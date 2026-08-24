generate_hcl "_tmgen-core-addons.tf" {
  lets {
    local_env = component.input.account_map.value[component.input.env.value].endpoint != ""
  }
  lets {
    prefix = component.input.project_prefix.value
  }
  content {
    resource "aws_eks_addon" "coredns" {
      cluster_name  = component.input.cluster_name.value
      addon_name    = "coredns"
      addon_version = component.input.addon_versions.value["coredns"]
    }

    resource "aws_iam_role" "ebs_csi" {
      name               = "${let.prefix}-ebs-csi-${component.input.env.value}"
      assume_role_policy = tm_hcl_expression("symbols::iam::pod_identity_trust()")
    }

    resource "aws_iam_role_policy_attachment" "ebs_csi" {
      role       = aws_iam_role.ebs_csi.name
      policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
    }

    # Pod Identity binds an IAM role to a ServiceAccount. MiniStack does not
    # implement CreatePodIdentityAssociation, and the binding would be inert
    # against its k3s cluster anyway (no IAM integration), so local envs skip it.
    tm_dynamic "resource" {
      condition = let.local_env == false
      labels    = ["aws_eks_pod_identity_association", "ebs_csi"]
      attributes = {
        cluster_name    = component.input.cluster_name.value
        namespace       = "kube-system"
        service_account = "ebs-csi-controller-sa"
        role_arn        = tm_hcl_expression("aws_iam_role.ebs_csi.arn")
      }
    }

    resource "aws_eks_addon" "ebs_csi" {
      cluster_name  = component.input.cluster_name.value
      addon_name    = "aws-ebs-csi-driver"
      addon_version = component.input.addon_versions.value["aws-ebs-csi-driver"]
      depends_on    = tm_hcl_expression(let.local_env ? "[]" : "[aws_eks_pod_identity_association.ebs_csi]")
    }
  }
}
