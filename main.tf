# Configure the Azure providers
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
    }
    azuread = {
      source  = "hashicorp/azuread"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azuread" {}

# Create two resource groups
resource "azurerm_resource_group" "prod-rg" {
  name     = "${var.subname}-PROD-RG"
  location = var.location
}

resource "azurerm_resource_group" "test-rg" {
  name     = "${var.subname}-TEST-RG"
  location = var.location
}

# Create a recovery services vault
resource "azurerm_recovery_services_vault" "prod-rv" {
  name                = "${var.short_subname}PROD-RV"
  location            = var.location
  resource_group_name = azurerm_resource_group.prod-rg.name
  sku                 = "Standard"
}
resource "azurerm_recovery_services_vault" "test-rv" {
  name                = "${var.short_subname}TEST-RV"
  location            = var.location
  resource_group_name = azurerm_resource_group.test-rg.name
  sku                 = "Standard"
}

# Create backup policies
resource "azurerm_backup_policy_vm" "prod-backup" {
  name                = "${var.short_subname}PROD-BACKUP"
  resource_group_name = azurerm_resource_group.prod-rg.name
  recovery_vault_name = azurerm_recovery_services_vault.prod-rv.name
  timezone = "UTC"
  backup {
    frequency = "Daily"
    time      = "23:00"
  }
  retention_daily {
    count = 7
  }
  retention_weekly {
    count = 6
    weekdays = ["Sunday"]
  }
}

resource "azurerm_backup_policy_vm" "test-backup" {
  name                = "${var.short_subname}TEST-BACKUP"
  resource_group_name = azurerm_resource_group.test-rg.name
  recovery_vault_name = azurerm_recovery_services_vault.test-rv.name
timezone = "UTC"
  backup {
    frequency = "Daily"
    time      = "23:00"
  }
  retention_daily {
    count = 6
  }
  retention_weekly {
    count = 6
    weekdays = ["Sunday"]
  }
}

# Add Azure AD group to custom role assignment
resource "azuread_group" "custom" {
  display_name     = "AZURE-${var.short_subname}"
  security_enabled = true
}

resource "azurerm_role_assignment" "prod" {
  scope                = azurerm_recovery_services_vault.prod-rv.id
  description          = "JH Custom INTERNAL Permissions Role"
  role_definition_name = "Owner"
  principal_id         = azuread_group.custom.id
}

resource "azurerm_role_assignment" "test" {
  scope                = azurerm_recovery_services_vault.test-rv.id
  description          = "JH Custom INTERNAL Permissions Role"
  role_definition_name = "Owner"
  principal_id         = azuread_group.custom.id
}

# Create an action group and add email addresses
resource "azurerm_monitor_action_group" "prod-ag" {
  name                 = "${var.subname} Prod Service Health AG"
  short_name           = "${var.subname}PRODAG"
  resource_group_name  = azurerm_resource_group.prod-rg.name

  email_receiver {
    name               = "example"
    email_address      = "example@example.com"
  }
}

resource "azurerm_monitor_action_group" "test-ag" {
  name                 = "${var.subname} Test Service Health AG"
  short_name           = "${var.subname}TESTAG"
  resource_group_name  = azurerm_resource_group.test-rg.name

  email_receiver {
    name               = "example"
    email_address      = "example@example.com"
  }
}

# Create network security groups
resource "azurerm_network_security_group" "nsg-prod" {
  name                = "${var.subname}-PROD-CLOUDNSG"
  location            = var.location
  resource_group_name = azurerm_resource_group.prod-rg.name
}

resource "azurerm_network_security_group" "nsg-test" {
  name                = "${var.subname}-TEST-CLOUDNSG"
  location            = var.location
  resource_group_name = azurerm_resource_group.test-rg.name
}
