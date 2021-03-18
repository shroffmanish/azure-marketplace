@description('Location where resources will be provisioned')
param location string

@description('Storage account used for share virtual machine images')
param storageAccountName string

@description('Existing storage account used to configure Azure Repository plugin')
param azureCloudStorageAccount object = {
  name: ''
  resourceGroup: ''
  install: 'No'
}

@description('Unique identifiers to allow the Azure Infrastructure to understand the origin of resources deployed to Azure. You do not need to supply a value for this.')
param elasticTags object = {
  provider: '648D2193-0CE0-4EFB-8A82-AF9792184FD9'
}

resource storageAccountName_resource 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'Storage'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: [
        {
          value: '103.118.162.214'
          action: 'Allow'
        }
        {
          value: '103.78.109.73'
          action: 'Allow'
        }
        {
          value: '165.225.114.0/23'
          action: 'Allow'
        }
        {
          value: '175.45.116.0/24'
          action: 'Allow'
        }
        {
          value: '165.225.98.0/24'
          action: 'Allow'
        }
      ]
      defaultAction: 'Deny'
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
  tags: {
    provider: toUpper(elasticTags.provider)
  }
}

output sharedStorageAccountName string = storageAccountName_resource.name
output sharedStorageAccountKey string = listKeys(storageAccountName_resource.id, '2019-04-01').keys[0].value
output sharedStorageAccountSuffix string = replace(replace(reference(storageAccountName).primaryEndpoints.blob, 'https://${storageAccountName}.blob.', ''), '/', '')
output existingStorageAccountKey string = (((!empty(azureCloudStorageAccount.name)) && (azureCloudStorageAccount.install == 'Yes')) ? listKeys(resourceId(azureCloudStorageAccount.resourceGroup, 'Microsoft.Storage/storageAccounts', azureCloudStorageAccount.name), '2019-04-01').keys[0].value : '')
output existingStorageAccountSuffix string = (((!empty(azureCloudStorageAccount.name)) && (azureCloudStorageAccount.install == 'Yes')) ? replace(replace(reference(resourceId(azureCloudStorageAccount.resourceGroup, 'Microsoft.Storage/storageAccounts', azureCloudStorageAccount.name), '2019-04-01').primaryEndpoints.blob, 'https://${azureCloudStorageAccount.name}.blob.', ''), '/', '') : '')