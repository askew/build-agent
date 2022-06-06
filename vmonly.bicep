@description('Admin username for the Virtual Machine.')
param adminUsername string = 'vstsbuild'

@secure()
@description('The public key of the SSH key used to sign in to the VM as the admin user.')
param sshPublicKey string

@description('The Azure DevOps Organisation URL to associate this build agent to.')
param azureDevOpsUrl string

@description('The location for the resources')
param location string = resourceGroup().location

var prefix = take(uniqueString(resourceGroup().id), 4)
var vnetname = '${prefix}-build-vnet'
var kvname = '${prefix}-build-kv'
var vmname = 'buildvm1'
var msiname = '${prefix}-buildagent-msi'

resource lb 'Microsoft.Network/loadBalancers@2021-08-01' existing = {
  name: 'lb-vms'
}

module buildvm 'buildvm.bicep' = {
  name: 'buildvm'
  params: {
    adminUsername: adminUsername
    agentPool: 'Default'
    devOpsServer: azureDevOpsUrl
    keyVaultName: kvname
    subNetName: 'buildagents'
    vNetName: vnetname
    vNetResourceGroup: resourceGroup().name
    vmName: vmname
    sshPublicKey: sshPublicKey
    lbBePoolId: lb.properties.backendAddressPools[0].id
    msiResourceGroup: resourceGroup().name
    msiName: msiname
    location: location
  }
}
