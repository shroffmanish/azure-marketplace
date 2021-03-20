@description('vm configuration')
param vm object

@description('Network settings')
param networkSettings object


@description('the outer loop index')
param index int

@description('The name of the availability set')
param availabilitySet string

@description('additional data disks to attach')
param dataDisks int = 0

@description('Unique identifiers to allow the Azure Infrastructure to understand the origin of resources deployed to Azure. You do not need to supply a value for this.')
param elasticTags object = {
  provider: '648D2193-0CE0-4EFB-8A82-AF9792184FD9'
}

var namespace = vm.namespace
var computername = concat(vm.namespace, index)
var password_osProfile = {
  computername: computername
  adminUsername: vm.shared.credentials.adminUsername
  adminPassword: vm.shared.credentials.password
}
var sshPublicKey_osProfile = {
  computername: computername
  adminUsername: vm.shared.credentials.adminUsername
  linuxConfiguration: {
    disablePasswordAuthentication: 'true'
    ssh: {
      publicKeys: [
        {
          path: '/home/${vm.shared.credentials.adminUsername}/.ssh/authorized_keys'
          keyData: vm.shared.credentials.sshPublicKey
        }
      ]
    }
  }
}

var publicIpName_var = '${namespace}${index}-ip'

resource publicIpName 'Microsoft.Network/publicIPAddresses@2020-06-01' = if ((!empty(vm.nsg)) && vm.standardInternalLoadBalancer) {
  name: publicIpName_var
  location: vm.shared.location
  sku: {
    name: 'Standard'
  }
  tags: {
    provider: toUpper(elasticTags.provider)
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: concat(namespace, index, uniqueString(resourceGroup().id, deployment().name))
    }
  }
}


var nsgIpConfigs = [
  {}
  {
    networkSecurityGroup: {
      id: resourceId(networkSettings.resourceGroup,'Microsoft.Network/networkSecurityGroups', vm.nsg)
    }
  }
  {
    networkSecurityGroup: {
      id: resourceId(networkSettings.resourceGroup,'Microsoft.Network/networkSecurityGroups', vm.nsg)
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          primary: true
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId(networkSettings.resourceGroup, 'Microsoft.Network/virtualNetworks/subnets', networkSettings.name, networkSettings.subnet.name)
          }
          loadBalancerBackendAddressPools: vm.backendPools
          publicIPAddress: {
            id: publicIpName.id
          }
        }
      }
    ]
  }
]
var nsgIpConfig = nsgIpConfigs[(empty(vm.nsg) ? 0 : (vm.standardInternalLoadBalancer ? 2 : 1))]
var nicProperties = {
  primary: true
  enableAcceleratedNetworking: (vm.acceleratedNetworking == 'Yes')
  ipConfigurations: [
    {
      name: 'ipconfig1'
      properties: {
        privateIPAllocationMethod: 'Dynamic'
        subnet: {
          id: resourceId(networkSettings.resourceGroup, 'Microsoft.Network/virtualNetworks/subnets', networkSettings.name, networkSettings.subnet.name)
        }
        loadBalancerBackendAddressPools: vm.backendPools
      }
    }
  ]
}


resource namespace_index_nic 'Microsoft.Network/networkInterfaces@2020-06-01' = {
  name: '${namespace}${index}-nic'
  location: vm.shared.location
  tags: {
    provider: toUpper(elasticTags.provider)
  }
  properties: union(nicProperties, nsgIpConfig)
}

resource namespace_index 'Microsoft.Compute/virtualMachines@2020-06-01' = {
  name: concat(namespace, index)
  location: vm.shared.location
  tags: {
    provider: toUpper(elasticTags.provider)
  }
  properties: {
    availabilitySet: {
      id: resourceId('Microsoft.Compute/availabilitySets', availabilitySet)
    }
    hardwareProfile: {
      vmSize: vm.size
    }
    osProfile:'${vm.shared.credentials.authenticationType}_osProfile' == 'password_osProfile' ? password_osProfile : sshPublicKey_osProfile
    storageProfile: {
      imageReference: vm.imageReference
      osDisk: {
        name: '${namespace}${index}-osdisk'
        managedDisk: {
          storageAccountType: vm.storageAccountType
        }
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
      dataDisks: [for j in range(0, dataDisks): {
        name:  '${namespace}${j}-datadisk'
        diskSizeGB: 1024
        lun: j
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
        caching: 'None'
        createOption: 'Empty'
      }]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: namespace_index_nic.id
        }
      ]
    }
  }
  dependsOn: [
    namespace_index_nic
  ]
}

resource namespace_index_script 'Microsoft.Compute/virtualMachines/extensions@2020-06-01' = {
  name: '${namespace}${index}/script'
  location: vm.shared.location
  properties: vm.installScript
  dependsOn: [
    namespace_index
  ]
}
