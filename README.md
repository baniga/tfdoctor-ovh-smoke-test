# TFDoctor feature lab on OVHcloud

The main root keeps the **8 existing empty OVHcloud buckets** unchanged and adds **8 built-in `terraform_data` instances**. The additions store values in Terraform State; they do not create cloud services or run scripts. Terraform remains **1.14.2**, OVH remains **2.22.0**, and the HTTP backend and dependency lock are preserved.

Use this lab to inspect actual resource references, explicit `depends_on`, a replacement chain, a local module, `count` / `for_each` groups, nested attributes, sensitive-field masking, outputs, and failure handling.

## Start in the existing Workspace

1. Open **ovh-smoke-test → Run plan** and select the latest **main** revision.
2. Review the Plan yourself. If the existing eight buckets are already managed, the intended new changes are **8 State-only resources to add**. No OVH bucket creation, replacement, update or deletion is introduced by this change.
3. Approve and Apply yourself when the saved Plan matches what you want.
4. Run main again to inspect a no-op, then select one of the `demo/*` branches below. Counts assume the main baseline was applied and Workspace inputs contain no overrides for the new `lab_*` variables.

No Plan or Apply is started by this repository update. There are no CI workflows, provisioners, remote scripts or automatic run triggers. Existing provider credentials and `ovh_project_id` stay in the Workspace; no new API permissions are needed. Do not copy credentials into Git.

## Select a test branch

| Branch | Expected change from the applied main baseline |
| --- | --- |
| `main` | 8 additions on upgrade; then 16 no-ops |
| `demo/01-update` | 2 in-place State-only updates |
| `demo/02-replace` | 3 State-only replacements and 4 State-only updates |
| `demo/03-scale-down` | 2 State-only deletions, one from `count` and one from `for_each` |
| `demo/04-scale-up` | 2 additional State-only instances |
| `demo/05-output-only` | One output changes; all 16 resources remain no-op |
| `demo/06-plan-error` | Intentional variable-validation failure; no Apply |
| `demo/07-check-warning` | Intentional Terraform check warning; no resource changes |
| `demo/08-apply-error` | Plan: 1 State-only replacement and 4 updates. If you approve Apply, an intentional postcondition fails. |

Scenario branches add only `scenario.auto.tfvars`; their Terraform source and eight OVH definitions match main. The files in `scenarios/` are examples and are not automatically loaded by the main root. If you Apply a scenario, review and Apply main to restore the baseline before comparing another scenario. Every Apply remains your decision.

See **[LAB.md](LAB.md)** for the exact click path, useful resources to select, the feature coverage matrix and State/recovery tests. The optional **[state-only/](state-only/)** root is a separate six-resource fixture with no cloud provider, suitable for a dedicated State/history/restore Workspace.

## Cost

The new resources have **zero additional cloud-resource cost**: `terraform_data` is built into Terraform and performs no cloud operations. The optional root also creates only State entries. The eight existing buckets stay empty; no uploaded objects, compute, disks, IPs, replication, Object Lock or paid add-ons are added.

Empty-bucket cost is expected to remain zero under OVHcloud's usage-based Object Storage pricing. This is an expectation for this lab, not a guarantee about your overall account bill. Stored data or later service changes can incur charges. [OVHcloud pricing](https://www.ovhcloud.com/en/public-cloud/prices/) · [Terraform built-in resource](https://developer.hashicorp.com/terraform/language/resources/terraform-data)

## Reproduce validation without a cloud account

With Terraform 1.14.2 and Python 3.9+ installed, run:

```sh
python3 tools/verify_lab.py
```

The bounded verifier copies only explicit source files to an ignored scratch directory, removes cloud/backend/variable credential environment, initializes with the backend disabled, and runs **14 native Terraform tests**. OVH is mocked in memory; the separate root uses only built-ins. It asserts exact action counts, sensitive markers, replacement paths and unchanged mocked bucket actions. Logs and source hashes remain under `.lab-validation/` for inspection.

Mock tests prove configuration and scenario behavior. They do not prove actual OVH authentication, billing, live drift, TFDoctor UI acceptance or recovery. Those checks require your explicitly started Workspace runs. The existing eight OVH blocks, addresses, namespace, DE region, encryption, explicit project identity and provider lock are unchanged. Existing State or taints are never cleared by this code.

The external OVH provider is referenced from the registry under its existing MPL-2.0 release; its binary is not redistributed here. No new external provider or dependency is introduced.
