param name string

param subnetid string

param privatednszoneid string

param location string = resourceGroup().location

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-12-01-preview' = {
  name: name
  location: location
  sku: {
    name: 'Premium'
  }
  properties: {
    adminUserEnabled: true
    dataEndpointEnabled: true
    anonymousPullEnabled: false
    networkRuleSet: {
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
    networkRuleBypassOptions: 'None'
    publicNetworkAccess: 'Disabled'
  }
}


resource crprivateendpoint 'Microsoft.Network/privateEndpoints@2021-08-01' = {
  name: 'pe-${name}'
  location: location
  properties: {
    subnet: {
      id: subnetid
    }
    privateLinkServiceConnections: [
      {
        name: 'ContainerRegistry'
        properties: {
          privateLinkServiceId: containerRegistry.id
          groupIds: [
            'registry'
          ]
        }
      }
    ]
  }
  resource crzonegrp 'privateDnsZoneGroups' = {
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
