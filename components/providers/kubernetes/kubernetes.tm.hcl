# ---------------------------------------------------------------------------
# Component: providers/kubernetes
#
# Emits kubernetes (and optionally helm) provider(s) using exec-based auth
# (`aws eks get-token`) via outputs-sharing for endpoint + CA.  Greenfield-safe:
# mocks satisfy `tofu plan` before the cluster stack is applied.
#
# Design decisions:
#   - Own-cluster endpoint/CA: consumed from cluster stack via sharing inputs
#     (labels cluster_endpoint / cluster_ca).  No data.aws_eks_cluster.
#   - Hub-cluster endpoint/CA (when hub_env != ""): consumed via divergent-label
#     sharing inputs (labels hub_cluster_endpoint / hub_cluster_ca, both reading
#     upstream outputs cluster_endpoint / cluster_ca).  Divergent labels are
#     confirmed working — see task-8-report.md probe section.
#   - Helm v3 uses attribute-assignment syntax: `kubernetes = { ... }` with
#     nested `exec = { ... }`.  Source: hashicorp/terraform-provider-helm
#     docs/index.md (verified at v3.2.0).
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Sharing inputs — own cluster endpoint + CA.
# Generated file name must not collide with the cluster component's
# _tmgen-sharing-inputs.tm.hcl; use a distinct name scoped to this component.
# On the SECOND `terramate generate` pass Terramate writes _tmgen-sharing.tf
# with variable "cluster_endpoint" and variable "cluster_ca".
# Use var.cluster_endpoint / var.cluster_ca in generated TF only — never in
# data-source filters (greenfield mock footgun, SPIKE-FINDINGS C.5).
# ---------------------------------------------------------------------------
generate_hcl "_tmgen-k8s-sharing-inputs.tm.hcl" {
  content {
    input "cluster_endpoint" {
      backend       = "default"
      from_stack_id = component.input.cluster_stack_id.value
      value         = outputs.cluster_endpoint.value
      mock          = "https://mock.eks.example.com"
    }
    # CA must be valid base64 — provider does base64decode(var.cluster_ca).
    input "cluster_ca" {
      backend       = "default"
      from_stack_id = component.input.cluster_stack_id.value
      value         = outputs.cluster_ca.value
      mock          = "bW9jay1jYS1kYXRh"
    }
  }
}

# ---------------------------------------------------------------------------
# Sharing inputs — hub cluster endpoint + CA (emitted only when hub_env != "").
# Divergent labels: local names hub_cluster_endpoint / hub_cluster_ca read
# upstream outputs named cluster_endpoint / cluster_ca on the hub stack.
# PROBE (task-8-report.md): Terramate generates variable "hub_cluster_endpoint"
# and variable "hub_cluster_ca" in _tmgen-sharing.tf — confirmed working.
# ---------------------------------------------------------------------------
generate_hcl "_tmgen-k8s-hub-sharing-inputs.tm.hcl" {
  condition = component.input.hub_env.value != ""

  content {
    input "hub_cluster_endpoint" {
      backend       = "default"
      from_stack_id = component.input.hub_cluster_stack_id.value
      value         = outputs.cluster_endpoint.value
      mock          = "https://hub-mock.eks.example.com"
    }
    input "hub_cluster_ca" {
      backend       = "default"
      from_stack_id = component.input.hub_cluster_stack_id.value
      value         = outputs.cluster_ca.value
      mock          = "aHViLW1vY2stY2EtZGF0YQ=="
    }
  }
}


# ---------------------------------------------------------------------------
# LOCAL (MiniStack) AUTH PATH
#
# MiniStack's EKS CreateCluster spawns a real k3s container, but there is no
# aws-iam-authenticator webhook in front of it: `aws eks get-token` returns a
# well-formed ExecCredential that k3s answers with 401. The only way in is k3s's
# own admin client certificate.
#
# `make ci-kubeconfig` extracts that cert/key/CA out of the k3s container into
# .ministack/<cluster>.{crt,key,ca}, and local envs point the providers at those
# files instead of exec-auth.
#
# This is the one place the ci environment deliberately diverges from prod: the
# auth path under test is NOT the exec-auth path real clusters use.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# kubernetes provider — own cluster (always emitted).
# ---------------------------------------------------------------------------
generate_hcl "_tmgen-provider-kubernetes.tf" {
  condition = component.input.account_map.value[component.input.env.value].endpoint == ""
  lets {
    acct = component.input.account_map.value[component.input.env.value]
  }
  content {
    provider "kubernetes" {
      host                   = var.cluster_endpoint
      cluster_ca_certificate = base64decode(var.cluster_ca)
      exec {
        api_version = "client.authentication.k8s.io/v1beta1"
        command     = "aws"
        args = [
          "eks", "get-token",
          "--cluster-name", component.input.cluster_name.value,
          "--role-arn", let.acct.deploy_role_arn,
        ]
      }
    }
  }
}

