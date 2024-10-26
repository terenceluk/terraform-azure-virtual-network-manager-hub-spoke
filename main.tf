################### Create Resource Group #####################

resource "azurerm_resource_group" "test-vnm-rg" {
  location = "canadacentral"
  name = "test-vnm-rg"
}

################### Create Virtual Network ####################

resource "azurerm_virtual_network" "test-192-168-0-0_16-hub-vnet" {
  address_space       = ["192.168.0.0/16"]
  location            = azurerm_resource_group.test-vnm-rg.location
  name                = "test-192-168-0-0_16-hub-vnet"
  resource_group_name = azurerm_resource_group.test-vnm-rg.name
  tags = merge(local.tags,
    {
      department = "infrastructure"
    },
  )
}

resource "azurerm_virtual_network" "test-172-16-0-0_12-spoke-vnet" {
  address_space       = ["172.16.0.0/12"]
  location            = azurerm_resource_group.test-vnm-rg.location
  name                = "test-172-16-0-0_12-spoke-vnet"
  resource_group_name = azurerm_resource_group.test-vnm-rg.name
  tags = merge(local.tags,
    {
      department = "infrastructure"
    },
  )
}

resource "azurerm_virtual_network" "test-10-0-0-0_8-spoke-vnet" {
  address_space       = ["10.0.0.0/8"]
  location            = azurerm_resource_group.test-vnm-rg.location
  name                = "test-10-0-0-0_8-spoke-vnet"
  resource_group_name = azurerm_resource_group.test-vnm-rg.name
  tags = merge(local.tags,
    {
      department = "infrastructure"
    },
  )
}

################### Create Subnet ###########################

resource "azurerm_subnet" "test-192-168-0-0_24-hub-snet" {
  address_prefixes     = ["192.168.0.0/24"]
  name                 = "test-192-168-0-0_24-hub-snet"
  resource_group_name = azurerm_resource_group.test-vnm-rg.name
  virtual_network_name = azurerm_virtual_network.test-192-168-0-0_16-hub-vnet.name
  depends_on = [
    azurerm_virtual_network.test-192-168-0-0_16-hub-vnet,
  ]
}

resource "azurerm_subnet" "test-192-168-1-0_24-hub-snet" {
  address_prefixes     = ["192.168.1.0/24"]
  name                 = "test-192-168-1-0_24-hub-snet"
  resource_group_name = azurerm_resource_group.test-vnm-rg.name
  virtual_network_name = azurerm_virtual_network.test-192-168-0-0_16-hub-vnet.name
  depends_on = [
    azurerm_virtual_network.test-192-168-0-0_16-hub-vnet,
  ]
}

resource "azurerm_subnet" "test-172-16-0-0_24-spoke-snet" {
  address_prefixes     = ["172.16.0.0/24"]
  name                 = "test-172-16-0-0_24-spoke-snet"
  resource_group_name = azurerm_resource_group.test-vnm-rg.name
  virtual_network_name = azurerm_virtual_network.test-172-16-0-0_12-spoke-vnet.name
  depends_on = [
    azurerm_virtual_network.test-172-16-0-0_12-spoke-vnet,
  ]
}

resource "azurerm_subnet" "test-172-16-1-0_24-spoke-snet" {
  address_prefixes     = ["172.16.1.0/24"]
  name                 = "test-172-16-1-0_24-spoke-snet"
  resource_group_name = azurerm_resource_group.test-vnm-rg.name
  virtual_network_name = azurerm_virtual_network.test-172-16-0-0_12-spoke-vnet.name
  depends_on = [
    azurerm_virtual_network.test-172-16-0-0_12-spoke-vnet,
  ]
}

resource "azurerm_subnet" "test-10-0-0-0_24-spoke-snet" {
  address_prefixes     = ["10.0.0.0/24"]
  name                 = "test-10-0-0-0_24-spoke-snet"
  resource_group_name = azurerm_resource_group.test-vnm-rg.name
  virtual_network_name = azurerm_virtual_network.test-10-0-0-0_8-spoke-vnet.name
  depends_on = [
    azurerm_virtual_network.test-10-0-0-0_8-spoke-vnet,
  ]
}

