@description('Location where resources will be provisioned')
param location string

@description('The unique namespace for the Kibana VM')
param namespace string

@description('Network settings')
param networkSettings object

@description('Credentials information block')
@secure()
param credentials object

@description('Platform and OS settings')
param osSettings object

@description('Size of the Kibana VM')
param vmSize string = 'Standard_A1'

@allowed([
  'Yes'
  'No'
])
@description('Whether to enable accelerated networking for Kibana, which enables single root I/O virtualization (SR-IOV) to a VM, greatly improving its networking performance. Valid only for specific VM SKUs')
param acceleratedNetworking string = 'No'

@description('Unique identifiers to allow the Azure Infrastructure to understand the origin of resources deployed to Azure. You do not need to supply a value for this.')
param elasticTags object = {
  provider: '648D2193-0CE0-4EFB-8A82-AF9792184FD9'
}

var namespace_var = namespace
var subnetId = resourceId(networkSettings.resourceGroup, 'Microsoft.Network/virtualNetworks/subnets', networkSettings.name, networkSettings.subnet.name)
var publicIpName = '${namespace_var}-ip'
var securityGroupName_var = '${namespace_var}-nsg'
var nicName_var = '${namespace_var}-nic'
var password_osProfile = {
  computername: namespace
  adminUsername: credentials.adminUsername
  adminPassword: credentials.password
}

var sshPublicKey_osProfile = {
  computername: namespace
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

resource securityGroupName 'Microsoft.Network/networkSecurityGroups@2020-06-01' = {
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
          description: 'Allows inbound SSH traffic from anyone'
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
      {
        name: 'Kibana'
        properties: {
          description: 'Allows inbound Kibana traffic from anyone'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '5601'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 200
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource nicName 'Microsoft.Network/networkInterfaces@2020-06-01' = {
  name: nicName_var
  location: location
  tags: {
    provider: toUpper(elasticTags.provider)
  }
  properties: {
    enableAcceleratedNetworking: (acceleratedNetworking == 'Yes')
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: resourceId('Microsoft.Network/publicIPAddresses', publicIpName)
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

resource namespace_resource 'Microsoft.Compute/virtualMachines@2020-06-01' = {
  name: namespace
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

resource namespace_script 'Microsoft.Compute/virtualMachines/extensions@2020-06-01' = {
  name: '${namespace_var}/script'
  location: location
  properties: osSettings.extensionSettings.kibana
  dependsOn: [
    namespace_resource
  ]
}