# ---------------------------------------------------------------------------
# helm provider — emitted when include_helm = true.
# v3 uses attribute-assignment syntax for the kubernetes block:
#   kubernetes = { host = ..., exec = { ... } }
# Source: hashicorp/terraform-provider-helm docs/index.md (verified v3.2.0)
# https://github.com/hashicorp/terraform-provider-helm/blob/main/docs/index.md
# ---------------------------------------------------------------------------
generate_hcl "_tmgen-provider-helm.tf" {
  condition = component.input.include_helm.value && component.input.account_map.value[component.input.env.value].endpoint == ""

  lets {
    acct = component.input.account_map.value[component.input.env.value]
  }
  content {
    provider "helm" {
      kubernetes = {
        host                   = var.cluster_endpoint
        cluster_ca_certificate = base64decode(var.cluster_ca)
        exec = {
          api_version = "client.authentication.k8s.io/v1beta1"
          command     = "aws"
          args = [
            "eks", "get-token",
            "--cluster-name", component.input.cluster_name.value,
            "--role-arn", let.acct.deploy_role_arn,
          ]
        }
      }
    }
  }
}

# Local (MiniStack) variant -- client-cert auth, see LOCAL AUTH PATH note above.
generate_hcl "_tmgen-provider-helm.tf" {
  condition = component.input.include_helm.value && component.input.account_map.value[component.input.env.value].endpoint != ""

  content {
    provider "helm" {
      kubernetes = {
        host                   = var.cluster_endpoint
        cluster_ca_certificate = base64decode(var.cluster_ca)
        client_certificate     = file("${terramate.stack.path.to_root}/.ministack/${component.input.cluster_name.value}.crt")
        client_key             = file("${terramate.stack.path.to_root}/.ministack/${component.input.cluster_name.value}.key")
      }
    }
  }
}

# Local (MiniStack) variant -- client-cert auth, see LOCAL AUTH PATH note above.
generate_hcl "_tmgen-provider-kubernetes.tf" {
  condition = component.input.account_map.value[component.input.env.value].endpoint != ""

  content {
    provider "kubernetes" {
      host                   = var.cluster_endpoint
      cluster_ca_certificate = base64decode(var.cluster_ca)
      client_certificate     = file("${terramate.stack.path.to_root}/.ministack/${component.input.cluster_name.value}.crt")
      client_key             = file("${terramate.stack.path.to_root}/.ministack/${component.input.cluster_name.value}.key")
    }
  }
}

# ---------------------------------------------------------------------------
# kubernetes provider hub alias — emitted when hub_env != "".
# Used by spoke provisioning stacks to deploy ArgoCD ApplicationSet resources
# into the hub cluster.  The hub deploy role is taken from account_map[hub_env].
# Prerequisite: hub cluster must be applied before spoke provisioning previews
# are meaningful (the `after` edge in the bundle handles ordering).
# ---------------------------------------------------------------------------
generate_hcl "_tmgen-provider-kubernetes-hub.tf" {
  condition = component.input.hub_env.value != ""

  lets {
    # tm_try guards the disabled case: `lets` is evaluated even when
    # condition=false (hub provisioning stack has hub_env=""), so a bare
    # account_map[""] would error before the condition can skip the block.
    hub = tm_try(component.input.account_map.value[component.input.hub_env.value], {})
  }
  content {
    provider "kubernetes" {
      alias                  = "hub"
      host                   = var.hub_cluster_endpoint
      cluster_ca_certificate = base64decode(var.hub_cluster_ca)
      exec {
        api_version = "client.authentication.k8s.io/v1beta1"
        command     = "aws"
        args = [
          "eks", "get-token",
          "--cluster-name", component.input.hub_cluster_name.value,
          "--role-arn", let.hub.deploy_role_arn,
        ]
      }
    }
  }
}
