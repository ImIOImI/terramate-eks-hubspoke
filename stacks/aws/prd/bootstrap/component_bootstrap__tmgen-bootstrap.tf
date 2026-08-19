// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

resource "aws_s3_bucket" "state" {
  bucket = "tmhs-state-prd-333333333333"
}
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    bucket_key_enabled = true
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}
resource "aws_s3_bucket_public_access_block" "state" {
  block_public_acls       = true
  block_public_policy     = true
  bucket                  = aws_s3_bucket.state.id
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_dynamodb_table" "locks" {
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  name         = "tmhs-locks-prd"
  attribute {
    name = "LockID"
    type = "S"
  }
}
resource "aws_iam_role_policy_attachment" "deploy_admin" {
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  role       = aws_iam_role.deploy.name
}
