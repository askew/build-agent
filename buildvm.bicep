@description('The machine name to use for the VM.')
param vmName string
@description('The name of the virtual network.')
param vNetName string
@description('The name of the subnet to deploy the server into.')
param subNetName string
@description('The virtual network resource group.')
param vNetResourceGroup string
@description('The VM size to deploy.')
param instanceSize string = 'Standard_D2ds_v4'
@description('Admin username for the Virtual Machine.')
param adminUsername string = 'vstsbuild'
@description('The SSH public key for the admin account.')
param sshPublicKey string
@description('The url of the Azure DevOps tenant, e.g. https://dev.azure.com/mydevops')
param devOpsServer string
@description('The name of the KeyVault that has the Azure DevOps PAT stored as a secret.')
param keyVaultName string
@description('The name of the secret in KeyVault containing the Azure DevOps PAT.')
param patTokenSecretName string = 'DevOpsPAT'
@description('The name of the Agent Pool to register the agent in.')
param agentPool string = 'Default'
@description('The size of the data disk provisioned for storing Docker images')
@allowed([
  64
  128
  256
  512
  1024
])
param dataDiskSize int = 256
@description('The resource id of the backend pool on the load balancer.')
param lbBePoolId string
@description('The resource group the user assigned managed identity is in.')
param msiResourceGroup string
@description('The name of the user assigned managed identity.')
param msiName string
@description('The location for the resources')
param location string = resourceGroup().location

var prefix = take(uniqueString(resourceGroup().id), 4)
var prefixedVMName = '${prefix}-${toLower(vmName)}'
var nicName = '${prefixedVMName}-nic'
var dataDiskName = '${prefixedVMName}-data'
var diagnosticsStorageAccountName = '${prefix}diagnostics${take(uniqueString(resourceId('Microsoft.Compute/virtualMachines', prefixedVMName)),4)}'
var cloudInit = loadFileAsBase64('out/cloud-config.yml')
var customScriptFormat = loadTextContent('custom-script.sh')
var agentName = '${vmName}-Agent'
var customScript = format(customScriptFormat, devOpsServer, keyVaultName, patTokenSecretName, agentName, vnet.id, agentPool)

resource vnet 'Microsoft.Network/virtualNetworks@2021-08-01' existing = {
  name: vNetName
  scope: resourceGroup(vNetResourceGroup)
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2021-08-01' existing = {
  name: '${vNetName}/${subNetName}'
  scope: resourceGroup(vNetResourceGroup)
}

resource agentIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: msiName
  scope: resourceGroup(msiResourceGroup)
}

resource nic 'Microsoft.Network/networkInterfaces@2021-08-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnet.id
          }
          loadBalancerBackendAddressPools: [
            {
              id: lbBePoolId
            }
          ]
        }
      }
    ]
  }
}

resource diagstg 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  location: location
  name: diagnosticsStorageAccountName
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    supportsHttpsTrafficOnly: true
  }
}

resource datadisk 'Microsoft.Compute/disks@2021-12-01' = {
  name: dataDiskName
  location: location
  sku: {
    name: 'Premium_LRS'
  }
  properties: {
    creationData: {
      createOption: 'Empty'
    }
    diskSizeGB: dataDiskSize
  }
}

resource buildvm 'Microsoft.Compute/virtualMachines@2021-11-01' = {
  name: prefixedVMName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${agentIdentity.id}': {}
    }
  }
  properties: {
    hardwareProfile: {
      vmSize: instanceSize
    }
    osProfile: {
      computerName: toUpper('${prefix}${vmName}')
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
        provisionVMAgent: true
      }
      customData: cloudInit
      allowExtensionOperations: true
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-focal'
        sku: '20_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        diffDiskSettings: {
          option: 'Local'
          placement: 'ResourceDisk'
        }
        caching: 'ReadOnly'
        createOption: 'FromImage'
      }
      dataDisks: [
        {
          lun: 0
          createOption: 'Attach'
          caching: 'ReadWrite'
          managedDisk: {
            id: datadisk.id
          }
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            primary: true
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: diagstg.properties.primaryEndpoints.blob
      }
    }
  }

  resource antimalware 'extensions' = {
    name: 'CustomScript'
    location: location
    properties: {
      publisher: 'Microsoft.Azure.Extensions'
      type: 'CustomScript'
      typeHandlerVersion: '2.1'
      autoUpgradeMinorVersion: true
      protectedSettings: {
        script: base64(customScript)
      }
    }
  }
}
