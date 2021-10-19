variable "location" {
  type    = string
  default = "east us"
}

variable "KFS_vnet_address_space" {
  type    = string
  default = "10.70.80.0/22"
}

variable "KFS_subnet_address_space1" {
  type    = string
  default = "10.70.80.0/24"
}

variable "KFS_subnet_address_space2" {
  type    = string
  default = "10.70.81.0/25"
}

variable "KFS_subnet_address_space3" {
  type    = string
  default = "10.70.81.128/25"
}

variable "environment_name" {
  type    = string
  default = "beta-prd"
}
variable "env_seq" {
  type = string
  default = "1"
}
variable "aks_service_cidr" {
  type = string
  default = "10.0.0.0/16"
}
variable "docker_bridge_cidr" {
  type = string
  default = "172.17.0.1/16"
}
variable "dns_service_ip" {
  type = string
  default = "10.0.0.10"
}
variable "user_assigned_identity" {
  type = string
}
variable "user_assigned_identity_rg" {
  type = string
}

variable "threat_detection_email" {
  type = string
}
variable "aks_vm_size" {
  type = string
  default = "Standard_D2S_v3"
}

resource "azurerm_user_assigned_identity" "AKSIDENTITY" {
  name = "kfsengg-beta"
  resource_group_name = azurerm_resource_group.KFSResourceGroup.name
  location = azurerm_resource_group.KFSResourceGroup.location
}

data "azurerm_client_config" "current" {}

terraform {
  backend "azurerm" {
    storage_account_name = "kfdevops"
    container_name       = "kfstatefile"
    access_key = "TB7swel1P350S5qzunR4uAYscdzv524ewPoHau4HMq1tfmtO8GP8kOFgH/tXHtjpLFS7H4iK3SIGgYHpyt0ffQ=="
    use_azuread_auth     = true
    subscription_id      = "3e357a00-39fc-400a-9d54-dcec7ed20bb4"
    tenant_id            = "7c0c36f5-af83-4c24-8844-9962e0163719"
  }
}

provider "azurerm" {
  features {}
  storage_use_azuread = true
}
locals {
  env_tag = join("_",[var.environment_name,var.env_seq])
  resource_prefix = join("",["kfs",var.environment_name])
  backend_address_pool_name      = "kfsell-plaform-backend"
  frontend_port_name             = "http"
  frontend_ip_configuration_name = "http-ip"
  http_setting_name              = "kfsell-platform-http-settings"
  listener_name                  = "kfsell-platform-listener"
  request_routing_rule_name      = "kfsell-platform-rule"

}

resource "azurerm_resource_group" "KFSResourceGroup" {
  location = var.location
  name     = join("",[local.resource_prefix,"rsg",var.env_seq])
  tags = {
    environment = local.env_tag
    SpokeType   = "KFS"
    CICDStage   = var.environment_name
  }
}
resource "azurerm_virtual_network" "kfsvnet" {
  name                = join("",[local.resource_prefix,"vnt",var.env_seq])
  location            = var.location
  resource_group_name = azurerm_resource_group.KFSResourceGroup.name
  address_space       = [var.KFS_vnet_address_space]
  depends_on          = [azurerm_resource_group.KFSResourceGroup]
  tags = {
    environment = local.env_tag
    SpokeType   = "KFS"
    CICDStage   = var.environment_name
  }
}
resource "azurerm_network_security_group" "KFSNSG" {
  location            = var.location
  name                = join("",[local.resource_prefix,"nsg",var.env_seq])
  resource_group_name = azurerm_resource_group.KFSResourceGroup.name
  depends_on          = [azurerm_resource_group.KFSResourceGroup]
  tags = {
    environment = local.env_tag
    SpokeType   = "KFS"
    CICDStage   = var.environment_name
  }
  security_rule {
    access = "Allow"
    direction = "Inbound"
    name = "Allow-VPN"
    priority = 110
    protocol = "TCP"
    source_address_prefixes = ["4.15.185.50/32", "213.86.156.212/32", "213.86.156.213/32", "63.236.5.205/32", "63.236.5.199/32", "8.243.153.34/32", "129.126.166.19/32", "129.126.166.20/32", "81.128.198.211/32", "203.111.163.174/32", "20.192.64.175/32", "20.190.42.250/32", "116.247.86.164/32", "179.191.97.66/32", "20.62.240.39/32", "52.168.0.151/32", "13.92.239.46/32"]
    destination_address_prefix = "*"
    source_port_range = "*"
    destination_port_ranges = ["443","80"]
  }
  security_rule {
    access = "Allow"
    direction = "Inbound"
    name = "IN-AGW-REQUIRED"
    priority = 100
    protocol = "TCP"
    source_address_prefix = "*"
    destination_address_prefix = "*"
    source_port_range = "*"
    destination_port_range = "65200-65535"
  }
  security_rule {
    access = "Allow"
    direction = "Inbound"
    name = "AllowHttpsInbound"
    priority = 120
    protocol = "TCP"
    source_address_prefix = "Internet"
    destination_address_prefix = "*"
    source_port_range = "*"
    destination_port_ranges = ["80", "443"]
  }
  security_rule {
    access = "Allow"
    direction = "Inbound"
    name = "AllowAzureLoadBalancerInbound"
    priority = 140
    protocol = "TCP"
    destination_address_prefix = "*"
    destination_port_ranges = ["80", "443"]
    source_port_range = "*"
    source_address_prefix = "AzureLoadBalancer"
  }
}
resource "azurerm_subnet" "kfs_aks_subnet" {
  name                 = "kfs_aks_subnet"
  resource_group_name  = azurerm_resource_group.KFSResourceGroup.name
  virtual_network_name = azurerm_virtual_network.kfsvnet.name
  address_prefixes     = [var.KFS_subnet_address_space1]
  enforce_private_link_endpoint_network_policies = true
  depends_on = [azurerm_resource_group.KFSResourceGroup,
    azurerm_virtual_network.kfsvnet
  ]
  service_endpoints = ["Microsoft.Sql","Microsoft.ContainerRegistry","Microsoft.Storage"]
}