resource "azurerm_subnet" "test-10-0-1-0_24-spoke-snet" {
  address_prefixes     = ["10.0.1.0/24"]
  name                 = "test-10-0-1-0_24-spoke-snet"
  resource_group_name = azurerm_resource_group.test-vnm-rg.name
  virtual_network_name = azurerm_virtual_network.test-10-0-0-0_8-spoke-vnet.name
  depends_on = [
    azurerm_virtual_network.test-10-0-0-0_8-spoke-vnet,
  ]
}

################### Create a Virtual Network Manager instance ###################
# https://learn.microsoft.com/en-us/azure/virtual-network-manager/create-virtual-network-manager-terraform?tabs=azure-cli&pivots=mgmt-grp
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_manager#scope

resource "azurerm_network_manager" "test-virtual-network-manager" {
  name                = "test-virtual-network-manager"
  location            = azurerm_resource_group.test-vnm-rg.location
  resource_group_name = azurerm_resource_group.test-vnm-rg.name
  scope_accesses      = ["Connectivity","SecurityAdmin"]
  description         = "Test virtual network manager"
  scope {
    subscription_ids = ["/subscriptions/6c5f8b3f-c166-43e1-b555-7f3901d663e6"]
  }
}

################### Create a network group ####################################

resource "azurerm_network_manager_network_group" "spoke-network-group" {
  name               = "spoke-network-group"
  network_manager_id = azurerm_network_manager.test-virtual-network-manager.id
}

################### Create Azure Policy for adding any VNets with the word "spoke" into a network group ###############

resource "azurerm_policy_definition" "spoke-network-group-policy" {
  name         = "spoke-network-group-policy"
  policy_type  = "Custom"
  mode         = "Microsoft.Network.Data"
  display_name = "Policy Definition for Network Group - spoke-network-group"

  metadata = <<METADATA
    {
      "category": "Azure Virtual Network Manager"
    }
  METADATA

  policy_rule = <<POLICY_RULE
    {
      "if": {
        "allOf": [
          {
              "field": "type",
              "equals": "Microsoft.Network/virtualNetworks"
          },
          {
            "allOf": [
              {
              "field": "Name",
              "contains": "spoke"
              }
            ]
          }
        ]
      },
      "then": {
        "effect": "addToNetworkGroup",
        "details": {
          "networkGroupId": "${azurerm_network_manager_network_group.spoke-network-group.id}"
        }
      }
    }
  POLICY_RULE
}

################### Assign Azure Policy to Network Group to add spokes ###############################

data "azurerm_subscription" "current" {
}

resource "azurerm_subscription_policy_assignment" "spoke-network-group-policy" {
  name                 = "spoke-network-group-policy"
  policy_definition_id = azurerm_policy_definition.spoke-network-group-policy.id
  subscription_id      = data.azurerm_subscription.current.id
}

################### Create a connectivity configuration ##############################################

resource "azurerm_network_manager_connectivity_configuration" "test-virtual-network-manager-connectivity-config" {
  name                  = "test-virtual-network-manager-connectivity-config"
  network_manager_id    = azurerm_network_manager.test-virtual-network-manager.id
  connectivity_topology = "HubAndSpoke"
  applies_to_group {
    # https://learn.microsoft.com/en-us/azure/virtual-network-manager/concept-connectivity-configuration
    group_connectivity = "None" # or "DirectlyConnected"
    network_group_id   = azurerm_network_manager_network_group.spoke-network-group.id
  }

  hub {
    resource_id = azurerm_virtual_network.test-192-168-0-0_16-hub-vnet.id
    resource_type = "Microsoft.Network/virtualNetworks"
  }
}

################### Commit deployment ########################################################

resource "azurerm_network_manager_deployment" "test-virtual-network-manager-commit-deployment" {
  network_manager_id = azurerm_network_manager.test-virtual-network-manager.id
  location           = azurerm_resource_group.test-vnm-rg.location
  scope_access       = "Connectivity"
  configuration_ids  = [azurerm_network_manager_connectivity_configuration.test-virtual-network-manager-connectivity-config.id]
  depends_on = [
    azurerm_network_manager_connectivity_configuration.test-virtual-network-manager-connectivity-config,
  ]
}
