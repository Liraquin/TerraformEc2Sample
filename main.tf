terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = ">= 5.0"
        }
    }
    backend "s3" {
    bucket         = "BUCKET_NAME"
    key            = "PATH/terraform.tfstate"
    region         = "us-east-1"
  }
}