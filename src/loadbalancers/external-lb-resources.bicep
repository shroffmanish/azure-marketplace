@description('Network settings object')
param networkSettings object

@description('Application Gateway settings')
param applicationGatewaySettings object

@description('Unique identifiers to allow the Azure Infrastructure to understand the origin of resources deployed to Azure. You do not need to supply a value for this.')
param elasticTags object = {
  provider: '648D2193-0CE0-4EFB-8A82-AF9792184FD9'
}

var httpsOpts = {
  Yes: 'https://'
  No: 'http://'
}
var https = httpsOpts[networkSettings.https]
var internalLoadBalancerName_var = '${networkSettings.namespacePrefix}internal-lb'
var externalLoadBalancerName_var = '${networkSettings.namespacePrefix}external-lb'
var externalLoadBalancerIp_var = '${networkSettings.namespacePrefix}external-lb-ip'

resource internalLoadBalancerName 'Microsoft.Network/loadBalancers@2020-06-01' = {
  name: internalLoadBalancerName_var
  location: networkSettings.location
  sku: {
    name: networkSettings.internalSku
  }
  tags: {
    provider: toUpper(elasticTags.provider)
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'LBFE'
        properties: {
          subnet: {
            id: resourceId(networkSettings.resourceGroup, 'Microsoft.Network/virtualNetworks/subnets', networkSettings.name, networkSettings.subnet.name)
          }
          privateIPAddress: networkSettings.subnet.loadBalancerIp
          privateIPAllocationMethod: 'Static'
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'LBBE'
      }
    ]
    loadBalancingRules: [
      {
        name: 'es-http-internal'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', internalLoadBalancerName_var, 'LBFE')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', internalLoadBalancerName_var, 'LBBE')
          }
          protocol: 'Tcp'
          frontendPort: 9200
          backendPort: 9200
          enableFloatingIP: false
          idleTimeoutInMinutes: 5
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', internalLoadBalancerName_var, 'es-probe-internal-http')
          }
        }
      }
      {
        name: 'es-transport-internal'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', internalLoadBalancerName_var, 'LBFE')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', internalLoadBalancerName_var, 'LBBE')
          }
          protocol: 'Tcp'
          frontendPort: 9300
          backendPort: 9300
          enableFloatingIP: false
          idleTimeoutInMinutes: 5
        }
      }
    ]
    probes: [
      {
        name: 'es-probe-internal-http'
        properties: {
          protocol: 'Tcp'
          port: 9200
          intervalInSeconds: 30
          numberOfProbes: 3
        }
      }
    ]
  }
}

resource externalLoadBalancerIp 'Microsoft.Network/publicIPAddresses@2020-06-01' = {
  name: externalLoadBalancerIp_var
  location: networkSettings.location
  sku: {
    name: networkSettings.externalSku
  }
  tags: {
    provider: toUpper(elasticTags.provider)
  }
  properties: {
    publicIPAllocationMethod: ((networkSettings.externalSku == 'Standard') ? 'Static' : 'Dynamic')
    dnsSettings: {
      domainNameLabel: 'lb-${uniqueString(resourceGroup().id, deployment().name)}'
    }
  }
}

resource externalLoadBalancerName 'Microsoft.Network/loadBalancers@2020-06-01' = {
  name: externalLoadBalancerName_var
  location: networkSettings.location
  sku: {
    name: networkSettings.externalSku
  }
  tags: {
    provider: toUpper(elasticTags.provider)
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'LBFE'
        properties: {
          publicIPAddress: {
            id: externalLoadBalancerIp.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'LBBE'
      }
    ]
    loadBalancingRules: [
      {
        name: 'es-http-external'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', externalLoadBalancerName_var, 'LBFE')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', externalLoadBalancerName_var, 'LBBE')
          }
          protocol: 'Tcp'
          frontendPort: 9200
          backendPort: 9201
          enableFloatingIP: false
          idleTimeoutInMinutes: 5
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', externalLoadBalancerName_var, 'es-http-external-probe')
          }
        }
      }
    ]
    probes: [
      {
        name: 'es-http-external-probe'
        properties: {
          protocol: 'Tcp'
          port: 9201
          intervalInSeconds: 30
          numberOfProbes: 3
        }
      }
    ]
  }
}

output fqdn string = '${https}${reference(externalLoadBalancerIp_var).dnsSettings.fqdn}:9200'