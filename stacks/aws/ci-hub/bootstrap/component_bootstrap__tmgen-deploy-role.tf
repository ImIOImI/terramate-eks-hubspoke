// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

resource "aws_iam_role" "deploy" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::111111111111:role/tmhs-gha-ci",
          ]
        }
        Action = "sts:AssumeRole"
      },
    ]
  })
  name = "tmhs-deploy"
}
