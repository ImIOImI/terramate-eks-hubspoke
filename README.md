# terramate-eks-hubspoke

A complete, self-sufficient public showcase of the bundle approach to standing up EKS clusters with Terramate and OpenTofu. This repository demonstrates an ArgoCD hub cluster in an `infra` account with spoke clusters in `dev` and `prd` accounts, all registered to the hub.

This is a generalized example — no SumerSports-specific identifiers or integrations. Anyone with AWS accounts can clone, fill in account IDs, and apply to real AWS infrastructure. Full CI included via GitHub Actions with OpenTofu, Terramate, and AWS OIDC authentication.

**Under construction** — full walkthrough and deployment instructions coming in Task 13.
