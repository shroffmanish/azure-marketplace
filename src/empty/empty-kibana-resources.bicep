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
param vmSize string = 'Standard_A2_v2'

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