resource "azurerm_subnet" "kfs_other_subnet" {
  name = "kfs_other_subnet"
  resource_group_name = azurerm_resource_group.KFSResourceGroup.name
  virtual_network_name = azurerm_virtual_network.kfsvnet.name
  address_prefixes     = [var.KFS_subnet_address_space2]
  enforce_private_link_endpoint_network_policies = true
  depends_on = [azurerm_resource_group.KFSResourceGroup,
    azurerm_virtual_network.kfsvnet
  ]
  service_endpoints = ["Microsoft.Sql","Microsoft.ContainerRegistry","Microsoft.Storage"]
}
resource "azurerm_subnet" "kfs_pass_subnet" {
  name = "kfs_other_subnet"
  resource_group_name = azurerm_resource_group.KFSResourceGroup.name
  virtual_network_name = azurerm_virtual_network.kfsvnet.name
  address_prefixes     = [var.KFS_subnet_address_space3]
  enforce_private_link_endpoint_network_policies = true
  depends_on = [azurerm_resource_group.KFSResourceGroup,
    azurerm_virtual_network.kfsvnet
  ]
  service_endpoints = ["Microsoft.Sql","Microsoft.ContainerRegistry","Microsoft.Storage"]
}

resource "azurerm_storage_account" "KFSStorage" {
  name                     = lower(join("",[local.resource_prefix,"sta",var.env_seq]))
  resource_group_name      = azurerm_resource_group.KFSResourceGroup.name
  location                 = azurerm_resource_group.KFSResourceGroup.location
  account_tier             = "Standard"
  account_replication_type = "ZRS"
  allow_blob_public_access = true
  tags = {
    environment = var.environment_name
    SpokeType   = "KFS"
  }
  network_rules {
    default_action = "Allow"
    virtual_network_subnet_ids = [
      azurerm_subnet.kfs_other_subnet.id,
      azurerm_subnet.kfs_aks_subnet.id,
      azurerm_subnet.kfs_pass_subnet.id]
    ip_rules = ["147.243.0.0/16"]
  }
  lifecycle {
    prevent_destroy = false
  }
}

