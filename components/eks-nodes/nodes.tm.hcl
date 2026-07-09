# ---------------------------------------------------------------------------
# Sharing inputs: private_subnet_ids (from network stack) + cluster_service_cidr
# (from eks-cluster stack). These generate _tmgen-sharing.tf on the second
# terramate generate pass. Consume as var.* in resource/module args only —
# never in data-source filters (mock footgun, SPIKE-FINDINGS C.5).
# ---------------------------------------------------------------------------
generate_hcl "_tmgen-sharing-inputs.tm.hcl" {
  content {
    input "private_subnet_ids" {
      backend       = "default"
      from_stack_id = component.input.network_stack_id.value
      value         = outputs.private_subnet_ids.value
      mock          = ["subnet-00000000000000000", "subnet-00000000000000001"]
    }
    input "cluster_service_cidr" {
      backend       = "default"
      from_stack_id = component.input.cluster_stack_id.value
      value         = outputs.cluster_service_cidr.value
      mock          = "172.20.0.0/16"
    }
  }
}

# ---------------------------------------------------------------------------
# Add-ons + managed node group.
#
# Ordering contract (CNI-before-nodes):
#   1. aws_eks_addon.kube_proxy + aws_eks_addon.vpc_cni — created first,
#      no depends_on (they only need the cluster control plane).
#   2. module.nodes — depends_on both CNI add-ons so nodes join only after
#      the network plumbing is ready.
#   3. aws_eks_addon.pod_identity — depends_on module.nodes (agent runs on
#      nodes; EKS requires at least one Ready node to schedule the DaemonSet).
#
# Module verified against terraform-aws-modules/eks v21.0.0
# modules/eks-managed-node-group/variables.tf:
#   name, cluster_name, subnet_ids, instance_types,
#   min_size, max_size, desired_size, cluster_service_cidr
#   all present with defaults — no undefaulted required vars beyond what
#   we supply. cluster_primary_security_group_id default = null (optional).
#   cluster_version does NOT exist in v21; kubernetes_version does (default null).
# ---------------------------------------------------------------------------
generate_hcl "_tmgen-nodes.tf" {
  content {
    resource "aws_eks_addon" "kube_proxy" {
      cluster_name  = component.input.cluster_name.value
      addon_name    = "kube-proxy"
      addon_version = component.input.addon_versions.value["kube-proxy"]
    }

    resource "aws_eks_addon" "vpc_cni" {
      cluster_name  = component.input.cluster_name.value
      addon_name    = "vpc-cni"
      addon_version = component.input.addon_versions.value["vpc-cni"]
    }

    module "nodes" {
      source  = "${component.input.terraform_modules.value.eks.source}//modules/eks-managed-node-group"
      version = component.input.terraform_modules.value.eks.version

      name         = "${component.input.cluster_name.value}-default"
      cluster_name = component.input.cluster_name.value

      # subnet_ids comes from the network stack via outputs-sharing (var.*).
      subnet_ids = var.private_subnet_ids

      instance_types = component.input.node_instance_types.value
      min_size       = component.input.node_scaling.value.min
      max_size       = component.input.node_scaling.value.max
      desired_size   = component.input.node_scaling.value.min

      # cluster_service_cidr comes from the eks-cluster stack via sharing (var.*).
      cluster_service_cidr = var.cluster_service_cidr

      depends_on = [aws_eks_addon.kube_proxy, aws_eks_addon.vpc_cni]
    }

    resource "aws_eks_addon" "pod_identity" {
      cluster_name  = component.input.cluster_name.value
      addon_name    = "eks-pod-identity-agent"
      addon_version = component.input.addon_versions.value["eks-pod-identity-agent"]
      depends_on    = [module.nodes]
    }
  }
}
