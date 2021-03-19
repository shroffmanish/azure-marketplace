@description('Location where resources will be provisioned')
param location string

@description('The unique namespace for jumpbox nodes')
param namespace string

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

var namespace_var = namespace
var vmSize = 'Standard_A0'
var osType = '${credentials.authenticationType}_osProfile'
var subnetId = resourceId(networkSettings.resourceGroup, 'Microsoft.Network/virtualNetworks/subnets', networkSettings.name, networkSettings.subnet.name)
var publicIpName_var = '${namespace_var}-ip'
var securityGroupName_var = '${namespace_var}-nsg'
var nicName_var = '${namespace_var}-nic'
var password_osProfile = {
  computername: namespace_var
  adminUsername: credentials.adminUsername
  adminPassword: credentials.password
}
var sshPublicKey_osProfile = {
  computername: namespace_var
  adminUsername: credentials.adminUsername
  linuxConfiguration: {
    disablePasswordAuthentication: 'true'
    ssh: {
      publicKeys: [
        {
          path: '/home/${credentials.adminUsername}/.ssh/authorized_keys'
          keyData: credentials.sshPublicKey
        }
      ]
    }
  }
}

resource securityGroupName 'Microsoft.Network/networkSecurityGroups@2019-04-01' = {
  name: securityGroupName_var
  location: location
  tags: {
    provider: toUpper(elasticTags.provider)
  }
  properties: {
    securityRules: [
      {
        name: 'SSH'
        properties: {
          description: 'Allows SSH traffic'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: osSettings.managementPort
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource publicIpName 'Microsoft.Network/publicIPAddresses@2019-04-01' = {
  name: publicIpName_var
  location: location
  tags: {
    provider: toUpper(elasticTags.provider)
  }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: 'jump-${uniqueString(resourceGroup().id, deployment().name)}'
    }
  }
}

resource nicName 'Microsoft.Network/networkInterfaces@2019-04-01' = {
  name: nicName_var
  location: location
  tags: {
    provider: toUpper(elasticTags.provider)
  }
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIpName.id
          }
          subnet: {
            id: subnetId
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: securityGroupName.id
    }
  }
}

resource namespace_resource 'Microsoft.Compute/virtualMachines@2019-03-01' = {
  name: namespace_var
  location: location
  tags: {
    provider: toUpper(elasticTags.provider)
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: '${credentials.authenticationType}_osProfile' == 'password_osProfile' ? password_osProfile : sshPublicKey_osProfile
    storageProfile: {
      imageReference: osSettings.imageReference
      osDisk: {
        name: '${namespace_var}-osdisk'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicName.id
        }
      ]
    }
  }
}

output ssh string = '${credentials.adminUsername}@${reference(publicIpName_var).dnsSettings.fqdn}'