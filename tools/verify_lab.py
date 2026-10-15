"""Validate the feature lab using mocked OVH and isolated, synthetic State only."""
from pathlib import Path
from collections import Counter
import hashlib
import json
import os
import re
import shutil
import subprocess
import uuid

repo = Path(__file__).resolve().parents[1]
area = repo / '.lab-validation' / uuid.uuid4().hex
area.mkdir(parents=True, mode=0o700)
assert area.resolve().is_relative_to((repo / '.lab-validation').resolve())
source = area / 'source'
source.mkdir()
names = ['main.tf', '.terraform.lock.hcl', 'lab.tf', 'lab-variables.tf',
         'modules/checks/main.tf', 'tests/lab.tftest.hcl',
         'state-only/main.tf', 'state-only/tests/state.tftest.hcl']
names += [str(p.relative_to(repo)) for p in sorted((repo / 'scenarios').glob('*.tfvars'))]
for name in names:
    src = repo / name
    assert src.resolve().is_relative_to(repo.resolve())
    dest = source / name
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, dest)

tests = (source / 'tests/lab.tftest.hcl').read_text()
assert 'mock_provider "ovh"' in tests
assert not re.search(r'(?m)^\s*provider\s+"', tests), 'Real providers are forbidden in these tests'
for path in source.rglob('*.tf'):
    text = path.read_text()
    assert not re.search(r'(?m)^\s*provisioner\s+"', text), 'No provisioners in this lab'
    assert not re.search(r'(?m)^\s*data\s+"', text), 'No external data reads in this lab'
    types = re.findall(r'(?m)^\s*resource\s+"([^"]+)"', text)
    assert all(t in ['terraform_data', 'ovh_cloud_project_storage'] for t in types)

env = {k: v for k, v in os.environ.items()
       if k in ['PATH', 'LANG', 'LC_ALL', 'TMPDIR', 'TEMP', 'TMP', 'SYSTEMROOT', 'WINDIR']}
config = area / 'terraform.rc'
config.write_text('disable_checkpoint = true\n')
env.update(TF_CLI_CONFIG_FILE=str(config), TF_IN_AUTOMATION='1', TF_INPUT='0', CHECKPOINT_DISABLE='1')
cache = repo / '.terraform/providers'
if cache.is_dir():
    env['TF_PLUGIN_CACHE_DIR'] = str(cache)
assert not any(k.startswith(('OVH_', 'TF_HTTP_', 'TF_VAR_', 'AWS_')) for k in env)

def execute(name, args, seconds):
    result = subprocess.run(args, cwd=source, env=env, text=True, capture_output=True, timeout=seconds)
    (area / (name + '.stdout')).write_text(result.stdout)
    (area / (name + '.stderr')).write_text(result.stderr)
    if result.returncode:
        raise RuntimeError(name + ' failed; see ' + str(area))
    return result.stdout

version = json.loads(execute('version', ['terraform', 'version', '-json'], 10))
assert version['terraform_version'] == '1.14.2'
execute('init', ['terraform', 'init', '-backend=false', '-lockfile=readonly', '-input=false', '-no-color'], 45)
execute('format', ['terraform', 'fmt', '-check', '-recursive'], 10)
assert json.loads(execute('validate', ['terraform', 'validate', '-json'], 20))['valid']
raw = execute('mock-tests', ['terraform', 'test', '-json', '-verbose', '-no-color'], 90)
events = [json.loads(line) for line in raw.splitlines() if line.strip().startswith('{')]
summary = next(e['test_summary'] for e in events if e.get('type') == 'test_summary')
assert summary == {'status': 'pass', 'passed': 11, 'failed': 0, 'errored': 0, 'skipped': 0}, summary

plans = {e['@testrun']: e['test_plan'] for e in events if e.get('type') == 'test_plan'}
expected = {
    'no_changes': {'no-op': 16},
    'update': {'no-op': 14, 'update': 2},
    'replace': {'no-op': 9, 'delete/create': 3, 'update': 4},
    'scale_down': {'no-op': 14, 'delete': 2},
    'scale_up': {'no-op': 16, 'create': 2},
    'output_only': {'no-op': 16},
    'check_warning': {'no-op': 16},
    'failed_apply_plan': {'no-op': 11, 'delete/create': 1, 'update': 4},
}
observed = {}
for name, counts in expected.items():
    changes = plans[name]['resource_changes']
    actual = dict(Counter('/'.join(r['change']['actions']) for r in changes))
    assert actual == counts, (name, actual, counts)
    cloud = [r for r in changes if r['type'] == 'ovh_cloud_project_storage']
    assert len(cloud) == 8 and all(r['change']['actions'] == ['no-op'] for r in cloud)
    assert all(r['type'] == 'terraform_data' for r in changes if r['change']['actions'] != ['no-op'])
    observed[name] = actual
assert plans['output_only']['output_changes']['lab_output_note']['actions'] == ['update']
assert all(v['actions'] == ['no-op'] for k, v in plans['output_only']['output_changes'].items() if k != 'lab_output_note')
replacement = next(r for r in plans['replace']['resource_changes'] if r['address'] == 'terraform_data.application')
assert ['triggers_replace'] in replacement['change']['replace_paths']

state = next(e['test_state'] for e in events if e.get('type') == 'test_state')
def resources(module):
    return module.get('resources', []) + [r for child in module.get('child_modules', []) for r in resources(child)]
all_resources = resources(state['root_module'])
assert len(all_resources) == 16
assert Counter(r['type'] for r in all_resources) == {'ovh_cloud_project_storage': 8, 'terraform_data': 8}
assert state['outputs']['lab_sensitive_example']['sensitive'] is True
execute('state-only-init', ['terraform', '-chdir=state-only', 'init', '-backend=false', '-input=false', '-no-color'], 20)
assert json.loads(execute('state-only-validate', ['terraform', '-chdir=state-only', 'validate', '-json'], 10))['valid']
state_raw = execute('state-only-tests', ['terraform', '-chdir=state-only', 'test', '-json', '-verbose', '-no-color'], 30)
state_events = [json.loads(line) for line in state_raw.splitlines() if line.strip().startswith('{')]
state_summary = next(e['test_summary'] for e in state_events if e.get('type') == 'test_summary')
assert state_summary == {'status': 'pass', 'passed': 3, 'failed': 0, 'errored': 0, 'skipped': 0}, state_summary
local_state = next(e['test_state'] for e in state_events if e.get('type') == 'test_state')
assert len(resources(local_state['root_module'])) == 6
assert all(r['type'] == 'terraform_data' for r in resources(local_state['root_module']))
local_plan = next(e['test_plan'] for e in state_events if e.get('@testrun') == 'generation_change' and e.get('type') == 'test_plan')
local_actions = dict(Counter('/'.join(r['change']['actions']) for r in local_plan['resource_changes']))
assert local_actions == {'update': 5, 'delete/create': 1}, local_actions
result = {'status': 'passed', 'terraform': '1.14.2', 'ovhProvider': '2.22.0',
          'testRuns': 14, 'mainTestRuns': 11, 'stateOnlyTestRuns': 3, 'scenarios': observed,
          'stateOnlyActions': local_actions,
          'sourceHashes': {name: hashlib.sha256((source / name).read_bytes()).hexdigest() for name in names},
          'scope': 'Mock OVH only; no credentials, real HTTP backend or real cloud resources.',
          'limits': 'Mock execution does not prove OVH billing, authentication, live drift or TFDoctor browser behavior.'}
(area / 'summary.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({'status': 'passed', 'testRuns': 14, 'scenarios': observed, 'stateOnlyActions': local_actions, 'evidenceDirectory': str(area)}))
