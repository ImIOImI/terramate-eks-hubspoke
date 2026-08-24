// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

resource "aws_eks_addon" "coredns" {
  addon_name    = "coredns"
  addon_version = "v1.12.4-eksbuild.18"
  cluster_name  = "tmhs-eks-ci-hub"
}
resource "aws_iam_role" "ebs_csi" {
  assume_role_policy = symbols::iam::pod_identity_trust()
  name               = "tmhs-ebs-csi-ci-hub"
}
resource "aws_iam_role_policy_attachment" "ebs_csi" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi.name
}
resource "aws_eks_addon" "ebs_csi" {
  addon_name    = "aws-ebs-csi-driver"
  addon_version = "v1.48.0-eksbuild.2"
  cluster_name  = "tmhs-eks-ci-hub"
  depends_on = [
  ]
}
