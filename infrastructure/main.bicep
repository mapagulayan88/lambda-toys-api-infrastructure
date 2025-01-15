param location string
param prefix string
param vnetSettings object = {
  addressPrefixes: [
    '10.0.0.0/19'
  ]
  subnets: [
    { 
      name: 'subnet1'
      addressPrefix: '10.0.0.0/21'
    }
    { 
      name: 'acaAppSubnet'
      addressPrefix: '10.0.8.0/21'
    }
    { 
      name: 'acaControlPlaneSubnet'
      addressPrefix: '10.0.16.0/21'
    }
  ]
}

param containerVersion string
param existingKeyVaultId string
param secretName string

var secretKeyVaultName = split(existingKeyVaultId, '/')[8]
var secretKeyVaultResourceGroup = split(existingKeyVaultId, '/')[4]
var secretKeyVautlSubscriptionId = split(existingKeyVaultId, '/')[2]

resource kv 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
 name: secretKeyVaultName
 scope: resourceGroup(secretKeyVautlSubscriptionId, secretKeyVaultResourceGroup)
}

 module core 'core.bicep' = {
  name: 'core'
  params: {
    location: location
    prefix: prefix
    vnetSettings: vnetSettings
  }
}


module aca 'aca.bicep' = {
  name: 'aca'
  dependsOn: [
    core
  ]
  params: {
    location: location
    prefix: prefix
    vNetId: core.outputs.vNetId
    containerRegistryName: core.outputs.containerRegistryName
    containerRegistryUsername: core.outputs.containerRegistryUsername
    containerVersion: containerVersion
    cosmosAccountName: core.outputs.cosmosAccountName
    cosmosContainerName: core.outputs.cosmosStateContainerName
    cosmosDbName: core.outputs.cosmosDbName
    containerRegistryPassword: kv.getSecret(secretKeyVaultName)
  }
}
