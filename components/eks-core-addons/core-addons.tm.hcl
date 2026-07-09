generate_hcl "_tmgen-core-addons.tf" {
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
      name = "${let.prefix}-ebs-csi-${component.input.env.value}"
      assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect    = "Allow"
          Principal = { Service = "pods.eks.amazonaws.com" }
          Action    = ["sts:AssumeRole", "sts:TagSession"]
        }]
      })
    }

    resource "aws_iam_role_policy_attachment" "ebs_csi" {
      role       = aws_iam_role.ebs_csi.name
      policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
    }

    resource "aws_eks_pod_identity_association" "ebs_csi" {
      cluster_name    = component.input.cluster_name.value
      namespace       = "kube-system"
      service_account = "ebs-csi-controller-sa"
      role_arn        = aws_iam_role.ebs_csi.arn
    }

    resource "aws_eks_addon" "ebs_csi" {
      cluster_name  = component.input.cluster_name.value
      addon_name    = "aws-ebs-csi-driver"
      addon_version = component.input.addon_versions.value["aws-ebs-csi-driver"]
      depends_on    = [aws_eks_pod_identity_association.ebs_csi]
    }
  }
}
