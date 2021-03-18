@description('Network settings object')
param networkSettings object

@allowed([
  'internal'
  'external'
  'gateway'
])
@description('Set up an internal or external load balancer, or use Application Gateway (gateway) for load balancing and SSL offload. If you are setting up Elasticsearch on a publicly available endpoint, it is *strongly recommended* to secure your nodes with a product like Elastic\'s X-Pack Security')
param loadBalancerType string = 'internal'

@description('Unique identifiers to allow the Azure Infrastructure to understand the origin of resources deployed to Azure. You do not need to supply a value for this.')
param elasticTags object = {
  provider: '648D2193-0CE0-4EFB-8A82-AF9792184FD9'
}

var subnetsOpts = [
  [
    {
      name: networkSettings.subnet.name
      properties: {
        addressPrefix: networkSettings.subnet.addressPrefix
      }
    }
    {
      name: networkSettings.applicationGatewaySubnet.name
      properties: {
        addressPrefix: networkSettings.applicationGatewaySubnet.addressPrefix
      }
    }
  ]
  [
    {
      name: networkSettings.subnet.name
      properties: {
        addressPrefix: networkSettings.subnet.addressPrefix
      }
    }
  ]
]
var subnets = subnetsOpts[((loadBalancerType == 'gateway') ? 0 : 1)]

resource networkSettings_name 'Microsoft.Network/virtualNetworks@2019-04-01' = {
  name: networkSettings.name
  location: networkSettings.location
  tags: {
    provider: toUpper(elasticTags.provider)
  }
  properties: {
    addressSpace: {
      addressPrefixes: [
        networkSettings.addressPrefix
      ]
    }
    subnets: subnets
  }
}