define "component" "metadata" {
  class       = "components/eks-nodes"
  version     = "0.1.0"
  name        = "eks-nodes"
  description = "EKS managed node group with ordered add-ons: kube-proxy + vpc-cni before nodes, pod-identity after"
}

define "component" {
  input "kubernetes_version" {
    type        = string
    description = "Kubernetes minor version for the control plane and the node group AMI"
    default     = "1.33"
  }
  input "use_latest_ami_release_version" {
    type        = bool
    description = "Look up the newest EKS-optimized AMI release from SSM. False for local envs -- MiniStack has no public SSM parameters."
    default     = true
  }
  input "cluster_name" {
    type        = string
    description = "EKS cluster name; passed to all add-ons and the node group module"
  }
  input "addon_versions" {
    type        = any
    description = "map of add-on name -> version string; expects keys kube-proxy, vpc-cni, eks-pod-identity-agent"
  }
  input "node_instance_types" {
    type        = any
    description = "list of EC2 instance type strings for the managed node group"
  }
  input "node_scaling" {
    type        = any
    description = "object with min and max attributes controlling the node group scaling bounds"
  }
  input "terraform_modules" {
    type        = any
    description = "map of module name -> {source, version}; expects .eks.source and .eks.version"
  }
  input "network_stack_id" {
    type        = string
    description = "UUID of this env's network stack; used to wire private_subnet_ids sharing input"
  }
  input "cluster_stack_id" {
    type        = string
    description = "UUID of this env's eks-cluster stack; used to wire cluster_service_cidr sharing input"
  }
}
