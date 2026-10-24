terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.50.0, < 6.29"
    }
    github = {
      source  = "integrations/github"
      version = ">= 6.0"
    }
  }
  backend "s3" {
    bucket       = "bottomupai.terraform"
    key          = "terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Repo = "terraform",
    }
  }
}

provider "github" {
  owner = "BottomUpAI"
}
