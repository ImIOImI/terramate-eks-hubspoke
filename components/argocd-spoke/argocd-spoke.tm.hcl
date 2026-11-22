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
  # Real AWS only; the local (MiniStack) variant is at the bottom of this file.
  condition = component.input.enabled.value && component.input.account_map.value[component.input.env.value].endpoint == ""
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

# ---------------------------------------------------------------------------
# Local (MiniStack) variant.
#
# Two things differ from the real registration above:
#   - auth: awsAuthConfig makes ArgoCD fetch an EKS token, which MiniStack's
#     k3s answers with 401. Local spokes register with the k3s admin client
#     certificate instead (tlsClientConfig cert/key/CA from .ministack/).
#   - server: MiniStack reports the endpoint as https://localhost:<port>, which
#     only resolves on your laptop. The hub's ArgoCD runs inside another
#     container, so it dials the spoke's k3s container IP (.ministack/<cluster>.ip,
#     on Docker's bridge network; the k3s serving cert includes that IP).
#
# The spoke-access IAM role is kept so the IAM side is still exercised, even
# though nothing assumes it locally.
# ---------------------------------------------------------------------------
generate_hcl "_tmgen-argocd-spoke.tf" {
  condition = component.input.enabled.value && component.input.account_map.value[component.input.env.value].endpoint != ""
  lets {
    prefix    = component.input.project_prefix.value
    hub       = tm_try(component.input.account_map.value[component.input.hub_env.value], {})
    ministack = "${terramate.stack.path.to_root}/.ministack/${component.input.cluster_name.value}"
  }
  content {
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

    resource "kubernetes_secret" "registration" {
      provider = kubernetes.hub

      metadata {
        name      = "cluster-${component.input.cluster_name.value}"
        namespace = "argocd"
        labels = {
          "argocd.argoproj.io/secret-type" = "cluster"
          "env"                            = component.input.env.value
          "overlay"                        = component.input.k8s_overlay.value
        }
      }

      data = {
        name   = component.input.cluster_name.value
        server = "https://${trimspace(file("${let.ministack}.ip"))}:6443"
        config = jsonencode({
          tlsClientConfig = {
            caData   = filebase64("${let.ministack}.ca")
            certData = filebase64("${let.ministack}.crt")
            keyData  = filebase64("${let.ministack}.key")
          }
        })
      }
    }
  }
}

# `terramate script run ci test` -- generated only into local spoke provisioning
# stacks. Waits (on the hub) for this spoke's two demo Applications to be
# Synced + Healthy, then lists what actually landed on the spoke's own k3s.
generate_hcl "_tmgen-ci-test-script.tm.hcl" {
  condition = component.input.enabled.value && component.input.account_map.value[component.input.env.value].endpoint != ""
  lets {
    hub_k3s   = "ministack-eks-${tm_try(component.input.account_map.value[component.input.hub_env.value].region, "")}-${tm_try(component.input.account_map.value[component.input.hub_env.value].cluster_name, "")}"
    spoke_k3s = "ministack-eks-${component.input.account_map.value[component.input.env.value].region}-${component.input.cluster_name.value}"
    apps = [
      "application/argo-rollouts-${component.input.cluster_name.value}",
      "application/hello-${component.input.cluster_name.value}",
    ]
  }
  content {
    script "ci" "test" {
      description = "Wait for the hub to sync + heal this spoke's demo apps, then show them on the spoke"
      job {
        commands = [
          # One create-wait per app: a multi-resource wait fails fast on NotFound.
          # 6m covers the ApplicationSet controller's 3m retry when a spoke's
          # cluster secret lands while it is mid-reconcile.
          ["docker", "exec", let.hub_k3s, "kubectl", "-n", "argocd", "wait", "--for=create", "--timeout=6m", let.apps[0]],
          ["docker", "exec", let.hub_k3s, "kubectl", "-n", "argocd", "wait", "--for=create", "--timeout=6m", let.apps[1]],
          tm_concat(["docker", "exec", let.hub_k3s, "kubectl", "-n", "argocd", "wait", "--for=jsonpath={.status.sync.status}=Synced", "--timeout=10m"], let.apps),
          tm_concat(["docker", "exec", let.hub_k3s, "kubectl", "-n", "argocd", "wait", "--for=jsonpath={.status.health.status}=Healthy", "--timeout=10m"], let.apps),
          ["docker", "exec", let.spoke_k3s, "kubectl", "get", "deploy,rollouts.argoproj.io,pods", "-n", "hello", "-L", "overlay", "-o", "wide"],
        ]
      }
    }
  }
}
