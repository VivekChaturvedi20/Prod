
#set the environment variable AZURE_DEVOPS_EXT_PAT

Param(
    [Parameter(Mandatory=$true)]
    [string]
    $rgName,

    [Parameter(Mandatory=$true)]
    [string]
    $storageAccountName,

    [Parameter(Mandatory=$true)]
    [string]
    $identity_name,
  
    [Parameter(Mandatory=$true)]
    [string]
    $identity_group,

    [Parameter(Mandatory=$true)]
    [string]
    $ARM_CLIENT_ID,

    [Parameter(Mandatory=$true)]
    [string]
    $ARM_CLIENT_SECRET,

    [Parameter(Mandatory=$true)]
    [string]
    $ARM_TENANT_ID,
  
    [Parameter(Mandatory=$true)]
    [string]
    $ARM_SUBSCRIPTION_ID
    
)


az login --service-principal --username $ARM_CLIENT_ID --password $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID
az account set --subscription $ARM_SUBSCRIPTION_ID

Write-Host "resource group name: $rgName"
$rg = az group create --name $rgName --location eastus
$rg | ConvertFrom-Json

Write-Host "storage account name: $storageAccountName"
$storageAccount = az storage account create -n $storageAccountName -g $rgName -l eastus --sku Standard_LRS --allow-blob-public-access false --access-tier Hot --kind StorageV2 --min-tls-version TLS1_2
$storageAccount | ConvertFrom-Json

$access_key = az storage account keys list --account-name $storageAccountName -g $rgName --query [0].value
Write-Host "access key: $access_key"

$cont_name = "state-files"
Write-Host "container name: $cont_name"
$container = az storage container create --name $cont_name --account-key $access_key --account-name $storageAccountName -g $rgName

az devops login --organization https://dev.azure.com/KFsell
az devops configure -d project=devops

$stage_two_vargroup = az pipelines variable-group list --group-name stage2-vars --query [0].id
az pipelines variable-group variable update --group-id $stage_two_vargroup --name devOps_storage --value $storageAccountName --prompt-value true
az pipelines variable-group variable update --group-id $stage_two_vargroup --name devOps_storage_key --value $access_key --prompt-value true
az pipelines variable-group variable update --group-id $stage_two_vargroup --name devOps_rg --value $rgName --prompt-value true
az pipelines variable-group variable update --group-id $stage_two_vargroup --name devOps_cont --value $cont_name --prompt-value true
az pipelines variable-group variable update --group-id $stage_two_vargroup --name managed_identity --value $identity_name --prompt-value true
az pipelines variable-group variable update --group-id $stage_two_vargroup --name managed_identity_group --value $identity_group --prompt-value true
<#az pipelines variable-group variable update --group-id $stage_two_vargroup --name docker_bridge_cidr --value $docker_bridge_cidr --prompt-value true
az pipelines variable-group variable update --group-id $stage_two_vargroup --name aks_service_cidr --value $aks_service_cidr --prompt-value true
az pipelines variable-group variable update --group-id $stage_two_vargroup --name dns_service_ip --value $dns_service_ip --prompt-value true
az pipelines variable-group variable update --group-id $stage_two_vargroup --name environments --value $environments --prompt-value true
az pipelines variable-group variable update --group-id $stage_two_vargroup --name choose_rg --value $choose_rg --prompt-value true
az pipelines variable-group variable update --group-id $stage_two_vargroup --name vnet_address_space --value $vnet_address_space --prompt-value true#>
az pipelines variable-group variable update --group-id $stage_two_vargroup --name nextEnvSeq --value 1 --prompt-value true


#run prod infra pipeline

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", "Basic OnJjcWd0cXJocHZseDV0M29jN3Rqejc0Zm5qNWc2cnFlcWdiaWZtMm9wdGphdHlsYjdqanE=")
$headers.Add("Content-Type", "application/json")

 

$body = "{
`n    
`n}"

 

$response = Invoke-RestMethod 'https://dev.azure.com/KFsell/DevOps/_apis/pipelines/45/runs?api-version=6.0-preview.1' -Method 'POST' -Headers $headers -Body $body
$response | ConvertTo-Json