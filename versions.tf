terraform {
  required_version = ">= 1.0.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.31.0"  # This version includes support for enable_fault_injection
    }
  }
}