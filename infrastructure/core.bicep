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

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2019-11-01' = {
  name: '${prefix}-default-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'allowhttpsinbound'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          description: 'Allow HTTPS inbound traffic'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: '${prefix}-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: vnetSettings.addressPrefixes
    }
    subnets: [ for subnet in vnetSettings.subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.addressPrefix
        networkSecurityGroup: {
          id: networkSecurityGroup.id
        }
        privateEndpointNetworkPolicies: 'Disabled'
      }
    }

    ]
  }
}

resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2021-03-15' = {
  name: '${prefix}-cosmos-account'
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
      }
    ]
    databaseAccountOfferType: 'Standard'
    enableAutomaticFailover: false
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
  }
}

resource sqlDb 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2021-06-15' = {
  parent: cosmosDbAccount
  name: '${prefix}-sqldb'
  properties: {
    resource: {
      id: '${prefix}-sqldb'
    }
    options: {
    }
  }
}


resource sqlContainerName 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2021-06-15' = {
  parent: sqlDb 
  name: '${prefix}-orders'
  properties: {
    resource: {
      id: '${prefix}-orders'
      partitionKey: {
        paths: [
          '/id'
        ]
      }
    }
    options: {}
  }
}

resource cosmosPrivateDNS 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.documents.azure.com'
  location: 'global'
}

resource cosmosPrivateDnsNetworkLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: cosmosPrivateDNS
  name: '${prefix}-cosmos-dns-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetwork.id
    }
  }
}

resource cosmosPrivateEndpoint 'Microsoft.Network/privateEndpoints@2020-03-01' = {
  name: '${prefix}-cosmos-pe'
  location: location
  properties: {
    subnet: {
      id: virtualNetwork.properties.subnets[0].id
    }
    privateLinkServiceConnections: [
      {
        name: '${prefix}-cosmos-pe'
        properties: {
          privateLinkServiceId: cosmosDbAccount.id
          groupIds: [
            'SQL'
          ]
        }
      }
    ]
  }
}

resource cosmosPrivateEndpointDnsLink 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-06-01' = {
  parent: cosmosPrivateEndpoint
  name: '${prefix}-cosmos-pe-dns'

  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink.documents.azure.com'
        properties: {
          privateDnsZoneId: cosmosPrivateDNS.id
        }
      }
    ]
  }
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-06-01-preview' = {
  name: '${replace(prefix, '-', '')}markpacr'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2021-10-01' = {
  name: '${prefix}-mark-kv2'
  location: location
  properties: {
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: true
    enableRbacAuthorization: true
    tenantId: tenant().tenantId
    sku: {
      name: 'standard'
      family: 'A'
    }
  }
}

resource keyVaultSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: 'arcAdminPassword'
  parent: keyVault
  properties: {
    value: containerRegistry.listCredentials().passwords[0].value
  }
}

resource stateContainerName 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2023-11-15' = {
  parent: sqlDb 
  name: '${prefix}-state'
  properties: {
    resource: {
      id: '${prefix}-state'
      partitionKey: {
        paths: [
          '/partitionKey'
        ]
      }
    }
    
  }
}

output vNetId string = virtualNetwork.id
output vNetName string = virtualNetwork.name
output SecretKeyVaultName string = keyVault.name
output CosmosAccountName string = cosmosDbAccount.name
output ComosDbName string = sqlDb.name
output CosmosStateContainerName string = stateContainerName.name
output CosmosSqlContainerName string = sqlContainerName.name
