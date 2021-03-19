@description('vm configuration')
param vm object

@description('Storage Account Settings')
param storageSettings object

@description('Unique identifiers to allow the Azure Infrastructure to understand the origin of resources deployed to Azure. You do not need to supply a value for this.')
param elasticTags object = {
  provider: '648D2193-0CE0-4EFB-8A82-AF9792184FD9'
}

var namespace = vm.namespace
var avSetCount = (((vm.count - 1) / 100) + 1)
var diskCount = ((storageSettings.dataDisks > 0) ? storageSettings.dataDisks : 1)

resource namespace_av_set 'Microsoft.Compute/availabilitySets@2019-03-01' = {
  name: '${namespace}-av-set'
  location: vm.shared.location
  tags: {
    provider: toUpper(elasticTags.provider)
  }
  properties: {
    platformUpdateDomainCount: 20
    platformFaultDomainCount: vm.platformFaultDomainCount
  }
  sku: {
    name: 'Aligned'
  }
}

module namespace_vm_creation '../partials/vm.bicep' = if (storageSettings.dataDisks > 0) {
  name: '${namespace}-vm-creation'
  params: {
    vm: vm
    index: 1
    availabilitySet: '${namespace}${avSetCount}-av-set'
    dataDisks: {
      name: 'disks'
      count: diskCount
      input: {
        name: '${namespace}-datadisk1'
        diskSizeGB: storageSettings.diskSize
        lun: '1'
        managedDisk: {
          storageAccountType: storageSettings.accountType
        }
        caching: 'None'
        createOption: 'Empty'
      }
    }
    elasticTags: elasticTags
  }
  dependsOn: [
    namespace_av_set
  ]
}

module namespace_vm_nodisks_creation '../partials/vm.bicep' = if (storageSettings.dataDisks == 0) {
  name: '${namespace}-vm-nodisks-creation'
  params: {
    vm: vm
    index: 1
    availabilitySet: '${namespace}${avSetCount}-av-set'
    elasticTags: elasticTags
  }
  dependsOn: [
    namespace_av_set
  ]
}