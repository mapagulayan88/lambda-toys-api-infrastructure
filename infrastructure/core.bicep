param location string = 'newzealandnorth'
param prefix string
param vnetSettings object = {
  addressPrefixes: [
    '10.0.0.0/20'
  ]
  subnets: [
    {
      name: 'subnet1'
      addressPrefix: '10.0.0.0/22'
    }
  ]
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2019-11-01' = {
  name: '${prefix}-default-nsg'
  location: location
  properties: {
    securityRules: [
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

resource cosmosPrivateEndpoint 'Microsoft.Network/privateEndpoints@2019-04-01' = {
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

