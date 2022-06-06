@description('The name of the keyvault')
param keyvaultname string

@secure()
@description('The PAT token needed to register a build agent with Azure DevOps')
param pattoken string

param subnetid string

param privatednszoneid string

param servicePrincipalObjectId string

param location string = resourceGroup().location

resource keyvault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: keyvaultname
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'premium'
    }
    tenantId: subscription().tenantId
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    networkAcls: {
      bypass: 'None'
      defaultAction: 'Deny'
      ipRules: []
    }
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: servicePrincipalObjectId
        permissions: {
          secrets: [
            'get'
          ]
        }
      }
    ]
  }

  resource pat 'secrets' = {
    name: 'DevOpsPAT'
    properties: {
      value: pattoken
    }
  }
}

resource kvprivateendpoint 'Microsoft.Network/privateEndpoints@2021-02-01' = {
  name: 'pe-${keyvaultname}'
  location: location
  properties: {
    subnet: {
      id: subnetid
    }
    privateLinkServiceConnections: [
      {
        name: 'KeyVault'
        properties: {
          privateLinkServiceId: keyvault.id
          groupIds: [
            'vault'
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
