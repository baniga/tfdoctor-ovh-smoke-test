# Practical TFDoctor checks

Start with the main baseline in the existing `ovh-smoke-test` Workspace. You run and approve all real Plans and Applies. The agent's verification used fake OVH resources and isolated test State.

## Baseline: make the connections visible

1. Open **Workspaces → ovh-smoke-test → Run plan**.
2. Select **main**, choose **Review plan request**, then **Run plan**. Check the resolved commit.
3. The upgrade should add eight `terraform_data` instances while the eight existing OVH buckets remain no-op. Inspect any unexpected OVH action before making an Apply decision.
4. Open **Resources** and select `terraform_data.application`. **Depends on** lists the catalog/release references. **View reference** opens a short explanation. **Technical details** contains the exact Plan pointer and provenance.
5. Select `terraform_data.release`, then `terraform_data.handoff`, to inspect **Used by**. In the map, select the same nodes. No empty evidence panel should ask you to select a missing link.
6. Inspect module instance groups: `module.checks.terraform_data.replica[0..1]` and `module.checks.terraform_data.check["health"/"inventory"]`. Expand the groups and select individual instances. A group is an IaC instance group, not a cloud dependency.
7. If you approve the baseline Apply, inspect the resulting State version and resource attributes. Replica inputs include nested labels/limits; check inputs contain a deliberately public dummy value marked sensitive. Masking should hide the sensitive field. This is a display test, not real secret material.
8. Run main again. Resource actions should be no-op. If refresh reports drift, inspect its actual before/after fields separately from changes proposed for Apply.

References are derived from the configuration stored with the Plan. They do not prove a runtime outage or current provider existence. Some module/input/index references may remain unresolved; the UI must preserve that uncertainty rather than invent an edge.

## Choose one scenario

The `demo/*` branches share main's source and add a small `scenario.auto.tfvars`. Select the branch in **Run plan**. Do not add `lab_*` overrides to Workspace inputs unless you deliberately want to override that branch's settings. The private `ovh_project_id` input remains in the Workspace.

Expected results are measured against an applied **main** baseline. The eight OVH resources are no-op in every scenario:

| Scenario | What to inspect |
| --- | --- |
| `demo/01-update` | Two replica updates. Open `input.note` before/after; counts and changed fields should agree. |
| `demo/02-replace` | `release → application → handoff`: three replacements, plus four module updates. Inspect `triggers_replace`, replacement reasons, reference details and optional dependency chains. A reference alone is not proof of the sole cause. |
| `demo/03-scale-down` | Exactly two deletions: replica `[1]` and check `["inventory"]`. Their sibling instances remain. |
| `demo/04-scale-up` | Exactly two creations: replica `[2]` and check `["routing"]`. Check count/key grouping and new attributes after an approved Apply. |
| `demo/05-output-only` | `lab_output_note` changes. Resource count is zero while the saved Plan still has an output change to review. |
| `demo/06-plan-error` | `lab_replica_count=0` fails validation. Show the concrete error and failed stage; no approval or claim of a complete Plan. Return to main to continue. |
| `demo/07-check-warning` | The named `lab_health` check intentionally warns. This is not an OVH outage. Inspect the warning and TFDoctor's decision; there are no infrastructure actions. |
| `demo/08-apply-error` | Only if you want a deliberate failed Apply: first review the one State-only replacement/four updates, then approve yourself. `handoff`'s postcondition fails after its new ID exists. Inspect the runner log, persisted State, partial result and any recovery requirement. Return to main and review a recovery Plan; do not erase State or clear locks to hide the failure. |

If you applied another scenario, main may propose changes to return its State-only objects to baseline. Review and restore the baseline before checking the next expected count. Merely switching a Git branch does not change infrastructure or State.

## Dedicated State-only Workspace

For State import/restore experiments, use a separate Workspace with repository root **`state-only`**, Terraform **1.14.2**, and initial State **New**. It has six built-in instances and needs no cloud provider credentials. Creating this Workspace is optional and has not been done for you.

1. Plan and, if desired, approve the generation-1 baseline yourself.
2. Set its Inputs to `{"generation":2}`. Plan should show one State-only replacement and five updates. Approve only if you want a second State version.
3. Compare version timestamps, resource IDs and nested attributes. Open history and resource details after a browser refresh.
4. Exercise owner-authorized export/import/restore controls only in this separate fixture. Record the selected version and expected current revision. Missing permission, stale revision or incompatible State should be reported explicitly.
5. Restoring a State version does not restore Git code or Inputs. If generation stays 2, a later Plan can propose generation 2 again. Set generation deliberately before interpreting that Plan.

Keep the original OVH Workspace's State intact for these experiments. This separate root lets the State workflow be tested without cloud objects.

## Feature coverage and manual acceptance

| Current area | This repo provides | Additional manual check |
| --- | --- | --- |
| Public source, roots, branches, commits | main, local module, optional second root, eight scenario branches | Confirm exact source/commit and working directory in the run. |
| Workspace setup, Inputs, readiness | Pinned engine/provider, one private project input, bounded lab variables | Open Configuration; verify required Inputs and credential binding. Editing Inputs is a full replacement: preserve existing private inputs. |
| Live Plan/Apply progress and runner log | Real bucket refresh plus small State-only actions | Start a run yourself; watch progress, events, resource discovery and final counts. Built-in operations may finish quickly. |
| Plan/resource review, drift, map | Resource references, explicit ordering, replacement chain, grouped module instances | Select real fields and references. Drift means saved State versus provider read; no-op does not assert no drift. |
| Attributes and masking | Nested lists/maps/objects and dummy sensitive field | Inspect recorded State, origin/time and hidden sensitive values. This is not live inventory. |
| Approval and exact Apply | Source changes with clear action/output expectations | Approve once yourself; verify the saved Plan/commit identity and role restrictions. A later execution-mode/profile change must not silently approve an old Plan. |
| Queue, cancellation and locking | Existing Workspace can receive manual runs | While a Plan is active, request another and inspect its queue reason. Try cancellation from the run and run list. No delay scripts or automatic cancellation are added. |
| Failed Plan, warning, failed Apply/recovery | Three explicit isolated scenarios | Distinguish the failed stage, planned actions, actual runner result and saved State. Uncertain results must stay visibly uncertain. No automatic retry is added. |
| History and State versions | Normal/source/output changes and dedicated State-only root | Verify persistence after refresh, comparisons, role checks, export/import/restore and current-version checks. |
| Organization/member roles, sign-in/out, administration, audit | Existing test organization and workspace context | Exercise those interfaces separately with appropriate roles. Terraform source does not test OIDC, SSO logout, RBAC isolation, execution-mode controls or audit integrity. |
| Private GitHub App and AWS federation | No new integration/account | Need their own authorized private-repo/AWS fixtures; a public generic-Git OVH lab cannot prove them. No AWS services or paid integrations are created. |

This is a practical coverage fixture and checklist, not a claim that every UI state, permission boundary, provider, browser or recovery path has passed. Keep observed results with the run's exact commit. Report a failed expectation as a product issue rather than changing counts or accepting unknown evidence as proof.

## Cleanup

Returning to main removes scenario effects only after you review and Apply it. Removing the lab's State-only instances requires a reviewed configuration change/Apply; deleting the repository does not delete State. The optional State-only workspace has no real cloud objects.

Destroying the original root would also delete the eight OVH buckets. Do not place useful data there; the provider can empty a bucket before deletion. This guide adds no destroy automation.
