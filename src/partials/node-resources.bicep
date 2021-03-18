@description('The base URI where artifacts required by this template are located including a trailing \'/\'')
param artifactsLocation string

@description('The sasToken required to access _artifactsLocation.  When the template is deployed using the accompanying scripts, a sasToken will be automatically generated. Use the defaultValue if the staging location is not secured.')
@secure()
param artifactsLocationSasToken string = ''

@description('Operating system settings')
param osSettings object

@description('Shared VM settings')
param commonVmSettings object

@description('Aggregate for topology variable')
param topologySettings object

@description('Network settings')
param networkSettings object

@description('Unique identifiers to allow the Azure Infrastructure to understand the origin of resources deployed to Azure. You do not need to supply a value for this.')
param elasticTags object = {
  provider: '648D2193-0CE0-4EFB-8A82-AF9792184FD9'
}

var jumpboxTemplates = {
  No: 'empty/empty-jumpbox-resources.json'
  Yes: 'machines/jumpbox-resources.json'
}
var jumpboxTemplateUrl = uri(artifactsLocation, concat(jumpboxTemplates[topologySettings.jumpbox], artifactsLocationSasToken))
var kibanaTemplates = {
  No: 'empty/empty-kibana-resources.json'
  Yes: 'machines/kibana-resources.json'
}
var kibanaTemplateUrl = uri(artifactsLocation, concat(kibanaTemplates[topologySettings.kibana], artifactsLocationSasToken))
var dataTemplateUrl = uri(artifactsLocation, 'machines/data-nodes-resources.json${artifactsLocationSasToken}')
var locations = {
  eastus: {
    platformFaultDomainCount: 3
  }
  eastus2: {
    platformFaultDomainCount: 3
  }
  centralus: {
    platformFaultDomainCount: 3
  }
  northcentralus: {
    platformFaultDomainCount: 3
  }
  southcentralus: {
    platformFaultDomainCount: 3
  }
  westus: {
    platformFaultDomainCount: 3
  }
  canadacentral: {
    platformFaultDomainCount: 3
  }
  northeurope: {
    platformFaultDomainCount: 3
  }
  westeurope: {
    platformFaultDomainCount: 3
  }
}
var normalizedLocation = replace(toLower(commonVmSettings.location), ' ', '')
var platformFaultDomainCount = (contains(locations, normalizedLocation) ? locations[normalizedLocation].platformFaultDomainCount : 2)
var vmAcceleratedNetworking = [
  'Standard_D2_v2'
  'Standard_D3_v2'
  'Standard_D4_v2'
  'Standard_D5_v2'
  'Standard_D11_v2'
  'Standard_D12_v2'
  'Standard_D13_v2'
  'Standard_D14_v2'
  'Standard_D15_v2'
  'Standard_DS2_v2'
  'Standard_DS3_v2'
  'Standard_DS4_v2'
  'Standard_DS5_v2'
  'Standard_DS11_v2'
  'Standard_DS12_v2'
  'Standard_DS13_v2'
  'Standard_DS14_v2'
  'Standard_DS15_v2'
  'Standard_F2'
  'Standard_F4'
  'Standard_F8'
  'Standard_F16'
  'Standard_F2s'
  'Standard_F4s'
  'Standard_F8s'
  'Standard_F16s'
  'Standard_D4_v3'
  'Standard_D8_v3'
  'Standard_D16_v3'
  'Standard_D32_v3'
  'Standard_D64_v3'
  'Standard_D4s_v3'
  'Standard_D8s_v3'
  'Standard_D16s_v3'
  'Standard_D32s_v3'
  'Standard_D64s_v3'
  'Standard_E4_v3'
  'Standard_E8_v3'
  'Standard_E16_v3'
  'Standard_E32_v3'
  'Standard_E64_v3'
  'Standard_E64i_v3'
  'Standard_E4s_v3'
  'Standard_E8s_v3'
  'Standard_E16s_v3'
  'Standard_E32s_v3'
  'Standard_E64s_v3'
  'Standard_E64is_v3'
  'Standard_F4s_v2'
  'Standard_F8s_v2'
  'Standard_F16s_v2'
  'Standard_F32s_v2'
  'Standard_F64s_v2'
  'Standard_F72s_v2'
  'Standard_M8ms'
  'Standard_M16ms'
  'Standard_M32ts'
  'Standard_M32ls'
  'Standard_M32ms'
  'Standard_M64s'
  'Standard_M64ls'
  'Standard_M64ms'
  'Standard_M128s'
  'Standard_M128ms'
  'Standard_M64'
  'Standard_M64m'
  'Standard_M128'
  'Standard_M128m'
]
var vmNsgName_var = '${commonVmSettings.namespacePrefix}standard-lb-nsg'
var vmNsgProperties = [
  {}
  {
    securityRules: [
      {
        name: 'External'
        properties: {
          description: 'Allows inbound traffic from Standard External LB'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '9201'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
    ]
  }
]
var standardInternalLoadBalancer = (networkSettings.internalSku == 'Standard')
var standardExternalLoadBalancer = (networkSettings.externalSku == 'Standard')
var standardInternalOrExternalLoadBalancer = (standardInternalLoadBalancer || standardExternalLoadBalancer)

module master_nodes '?' /*TODO: replace with correct path to [uri(parameters('_artifactsLocation'), concat('machines/master-nodes-resources.json', parameters('_artifactsLocationSasToken')))]*/ = if (topologySettings.dataNodesAreMasterEligible == 'No') {
  name: 'master-nodes'
  params: {
    '_artifactsLocation': artifactsLocation
    '_artifactsLocationSasToken': artifactsLocationSasToken
    vm: {
      shared: commonVmSettings
      namespace: '${commonVmSettings.namespacePrefix}master-'
      installScript: osSettings.extensionSettings.master
      size: topologySettings.vmSizeMasterNodes
      storageAccountType: 'Standard_LRS'
      count: 3
      backendPools: []
      imageReference: osSettings.imageReference
      platformFaultDomainCount: platformFaultDomainCount
      acceleratedNetworking: ((topologySettings.vmMasterNodeAcceleratedNetworking == 'Default') ? (contains(vmAcceleratedNetworking, topologySettings.vmSizeMasterNodes) ? 'Yes' : 'No') : topologySettings.vmMasterNodeAcceleratedNetworking)
      nsg: ''
      standardInternalLoadBalancer: false
    }
    elasticTags: elasticTags
  }
  dependsOn: []
}

resource vmNsgName 'Microsoft.Network/networkSecurityGroups@2019-04-01' = if (standardInternalOrExternalLoadBalancer) {
  name: vmNsgName_var
  location: commonVmSettings.location
  tags: {
    provider: toUpper(elasticTags.provider)
  }
  properties: vmNsgProperties[(standardExternalLoadBalancer ? 1 : 0)]
}

module client_nodes '?' /*TODO: replace with correct path to [uri(parameters('_artifactsLocation'), concat('machines/client-nodes-resources.json', parameters('_artifactsLocationSasToken')))]*/ = if (topologySettings.vmClientNodeCount > 0) {
  name: 'client-nodes'
  params: {
    '_artifactsLocation': artifactsLocation
    '_artifactsLocationSasToken': artifactsLocationSasToken
    vm: {
      shared: commonVmSettings
      namespace: '${commonVmSettings.namespacePrefix}client-'
      installScript: osSettings.extensionSettings.client
      size: topologySettings.vmSizeClientNodes
      count: topologySettings.vmClientNodeCount
      storageAccountType: 'Standard_LRS'
      backendPools: topologySettings.loadBalancerBackEndPools
      imageReference: osSettings.imageReference
      platformFaultDomainCount: platformFaultDomainCount
      acceleratedNetworking: ((topologySettings.vmClientNodeAcceleratedNetworking == 'Default') ? (contains(vmAcceleratedNetworking, topologySettings.vmSizeClientNodes) ? 'Yes' : 'No') : topologySettings.vmClientNodeAcceleratedNetworking)
      nsg: (standardInternalOrExternalLoadBalancer ? vmNsgName_var : '')
      standardInternalLoadBalancer: standardInternalLoadBalancer
    }
    elasticTags: elasticTags
  }
  dependsOn: [
    vmNsgName
  ]
}

module data_nodes '?' /*TODO: replace with correct path to [variables('dataTemplateUrl')]*/ = {
  name: 'data-nodes'
  params: {
    '_artifactsLocation': artifactsLocation
    '_artifactsLocationSasToken': artifactsLocationSasToken
    vm: {
      shared: commonVmSettings
      namespace: '${commonVmSettings.namespacePrefix}data-'
      installScript: osSettings.extensionSettings.data
      size: topologySettings.vmSizeDataNodes
      storageAccountType: topologySettings.vmDataNodeStorageAccountType
      count: topologySettings.vmDataNodeCount
      backendPools: topologySettings.dataLoadBalancerBackEndPools
      imageReference: osSettings.imageReference
      platformFaultDomainCount: platformFaultDomainCount
      acceleratedNetworking: ((topologySettings.vmDataNodeAcceleratedNetworking == 'Default') ? (contains(vmAcceleratedNetworking, topologySettings.vmSizeDataNodes) ? 'Yes' : 'No') : topologySettings.vmDataNodeAcceleratedNetworking)
      nsg: ((standardInternalOrExternalLoadBalancer && (topologySettings.vmClientNodeCount == 0)) ? vmNsgName_var : '')
      standardInternalLoadBalancer: standardInternalLoadBalancer
    }
    storageSettings: topologySettings.dataNodeStorageSettings
    elasticTags: elasticTags
  }
  dependsOn: [
    vmNsgName
  ]
}

module jumpbox '?' /*TODO: replace with correct path to [variables('jumpboxTemplateUrl')]*/ = {
  name: 'jumpbox'
  params: {
    credentials: commonVmSettings.credentials
    location: commonVmSettings.location
    namespace: '${commonVmSettings.namespacePrefix}jumpbox'
    networkSettings: networkSettings
    osSettings: osSettings
    elasticTags: elasticTags
  }
  dependsOn: []
}

module kibana '?' /*TODO: replace with correct path to [variables('kibanaTemplateUrl')]*/ = {
  name: 'kibana'
  params: {
    credentials: commonVmSettings.credentials
    location: commonVmSettings.location
    namespace: '${commonVmSettings.namespacePrefix}kibana'
    networkSettings: networkSettings
    osSettings: osSettings
    vmSize: topologySettings.vmSizeKibana
    acceleratedNetworking: ((topologySettings.vmKibanaAcceleratedNetworking == 'Default') ? (contains(vmAcceleratedNetworking, topologySettings.vmSizeKibana) ? 'Yes' : 'No') : topologySettings.vmKibanaAcceleratedNetworking)
    elasticTags: elasticTags
  }
  dependsOn: []
}

module logstash '?' /*TODO: replace with correct path to [uri(parameters('_artifactsLocation'), concat('machines/logstash-resources.json', parameters('_artifactsLocationSasToken')))]*/ = if (topologySettings.logstash == 'Yes') {
  name: 'logstash'
  params: {
    '_artifactsLocation': artifactsLocation
    '_artifactsLocationSasToken': artifactsLocationSasToken
    vm: {
      shared: commonVmSettings
      namespace: '${commonVmSettings.namespacePrefix}logstash-'
      installScript: osSettings.extensionSettings.logstash
      size: topologySettings.vmSizeLogstash
      storageAccountType: 'Standard_LRS'
      count: topologySettings.vmLogstashCount
      backendPools: []
      imageReference: osSettings.imageReference
      platformFaultDomainCount: platformFaultDomainCount
      acceleratedNetworking: ((topologySettings.vmLogstashAcceleratedNetworking == 'Default') ? (contains(vmAcceleratedNetworking, topologySettings.vmSizeLogstash) ? 'Yes' : 'No') : topologySettings.vmLogstashAcceleratedNetworking)
      nsg: ''
      standardInternalLoadBalancer: false
    }
    elasticTags: elasticTags
  }
  dependsOn: []
}

output jumpboxssh string = reference('jumpbox').outputs.ssh.value