@description('vm configuration')
param vm object

@description('Unique identifiers to allow the Azure Infrastructure to understand the origin of resources deployed to Azure. You do not need to supply a value for this.')
param elasticTags object = {
  provider: '648D2193-0CE0-4EFB-8A82-AF9792184FD9'
}

var namespace = vm.namespace

resource av_set 'Microsoft.Compute/availabilitySets@2019-03-01' = {
  name: 'av-set'
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

module namespace_vm_creation '../partials/vm.bicep' = {
  name: '${namespace}-vm-creation'
  params: {
    vm: vm
    availabilitySet: '${namespace}av-set'
    index: 1
    elasticTags: elasticTags
  }
  dependsOn: [
    av_set
  ]
}