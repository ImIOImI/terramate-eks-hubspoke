# ---------------------------------------------------------------------------
# Component: argocd-spoke
#
# Registers a spoke EKS cluster with the ArgoCD hub by:
#   1. Creating an IAM role in the spoke account that the hub ArgoCD controller
#      may assume to deploy workloads.
#   2. Writing a kubernetes Secret into the hub cluster's "argocd" namespace
#      that contains the spoke cluster's endpoint, CA, and the assume-role ARN.
#
# Prerequisites (must be co-located in the same provisioning stack):
#   - components/providers/kubernetes with hub_env set (non-empty):
#       * Emits provider kubernetes { alias = "hub" } connected to the hub.
#       * Emits sharing inputs var.cluster_endpoint / var.cluster_ca for the
#         own spoke cluster (labels cluster_endpoint / cluster_ca).
#       * Emits sharing inputs var.hub_cluster_endpoint / var.hub_cluster_ca
#         for the hub cluster.
#   - Do NOT redeclare var.cluster_endpoint or var.cluster_ca here — the
#     kubernetes provider component already declares them.  Duplicate variable
#     definitions cause a tofu parse error.
# ---------------------------------------------------------------------------

generate_hcl "_tmgen-argocd-spoke.tf" {
  # Conditional components are unsupported (SPIKE-FINDINGS: no ternary source, no
  # tm_dynamic "component"), so this component is always instantiated but emits
  # nothing unless enabled (bundle sets enabled = role=="spoke").
  condition = component.input.enabled.value
  lets {
    prefix = component.input.project_prefix.value
    # hub account map entry — used to construct the controller role ARN.
    # tm_try guards the disabled case: `lets` is evaluated even when
    # condition=false (hub provisioning stack instantiates this component with
    # enabled=false and hub_env=""), so a bare account_map[""] would error.
    hub = tm_try(component.input.account_map.value[component.input.hub_env.value], {})
  }
  content {
    # -------------------------------------------------------------------------
    # IAM role in the spoke account.
    # Trusted by the ArgoCD controller role running in the hub account.
    #
    # Both sts:AssumeRole and sts:TagSession are granted:
    #   - sts:AssumeRole: required for any cross-account role assumption.
    #   - sts:TagSession: required when the principal uses pod identity
    #     (EKS Pod Identity always includes TagSession in its assume-role call;
    #     omitting it causes an IAM error even though the pod already has the
    #     IRSA/pod-identity role).
    # -------------------------------------------------------------------------
    resource "aws_iam_role" "spoke_access" {
      name = "${let.prefix}-argocd-spoke-access"
      assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect = "Allow"
          Principal = {
            AWS = "arn:aws:iam::${let.hub.account_id}:role/${let.prefix}-argocd-controller"
          }
          Action = ["sts:AssumeRole", "sts:TagSession"]
        }]
      })
    }

    # -------------------------------------------------------------------------
    # ArgoCD cluster registration Secret written into the hub cluster.
    # provider = kubernetes.hub: targets the hub cluster (alias emitted by the
    # kubernetes provider component when hub_env != "").
    #
    # caData note: EKS cluster_ca_certificate_authority.data is already
    # base64-encoded. ArgoCD's tlsClientConfig.caData expects base64 — pass
    # it through as-is; do NOT base64encode or base64decode it here.
    #
    # var.cluster_endpoint / var.cluster_ca: declared by the kubernetes provider
    # component's sharing-inputs generator (_tmgen-k8s-sharing-inputs.tm.hcl).
    # They resolve at apply time from the spoke eks-cluster stack outputs.
    # -------------------------------------------------------------------------
    resource "kubernetes_secret" "registration" {
      provider = kubernetes.hub

      metadata {
        name      = "cluster-${component.input.cluster_name.value}"
        namespace = "argocd"
        labels = {
          "argocd.argoproj.io/secret-type" = "cluster"
          "env"                            = component.input.env.value
        }
      }

      data = {
        name   = component.input.cluster_name.value
        server = var.cluster_endpoint
        config = jsonencode({
          awsAuthConfig = {
            clusterName = component.input.cluster_name.value
            roleARN     = aws_iam_role.spoke_access.arn
          }
          tlsClientConfig = {
            caData = var.cluster_ca
          }
        })
      }
    }
  }
}
