@description('Network settings object')
param networkSettings object

@description('Application Gateway settings')
param applicationGatewaySettings object

@description('Unique identifiers to allow the Azure Infrastructure to understand the origin of resources deployed to Azure. You do not need to supply a value for this.')
param elasticTags object = {
  provider: '648D2193-0CE0-4EFB-8A82-AF9792184FD9'
}

var applicationGatewayName_var = '${networkSettings.namespacePrefix}app-gateway'
var applicationGatewayIp_var = '${networkSettings.namespacePrefix}app-gateway-ip'
var internalLoadBalancerName_var = '${networkSettings.namespacePrefix}internal-lb'
var applicationGatewayId = applicationGatewayName.id
var authenticationCertsOpts = {
  Yes: [
    {
      properties: {
        data: applicationGatewaySettings.backendCert
      }
      name: 'esHttpCert'
    }
  ]
  No: []
}
var authenticationCerts = authenticationCertsOpts[(empty(applicationGatewaySettings.backendCert) ? 'No' : 'Yes')]
var backendCertsOpts = {
  Yes: [
    {
      id: '${applicationGatewayId}/authenticationCertificates/esHttpCert'
    }
  ]
  No: []
}
var backendCerts = backendCertsOpts[(empty(applicationGatewaySettings.backendCert) ? 'No' : 'Yes')]
var wafEnabledOpts = {
  Enabled: true
  Disabled: false
}
var wafEnabled = wafEnabledOpts[applicationGatewaySettings.firewallStatus]

resource internalLoadBalancerName 'Microsoft.Network/loadBalancers@2019-04-01' = {
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

resource applicationGatewayIp 'Microsoft.Network/publicIPAddresses@2019-04-01' = {
  name: applicationGatewayIp_var
  location: networkSettings.location
  tags: {
    provider: toUpper(elasticTags.provider)
  }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource applicationGatewayName 'Microsoft.Network/applicationGateways@2019-04-01' = {
  name: applicationGatewayName_var
  location: networkSettings.location
  tags: {
    provider: toUpper(elasticTags.provider)
  }
  properties: {
    sku: {
      name: applicationGatewaySettings.skuName
      tier: applicationGatewaySettings.tier
      capacity: applicationGatewaySettings.instanceCount
    }
    sslCertificates: [
      {
        name: 'es-app-gateway-sslcert'
        properties: {
          data: applicationGatewaySettings.certBlob
          password: applicationGatewaySettings.certPassword
        }
      }
    ]
    authenticationCertificates: authenticationCerts
    gatewayIPConfigurations: [
      {
        name: 'es-app-gateway-ip'
        properties: {
          subnet: {
            id: resourceId(networkSettings.resourceGroup, 'Microsoft.Network/virtualNetworks/subnets', networkSettings.name, networkSettings.applicationGatewaySubnet.name)
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'es-app-gateway-fip'
        properties: {
          publicIPAddress: {
            id: applicationGatewayIp.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'es-app-gateway-fport'
        properties: {
          port: 9200
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'LBBE'
        properties: {
          backendAddresses: [
            {
              ipAddress: networkSettings.subnet.loadBalancerIp
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'es-app-gateway-httpsettings'
        properties: {
          port: 9200
          protocol: applicationGatewaySettings.backendProtocol
          cookieBasedAffinity: 'Disabled'
          authenticationCertificates: backendCerts
          probeEnabled: true
          probe: {
            id: '${applicationGatewayId}/probes/es-app-gateway-probe'
          }
          requestTimeout: 86400
        }
      }
    ]
    httpListeners: [
      {
        name: 'es-app-gateway-httplistener'
        properties: {
          frontendIPConfiguration: {
            id: '${applicationGatewayId}/frontendIPConfigurations/es-app-gateway-fip'
          }
          frontendPort: {
            id: '${applicationGatewayId}/frontendPorts/es-app-gateway-fport'
          }
          protocol: 'Https'
          sslCertificate: {
            id: '${applicationGatewayId}/sslCertificates/es-app-gateway-sslcert'
          }
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'rule1'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: '${applicationGatewayId}/httpListeners/es-app-gateway-httplistener'
          }
          backendAddressPool: {
            id: '${applicationGatewayId}/backendAddressPools/LBBE'
          }
          backendHttpSettings: {
            id: '${applicationGatewayId}/backendHttpSettingsCollection/es-app-gateway-httpsettings'
          }
        }
      }
    ]
    webApplicationFirewallConfiguration: {
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.0'
      enabled: wafEnabled
      firewallMode: applicationGatewaySettings.firewallMode
    }
    probes: [
      {
        name: 'es-app-gateway-probe'
        properties: {
          protocol: applicationGatewaySettings.backendProtocol
          path: '/'
          host: '127.0.0.1'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          match: {
            statusCodes: [
              '200-399'
              '401'
            ]
            body: ''
          }
        }
      }
    ]
  }
}

output fqdn string = 'N/A'