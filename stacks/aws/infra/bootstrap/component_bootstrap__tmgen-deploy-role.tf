// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

data "aws_caller_identity" "current" {
}
locals {
  caller_arn      = data.aws_caller_identity.current.arn
  caller_assumed  = can(regex("^arn:aws:sts::[0-9]+:assumed-role/", local.caller_arn))
  caller_role_arn = local.caller_assumed ? replace(local.caller_arn, "/^arn:aws:sts::([0-9]+):assumed-role/([^/]+)/.*/", "arn:aws:iam::$1:role/$2") : local.caller_arn
  caller_sso      = can(regex(":assumed-role/AWSReservedSSO_", local.caller_arn))
  caller_trust = local.caller_sso ? [
    ] : [
    local.caller_role_arn,
  ]
  deploy_trust = distinct(concat([
    "arn:aws:iam::111111111111:role/tmhs-gha-ci",
  ], local.caller_trust))
}
resource "aws_iam_role" "deploy" {
  assume_role_policy = symbols::iam::aws_principal_trust(local.deploy_trust, "sts:AssumeRole")
  name               = "tmhs-deploy"
}
resource "terraform_data" "deploy_role_ready" {
  depends_on = [
    aws_iam_role.deploy,
    aws_iam_role_policy_attachment.deploy_admin,
  ]
  triggers_replace = [
    aws_iam_role.deploy.arn,
  ]
  provisioner "local-exec" {
    command = <<-EOT
for i in $(seq 1 30); do
  aws sts assume-role --role-arn "$ROLE_ARN" --role-session-name bootstrap-gate >/dev/null 2>&1 && exit 0
  echo "deploy role $ROLE_ARN not yet assumable, retry $i/30..." >&2
  sleep 10
done
echo "deploy role $ROLE_ARN never became assumable after 5m" >&2
exit 1
EOT

    environment = {
      ROLE_ARN = self.triggers_replace[0]
    }
    interpreter = [
      "/bin/bash",
      "-c",
    ]
  }
}
