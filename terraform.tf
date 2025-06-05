terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.0.0-beta2"
    }
    tls = {
      source = "hashicorp/tls"
      version = "4.1.0"
    }
  }
}