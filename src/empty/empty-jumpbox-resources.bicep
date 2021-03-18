@description('Location where resources will be provisioned')
param location string
param namespace string = ''

@description('Network settings')
param networkSettings object

@description('Credential information block')
@secure()
param credentials object

@description('Elasticsearch deployment platform settings')
param osSettings object

@description('Unique identifiers to allow the Azure Infrastructure to understand the origin of resources deployed to Azure. You do not need to supply a value for this.')
param elasticTags object = {
  provider: '648D2193-0CE0-4EFB-8A82-AF9792184FD9'
}

output ssh string = 'N/A'