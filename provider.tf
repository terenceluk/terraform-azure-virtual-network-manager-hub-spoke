terraform {
  #  backend "local" {}

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.2.0"
      # version = "3.27.0"

    }
  }

  backend "azurerm" {
    resource_group_name  = "<storageAccountRG>"
    storage_account_name = "<storageAccountName>"
    container_name       = "<containerName>"
    key                  = "terraform.tfstate"
    access_key           = "<StorageAccountAccessKey>"
  }
}
