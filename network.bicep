param vnetName string
param addressSpace string
@description('The location for the resources')
param location string = resourceGroup().location

@description('IP address from which to allow SSH access to the VM subnet.')
param managementIP string = ''

var addressSpaceList = split(addressSpace, ',')
var cidrParts = split(addressSpaceList[0], '/')
var addressSpaceParts = split(cidrParts[0], '.')
var addressPrefix24 = '${addressSpaceParts[0]}.${addressSpaceParts[1]}.${addressSpaceParts[2]}'

var vmsubnetName = 'buildagents'

var sshRule = {
  name: 'Allow-SSH'
  properties: {
    priority: 100
    description: 'Allow SSH from fixed location'
    access: 'Allow'
    direction: 'Inbound'
    sourceAddressPrefix: managementIP
    sourcePortRange: '*'
    destinationAddressPrefix: '*'
    destinationPortRange: '22'
    protocol: 'Tcp'
  }
}

var sshNatPool = {
  name: 'ssh'
  properties: {
    backendPort: 22
    frontendPortRangeStart: 22001
    frontendPortRangeEnd: 22099
    frontendIPConfiguration: {
      id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', 'lb-vms', 'public-ip')
    }
    backendAddressPool: {
      id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'lb-vms', 'buildvms')
    }
    protocol: 'Tcp'
  }
}


// See https://docs.microsoft.com/azure/private-link/private-endpoint-dns#azure-services-dns-zone-configuration
var privatednszones = [
  'privatelink.blob.${environment().suffixes.storage}'
  'privatelink.vaultcore.azure.net'
  'privatelink.azurecr.io'
]

resource defaultnsg 'Microsoft.Network/networkSecurityGroups@2021-08-01' = {
  name: 'default-nsg'
  location: location
  properties: {
    securityRules: []
  }
}

resource agentnsg 'Microsoft.Network/networkSecurityGroups@2021-08-01' = {
  name: 'agent-nsg'
  location: location
  properties: {
    securityRules: empty(managementIP) ? [] : [
      sshRule
    ]
  }
}

resource bastionnsg 'Microsoft.Network/networkSecurityGroups@2021-08-01' = {
  name: 'bastion-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-SecureWeb'
        properties: {
          priority: 100
          description: 'Allow HTTPS traffic from the Internet to the Azure Bastion'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
          protocol: 'Tcp'
        }
      }
      {
        name: 'Allow-ControlPlane'
        properties: {
          priority: 110
          description: 'Allow Azure control-plane access to Azure Bastion'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'GatewayManager'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
          protocol: 'Tcp'
        }
      }
      {
        name: 'Allow-DataPlane-In'
        properties: {
          priority: 120
          description: 'Allow Azure control-plane access to Azure Bastion'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          protocol: '*'
        }
      }
      {
        name: 'Allow-LoadBalancerProbe'
        properties: {
          priority: 130
          description: 'Allow HTTPS traffic from the LB to the Azure Bastion'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'AzureLoadBalancer'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
          protocol: 'Tcp'
        }
      }
      {
        name: 'Allow-SSHRDPOut'
        properties: {
          priority: 100
          description: 'Allow Basition access to VMs'
          access: 'Allow'
          direction: 'Outbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '22'
            '3380'
          ]
          protocol: '*'
        }
      }
      {
        name: 'Allow-DataPlane-Out'
        properties: {
          priority: 110
          description: 'Allow Azure control-plane access from Azure Bastion'
          access: 'Allow'
          direction: 'Outbound'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          protocol: '*'
        }
      }
      {
        name: 'Allow-Azure-Out'
        properties: {
          priority: 120
          description: 'Allow Bastion access to Azure public endpoints'
          access: 'Allow'
          direction: 'Outbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'AzureCloud'
          destinationPortRange: '443'
          protocol: 'Tcp'
        }
      }
      {
        name: 'Allow-Session-Out'
        properties: {
          priority: 130
          description: 'Allow Bastion access to certificate validation'
          access: 'Allow'
          direction: 'Outbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'Internet'
          destinationPortRange: '80'
          protocol: '*'
        }
      }
    ]
  }
}

resource network 'Microsoft.Network/virtualNetworks@2021-08-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: addressSpaceList
    }
    subnets: [
      {
        name: vmsubnetName
        properties: {
          addressPrefix: '${addressPrefix24}.0/26'
          networkSecurityGroup: {
            id: agentnsg.id
          }
        }
      }
      {
        name: 'bastion'
        properties: {
          addressPrefix: '${addressPrefix24}.64/26'
          networkSecurityGroup: {
            id: bastionnsg.id
          }
        }
      }
      {
        name: 'PrivateEndpoints'
        properties: {
          addressPrefix: '${addressPrefix24}.192/26'
          privateEndpointNetworkPolicies: 'Disabled'
          networkSecurityGroup: {
            id: defaultnsg.id
          }
        }
      }
    ]
  }
}

resource privatedns 'Microsoft.Network/privateDnsZones@2020-06-01' = [for zone in privatednszones :{
  name: zone
  location: 'global'
  properties: {}
}]

resource privatednslinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (zone, i) in privatednszones :{
  dependsOn: [
    privatedns[i]
  ]
  name: '${zone}/${uniqueString(network.id)}'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: network.id
    }
    registrationEnabled: false
  }
}]

resource lbpip 'Microsoft.Network/publicIPAddresses@2021-08-01' = {
  name: 'pip-loadbalancer'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource lb 'Microsoft.Network/loadBalancers@2021-08-01' = {
  name: 'lb-vms'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'public-ip'
        properties: {
          publicIPAddress: {
            id: lbpip.id
          }

        }
      }
    ]
    backendAddressPools: [
      {
        name: 'buildvms'
      }
    ]
    outboundRules: [
      {
        name: 'defaultout'
        properties: {
          frontendIPConfigurations: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', 'lb-vms', 'public-ip')
            }
          ]
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'lb-vms', 'buildvms')
          }
          protocol: 'All'
        }
      }
    ]
    inboundNatRules: empty(managementIP) ? [] : [
      sshNatPool
    ]
  }
}

output vmsubnet string = vmsubnetName
output pesubnetid string = network.properties.subnets[2].id
output lbBePoolId string = lb.properties.backendAddressPools[0].id
output blobdnszoneid string = privatedns[0].id
output kvdnszoneid string = privatedns[1].id
output crdnszoneid string = privatedns[2].id
