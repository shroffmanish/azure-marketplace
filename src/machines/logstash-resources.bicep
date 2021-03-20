@description('vm configuration')
param vm object

@description('Network settings')
param networkSettings object

@description('Unique identifiers to allow the Azure Infrastructure to understand the origin of resources deployed to Azure. You do not need to supply a value for this.')
param elasticTags object = {
  provider: '648D2193-0CE0-4EFB-8A82-AF9792184FD9'
}

var namespace = vm.namespace

resource namespace_av_set 'Microsoft.Compute/availabilitySets@2020-06-01' = {
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

module namespace_vm_creation '../partials/vm.bicep'  = {
  name: '${namespace}-vm-creation'
  params: {
    vm: vm
    networkSettings: networkSettings
    availabilitySet: namespace_av_set.name
    index: 1
    elasticTags: elasticTags
  }
  dependsOn: [
    namespace_av_set
  ]
}