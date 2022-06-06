@description('Admin username for the Virtual Machine.')
param adminUsername string = 'vstsbuild'

@secure()
@description('The public key of the SSH key used to sign in to the VM as the admin user.')
param sshPublicKey string

@description('The Azure DevOps Organisation URL to associate this build agent to.')
param azureDevOpsUrl string

@secure()
@description('The Personal Access Token (PAT) needed to register a build agent with Azure DevOps')
param personalAccessToken string

@description('Address space for the virtual network. This should be in CIDR format with a /24 range.')
param addressSpace string = '10.0.0.0/24'

@description('IP address from which to allow SSH access to the VM subnet (optional).')
param managementIP string = ''

@description('The location for the resources')
param location string = resourceGroup().location

var prefix = take(uniqueString(resourceGroup().id), 4)
var vnetname = '${prefix}-build-vnet'
var kvname = '${prefix}-build-kv'
var vmname = 'buildvm1'
var acrname = '${prefix}devacr'
var msiname = '${prefix}-buildagent-msi'


resource agentmsi 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: msiname
  location: location
}

module network 'network.bicep' = {
  name: 'network'
  params: {
    vnetName: vnetname
    addressSpace: addressSpace
    managementIP: managementIP
    location: location
  }
}

module keyvault 'keyvault.bicep' = {
  name: 'keyvault'
  params: {
    keyvaultname: kvname
    pattoken: personalAccessToken
    privatednszoneid: network.outputs.kvdnszoneid
    subnetid: network.outputs.pesubnetid
    servicePrincipalObjectId: agentmsi.properties.principalId
    location: location
  }
}

module storage 'storage.bicep' = {
  name: 'tfstatestorage'
  params: {
    stgaccountname: '${prefix}tfstate'
    privatednszoneid: network.outputs.blobdnszoneid
    subnetid: network.outputs.pesubnetid
    buildAgentServicePrincipalObjectId: agentmsi.properties.principalId
    location: location
  }
}

module containerRegistry 'container-registry.bicep' = {
  name: 'devContainerRegistry'
  params: {
    name: acrname
    location: location
    subnetid: network.outputs.pesubnetid
    privatednszoneid: network.outputs.crdnszoneid
  }
}

module buildvm 'buildvm.bicep' = {
  dependsOn: [
    keyvault
  ]
  name: 'buildvm'
  params: {
    adminUsername: adminUsername
    agentPool: 'Default'
    devOpsServer: azureDevOpsUrl
    keyVaultName: kvname
    subNetName: network.outputs.vmsubnet
    vNetName: vnetname
    vNetResourceGroup: resourceGroup().name
    vmName: vmname
    sshPublicKey: sshPublicKey
    lbBePoolId: network.outputs.lbBePoolId
    msiResourceGroup: resourceGroup().name
    msiName: msiname
    location: location
  }
}
