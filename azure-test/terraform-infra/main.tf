terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.65"
    }
  }

  required_version = ">= 0.14.9"
}

provider "azurerm" {
  skip_provider_registration = "true"
  features {}
  subscription_id = "<subs_id>"
}

resource "azurerm_resource_group" "azureRG" {
  name                     = "${var.prefix}-resourcegroup"
  location = var.location
  tags = {
    "TechnicalEnvironment" = "NONPROD"
    "Technical:ApplicationName" = "TBD"
    "Technical:ApplicationID" = "TBD"
    "Technical:PlatformOwner" = "TBD"
  }
}


resource "azurerm_storage_account" "azurestrg" {
  name                     = "${var.storageprefix}data"
  resource_group_name      = azurerm_resource_group.azureRG.name
  location                 = azurerm_resource_group.azureRG.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  allow_blob_public_access = true

  tags = {
    "TechnicalEnvironment" = "NONPROD"
    "Technical:ApplicationName" = "TBD"
    "Technical:ApplicationID" = "TBD"
    "Technical:PlatformOwner" = "TBD"
  }
}

resource "azurerm_storage_container" "rawfiles" {
  name                  = "rawfiles"
  storage_account_name  = azurerm_storage_account.azurestrg.name
 
}

resource "azurerm_storage_container" "editedfiles" {
  name                  = "editedfiles"
  storage_account_name  = azurerm_storage_account.azurestrg.name
 
 
}


resource "azurerm_log_analytics_workspace" "workspaceA" {
  name                = "${var.prefix}-workspace"
  resource_group_name      = azurerm_resource_group.azureRG.name
  location                 = azurerm_resource_group.azureRG.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
}


# Use this data source to fetch all available log and metrics categories. We then enable all of them
data "azurerm_monitor_diagnostic_categories" "storage" {
  resource_id = azurerm_storage_account.azurestrg.id
}

resource "azurerm_monitor_diagnostic_setting" "storage" {
  name                       = "${var.prefix}-storage-diagnostics"
  target_resource_id         = azurerm_storage_account.azurestrg.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.workspaceA.id
  dynamic "log" {
    iterator = entry
    for_each = data.azurerm_monitor_diagnostic_categories.storage.logs

    content {
      category = entry.value
      enabled  = true

      retention_policy {
        enabled = true
        days    = 90
      }
    }
  }

  dynamic "metric" {
    iterator = entry
    for_each = data.azurerm_monitor_diagnostic_categories.storage.metrics

    content {
      category = entry.value
      enabled  = true

      retention_policy {
        enabled = true
        days    = 90
      }
    }
  }

  depends_on = [
    azurerm_log_analytics_workspace.workspaceA

  ]
}

data "azurerm_monitor_diagnostic_categories" "storage_blob" {
  resource_id = "${azurerm_storage_account.azurestrg.id}/blobServices/default/"
}

resource "azurerm_monitor_diagnostic_setting" "storage_blob" {
  name                       = "${var.prefix}-storageblob-diagnostics"
  target_resource_id         = "${azurerm_storage_account.azurestrg.id}/blobServices/default/"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.workspaceA.id

  dynamic "log" {
    iterator = entry
    for_each = data.azurerm_monitor_diagnostic_categories.storage_blob.logs

    content {
      category = entry.value
      enabled  = true

      retention_policy {
        enabled = true
        days    = 90
      }
    }
  }

  dynamic "metric" {
    iterator = entry
    for_each = data.azurerm_monitor_diagnostic_categories.storage_blob.metrics

    content {
      category = entry.value
      enabled  = true

      retention_policy {
        enabled = true
        days    = 90
      }
    }
  }

  depends_on = [

    azurerm_log_analytics_workspace.workspaceA

  ]
}

resource "azurerm_application_insights" "azureAppI" {
  name                = "${var.prefix}-application-insights"
  location            = azurerm_resource_group.azureRG.location
  resource_group_name = azurerm_resource_group.azureRG.name
  application_type    = "web"
}

resource "azurerm_app_service_plan" "azureASP" {
  name                = "${var.prefix}-appserviceplan"
  location            = azurerm_resource_group.azureRG.location
  resource_group_name = azurerm_resource_group.azureRG.name
  kind                = "Linux"
  reserved = true
  sku {
    tier = "Premium"
    size = "P2V3"
    capacity = 4
  }
  tags = {
    "TechnicalEnvironment" = "NONPROD"
    "Technical:ApplicationName" = "TBD"
    "Technical:ApplicationID" = "TBD"
    "Technical:PlatformOwner" = "TBD"
  }
}

resource "azurerm_function_app" "azuredmt" {
  name                       = "${var.prefix}-application"
  location                   = azurerm_resource_group.azureRG.location
  resource_group_name        = azurerm_resource_group.azureRG.name
  app_service_plan_id        = azurerm_app_service_plan.azureASP.id
  storage_account_name       = azurerm_storage_account.azurestrg.name
  storage_account_access_key = 		azurerm_storage_account.azurestrg.primary_access_key
  os_type                    = "linux"
  version                    = "~3"
   site_config {
    linux_fx_version = "PYTHON|3.8"
  }
   app_settings = {
      "FUNCTIONS_WORKER_RUNTIME" = "python"
      "MyStorageConnectionString"= azurerm_storage_account.azurestrg.primary_connection_string
      "AzureWebJobsMyStorageConnectionString" = azurerm_storage_account.azurestrg.primary_connection_string
      "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.azureAppI.instrumentation_key
  }
  tags = {
    "TechnicalEnvironment" = "NONPROD"
    "Technical:ApplicationName" = "TBD"
    "Technical:ApplicationID" = "TBD"
    "Technical:PlatformOwner" = "TBD"
  }
}

