@description('Location where resources will be provisioned')
param location string

@description('The unique namespace for the Kibana VM')
param namespace string

@allowed([
  'Yes'
  'No'
])
@description('Controls if the output address should be HTTP or HTTPS')
param https string = 'No'

@description('Unique identifiers to allow the Azure Infrastructure to understand the origin of resources deployed to Azure. You do not need to supply a value for this.')
param elasticTags object = {
  provider: '648D2193-0CE0-4EFB-8A82-AF9792184FD9'
}


var namespace_var = namespace
var publicIpName_var = '${namespace_var}-ip'
var httpsOpts = {
  Yes: 'https://'
  No: 'http://'
}
var https_var = httpsOpts[https]

resource publicIpName 'Microsoft.Network/publicIPAddresses@2020-06-01' = {
  name: publicIpName_var
  location: location
  tags: {
    provider: toUpper(elasticTags.provider)
  }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: 'kb-${uniqueString(location, publicIpName_var)}'
    }
  } 
}

output fqdn string = '${https_var}${reference(publicIpName_var).dnsSettings.fqdn}:5601'