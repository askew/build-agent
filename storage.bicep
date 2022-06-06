param stgaccountname string
param subnetid string
param privatednszoneid string
param buildAgentServicePrincipalObjectId string = ''
@description('The location for the resources')
param location string = resourceGroup().location

var storageBlobDataContributorId = resourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')

resource tfstatestg 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: stgaccountname
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    supportsHttpsTrafficOnly: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
  }

  resource blob 'blobServices' = {
    name: 'default'
    resource tfstatecontainer 'containers' = {
      name: 'tfstate'
    }
    resource buildcontainer 'containers' = {
      name: 'build'
    }
  }
}

resource blobContributor 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = if (length(buildAgentServicePrincipalObjectId) > 0) {
  scope: tfstatestg
  name: guid(storageBlobDataContributorId, buildAgentServicePrincipalObjectId, tfstatestg.id)
  properties: {
    roleDefinitionId: storageBlobDataContributorId
    principalId: buildAgentServicePrincipalObjectId
    principalType: 'ServicePrincipal'
  }
}

resource stgprivateendpoint 'Microsoft.Network/privateEndpoints@2021-08-01' = {
  name: 'pe-${stgaccountname}'
  location: location
  properties: {
    subnet: {
      id: subnetid
    }
    privateLinkServiceConnections: [
      {
        name: 'KeyVault'
        properties: {
          privateLinkServiceId: tfstatestg.id
          groupIds: [
            'Blob'
          ]
        }
      }
    ]
  }
  resource kvzonegrp 'privateDnsZoneGroups' = {
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'config'
          properties: {
            privateDnsZoneId: privatednszoneid
          }
        }
      ]
    }
  }
}
