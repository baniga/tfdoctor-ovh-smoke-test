# OVHcloud smoke test for TFDoctor

This small Terraform configuration declares **8 empty Object Storage buckets** in OVHcloud's **DE** region (Germany). It uses Terraform **1.14.2** and the official **ovh/ovh 2.22.0** provider, with the dependency lock file committed.

The repository contains no account IDs, API credentials, state, uploaded objects, compute instances, volumes, replication or Object Lock. This public repository is intended as a disposable, readable test example.

## Run it in TFDoctor

Open **Bar Test → Workspaces → ovh-smoke-test**. The Workspace supplies these provider environment variables through its encrypted credential binding:

- `OVH_APPLICATION_KEY`
- `OVH_APPLICATION_SECRET`
- `OVH_CONSUMER_KEY`
- `OVH_CLOUD_PROJECT_SERVICE`

The provider endpoint is `ovh-eu`. The Workspace also supplies the Terraform input `ovh_project_id`. Each resource uses it explicitly as `service_name`: provider 2.22.0's environment fallback can otherwise create the bucket and then fail Terraform's Plan/State consistency check. The project identifier stays in encrypted Workspace inputs, outside this public repository.

1. Choose the `main` revision and run **Plan** yourself.
2. Inspect the saved plan. For a fresh state, the intended change is **8 to add, 0 to change, 0 to destroy**.
3. Approve and run **Apply** yourself if the plan matches.

The setup process does **not** run Plan or Apply. This example has no CI workflows or automatic run trigger. Validation without Plan/Apply cannot guarantee that a future cloud operation will succeed; OVH authorization, service availability and bucket-name uniqueness are checked separately as far as possible with read-only requests.

## Expected cost and cleanup

Empty Standard Object Storage buckets are expected to cost **zero**: OVHcloud charges for stored capacity and applicable transfer; its pricing table lists Standard API requests as free and no minimum storage duration. This is a pricing-based expectation, not a billing guarantee. Keep the buckets empty for this test. Uploading data, adding replication or changing storage classes can incur charges.

After testing, use your normal Terraform workflow to review a destroy plan and remove these eight test buckets. Do not put valuable data in them: the provider's deletion implementation can empty a bucket before deleting it. The scoped credential is intended only for these test bucket names and their lifecycle; it cannot access KMS or create compute resources.

References: [OVHcloud pricing](https://www.ovhcloud.com/en/public-cloud/prices/), [official bucket resource](https://registry.terraform.io/providers/ovh/ovh/latest/docs/resources/cloud_project_storage), [provider 2.22.0 source](https://github.com/ovh/terraform-provider-ovh/tree/v2.22.0).

## Validation

Preparation uses `terraform init -backend=false`, `terraform fmt -check`, `terraform validate`, and provider schema inspection. These steps do not create cloud resources. The configuration explicitly selects the HTTP backend. TFDoctor supplies its State endpoint, locking and run-scoped authentication at runtime; no endpoint or credentials are stored in this repository. Without that declaration, Terraform falls back to local State even when TF_HTTP_* variables are present. Existing saved Plans from the older revision are retained; run and review a new Plan only after the prior uncertain outcome has been reconciled.

The external provider is distributed by OVHcloud under MPL-2.0. This repository references the provider through the Terraform registry and does not redistribute its binary or copy its implementation. See the upstream license and release provenance at the pinned version.

## Existing tainted test resources

An earlier owner-run Apply created the eight buckets, but Terraform marked them `tainted` after the provider's inconsistent `service_name` response. Fixing this configuration preserves that State. A new Plan can propose destroying and recreating these resources; review its replacements before approving Apply. Nothing in this repository clears taints, imports State, retries Apply, or deletes resources automatically.
