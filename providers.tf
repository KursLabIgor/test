terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}
terraform {
  required_version = ">= 1.0"
  backend "s3" {
  }
}
provider "aws" {
#  assume_role {
#    role_arn     = "arn:aws:iam::659831962308:role/AdminAssumeRole"
#    session_name = "TRF"
#    external_id  = "EXTERNAL_ID"
#  }
}

