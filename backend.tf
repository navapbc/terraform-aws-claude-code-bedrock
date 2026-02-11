# Uncomment and configure for remote state storage.
# terraform {
#   backend "s3" {
#     bucket         = "your-terraform-state-bucket"
#     key            = "claude-code-bedrock/terraform.tfstate"
#     region         = "us-east-1"
#     dynamodb_table = "terraform-locks"
#     encrypt        = true
#   }
# }