resource "azurerm_private_dns_zone" "PRD-DNS" {
  name = "privatedns.azure.com"
  resource_group_name = azurerm_resource_group.KFSResourceGroup.name
}
resource "azurerm_key_vault" "AKV" {
  location = azurerm_resource_group.KFSResourceGroup.location
  name = lower(join("",[local.resource_prefix,"akv",var.env_seq]))
  resource_group_name = azurerm_resource_group.KFSResourceGroup.name
  sku_name = "standard"
  tenant_id = data.azurerm_client_config.current.tenant_id
  access_policy {
    object_id = data.azurerm_client_config.current.object_id
    tenant_id = data.azurerm_client_config.current.tenant_id
    key_permissions = ["Get","List","Delete"]
    secret_permissions = ["Backup", "Delete", "Get", "List", "Purge", "Recover", "Restore", "Set"]
    storage_permissions = ["Get"]
  }
  access_policy {
    object_id = azurerm_user_assigned_identity.AKSIDENTITY.principal_id
    tenant_id = data.azurerm_client_config.current.tenant_id
    key_permissions = ["Get","List","Delete"]
    secret_permissions = ["Backup", "Delete", "Get", "List", "Purge", "Recover", "Restore", "Set"]
    storage_permissions = ["Get"]
  }
}
resource "random_password" "postgrepassword" {
  length = 64
}
resource "azurerm_postgresql_server" "POSTGRES" {
  location = azurerm_resource_group.KFSResourceGroup.location
  name = lower(join("",[local.resource_prefix,"psql",var.env_seq]))
  resource_group_name = azurerm_resource_group.KFSResourceGroup.name
  sku_name = "GP_Gen5_4"
  version = "11"
  administrator_login = "psqladmin"
  administrator_login_password = random_password.postgrepassword.result
  backup_retention_days = 7
  auto_grow_enabled = true
  public_network_access_enabled = true
  ssl_enforcement_enabled = true
  ssl_minimal_tls_version_enforced = "TLS1_2"
  lifecycle {
    prevent_destroy = false
  }
  tags = {
    SpokeType   = "KFS"
    CICDStage   = var.environment_name
  }
  threat_detection_policy {
    enabled = true
    email_addresses = [var.threat_detection_email]
    storage_account_access_key = azurerm_storage_account.KFSStorage.primary_access_key
    storage_endpoint = azurerm_storage_account.KFSStorage.primary_blob_endpoint
  }
}
resource "azurerm_key_vault_secret" "store_pgsl_password" {
  key_vault_id = azurerm_key_vault.AKV.id
  name = lower(join("-",[local.resource_prefix,"psql",var.env_seq,"password"]))
  value = azurerm_postgresql_server.POSTGRES.administrator_login_password
}

resource "azurerm_redis_cache" "kfprdredis" {
  name                = lower(join("",[local.resource_prefix,"redis",var.env_seq]))
  location            = var.location
  resource_group_name = azurerm_resource_group.KFSResourceGroup.name
  capacity            = 1
  family              = "C"
  sku_name            = "Standard"
  enable_non_ssl_port = false
  minimum_tls_version = "1.2"
  tags = {
    SpokeType   = "PRD"
    CICDStage   = var.environment_name
  }

  redis_configuration {
  }
}
resource "azurerm_private_endpoint" "ENDPOINT5" {
  location = var.location
  name = "AKS-Redis-ENDPOINT"
  resource_group_name = azurerm_resource_group.KFSResourceGroup.name
  tags = {
    SpokeType   = "KFS"
    CICDStage   = var.environment_name
  }
  subnet_id = azurerm_subnet.kfs_aks_subnet.id
  private_service_connection {
    is_manual_connection = false
    name = "REDISLCONN"
    private_connection_resource_id = azurerm_redis_cache.kfprdredis.id
    subresource_names = ["redisCache"]
  }
  private_dns_zone_group {
    name = "dns_zone"
    private_dns_zone_ids = [azurerm_private_dns_zone.PRD-DNS.id]
  }
}
resource "azurerm_private_endpoint" "ENDPOINT4" {
  location = var.location
  name = "AKS-PGSQL-ENDPOINT"
  resource_group_name = azurerm_resource_group.KFSResourceGroup.name
  tags = {
    SpokeType   = "KFS"
    CICDStage   = var.environment_name
  }
  subnet_id = azurerm_subnet.kfs_aks_subnet.id
  private_service_connection {
    is_manual_connection = false
    name = "PGSQLCONN"
    private_connection_resource_id = azurerm_postgresql_server.POSTGRES.id
    subresource_names = ["postgresqlServer"]
  }
  private_dns_zone_group {
    name = "dns_zone"
    private_dns_zone_ids = [azurerm_private_dns_zone.PRD-DNS.id]
  }
}
resource "azurerm_log_analytics_workspace" "OMS" {
  location = azurerm_resource_group.KFSResourceGroup.location
  name = join("",[local.resource_prefix,"OMS",var.env_seq])
  resource_group_name = azurerm_resource_group.KFSResourceGroup.name
  tags = {
    SpokeType   = "KFS"
    CICDStage   = var.environment_name
  }
  sku = "PerGB2018"
  retention_in_days = 30
}
resource "azurerm_kubernetes_cluster" "AKSCLUSTER" {
  dns_prefix = join("-",[local.resource_prefix,"aks",var.env_seq,"dns"])
  location = azurerm_resource_group.KFSResourceGroup.location
  name = join("",[local.resource_prefix,"aks",var.env_seq])
  resource_group_name = azurerm_resource_group.KFSResourceGroup.name
  private_cluster_enabled = true
  tags = {
    environment = var.environment_name
    SpokeType   = "KFS"
  }
  default_node_pool {
    name = "default"
    vm_size = var.aks_vm_size
    type = "VirtualMachineScaleSets"
    enable_auto_scaling = true
    enable_node_public_ip = false
    max_count = 10
    min_count = 1
    vnet_subnet_id = azurerm_subnet.kfs_aks_subnet.id
  }
  identity {
    type = "UserAssigned"
    user_assigned_identity_id = azurerm_user_assigned_identity.AKSIDENTITY.id
  }
  role_based_access_control {
    enabled = true
  }

  network_profile {
    network_plugin = "azure"
    load_balancer_sku = "Standard"
    network_policy = "azure"
    service_cidr = var.aks_service_cidr
    docker_bridge_cidr = var.docker_bridge_cidr
    dns_service_ip = var.dns_service_ip
  }
  addon_profile {
    azure_policy {
    enabled = true
  }
}
}

