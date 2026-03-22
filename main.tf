terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "docker" {}

locals {
  # abspath() required — Docker provider rejects relative host_path values
  module_path = abspath(path.module)
}

resource "docker_network" "lakehouse" {
  name   = "bp-ecg-lakehouse-net"
  driver = "bridge"
}