resource "azurerm_app_configuration" "app_conf_kfs" {
  name                = join("-",[local.resource_prefix,"appcfg",var.env_seq,"dns"])
  resource_group_name = azurerm_resource_group.KFSResourceGroup.name
  location            = azurerm_resource_group.KFSResourceGroup.location
}
resource "azurerm_storage_account" "STORAGE-STATIC-WEB" {
  name                     = lower(join("",[local.resource_prefix,"sto",var.env_seq]))
  resource_group_name      = azurerm_resource_group.KFSResourceGroup.name
  location                 = azurerm_resource_group.KFSResourceGroup.location
  account_tier             = "Standard"
  account_replication_type = "ZRS"
  allow_blob_public_access = true
  shared_access_key_enabled = false
  tags = {
    environment = var.environment_name
    SpokeType   = "KFS"
  }
  network_rules {
    default_action = "Allow"
    virtual_network_subnet_ids = [
      azurerm_subnet.kfs_other_subnet.id,
      azurerm_subnet.kfs_aks_subnet.id,
      azurerm_subnet.kfs_pass_subnet.id]
    ip_rules = ["147.243.0.0/16"]
  }
  lifecycle {
    prevent_destroy = false
  }
  static_website {
    index_document = "index.html"
  }
}

resource "azurerm_cdn_profile" "CDN-PROFILE" {
  location = azurerm_resource_group.KFSResourceGroup.location
  name = lower(join("",[local.resource_prefix,"ael",var.env_seq]))
  resource_group_name = azurerm_resource_group.KFSResourceGroup.name
  sku = "Standard_Microsoft"
  tags = {
    SpokeType   = "KFS"
    CICDStage   = var.environment_name
  }
}
resource "azurerm_cdn_endpoint" "cdn-endpoint" {
  location = azurerm_resource_group.KFSResourceGroup.location
  name = lower(join("",[local.resource_prefix,"cde",var.env_seq]))
  profile_name = azurerm_cdn_profile.CDN-PROFILE.name
  resource_group_name = azurerm_resource_group.KFSResourceGroup.name
  origin {
    host_name = azurerm_storage_account.STORAGE-STATIC-WEB.primary_web_host
    name = "client-management"
  }
}
provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.AKSCLUSTER.kube_config.0.host
  username               = azurerm_kubernetes_cluster.AKSCLUSTER.kube_config.0.username
  password               = azurerm_kubernetes_cluster.AKSCLUSTER.kube_config.0.password
  client_certificate     = base64decode(azurerm_kubernetes_cluster.AKSCLUSTER.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.AKSCLUSTER.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.AKSCLUSTER.kube_config.0.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    client_certificate = base64decode(azurerm_kubernetes_cluster.AKSCLUSTER.kube_config.0.client_certificate)
    host = azurerm_kubernetes_cluster.AKSCLUSTER.kube_config.0.host
    client_key = base64decode(azurerm_kubernetes_cluster.AKSCLUSTER.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.AKSCLUSTER.kube_config.0.cluster_ca_certificate)
  }
}

resource "azurerm_application_insights" "APPAINSIGHT" {
  application_type = "web"
  location = azurerm_resource_group.KFSResourceGroup.location
  name = join("",[local.resource_prefix,"aai",var.env_seq])
  resource_group_name = azurerm_resource_group.KFSResourceGroup.name
  disable_ip_masking = false
  tags = {
    SpokeType   = "KFS"
    CICDStage   = var.environment_name
  }
}

output "RGName" {
  value = azurerm_resource_group.KFSResourceGroup.name
}
output "TenantID" {
  value = data.azurerm_client_config.current.tenant_id
}
output "AKSName" {
  value = azurerm_kubernetes_cluster.AKSCLUSTER.name
}
output "keyVaultName" {
  value = azurerm_key_vault.AKV.name
}
output "clientID" {
  value = azurerm_user_assigned_identity.AKSIDENTITY.client_id
}
output "IdentityID" {
  value = azurerm_user_assigned_identity.AKSIDENTITY.id
}
output "nodeRg" {
  value = azurerm_kubernetes_cluster.AKSCLUSTER.node_resource_group
}