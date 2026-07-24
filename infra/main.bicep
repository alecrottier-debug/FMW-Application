// Fox Mill Woods — azd entry point (subscription scope).
// Provision + deploy:  azd up
//   Before first run, set the SQL admin password (kept out of source control):
//     azd env set SQL_ADMIN_PASSWORD '<strong-password>'
targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the azd environment — used to name the resource group and derive a unique resource token.')
param environmentName string

@minLength(1)
@description('Primary location for all resources.')
param location string

@description('SQL administrator login.')
param sqlAdminLogin string = 'fmwadmin'

@secure()
@description('SQL administrator password. Set with: azd env set SQL_ADMIN_PASSWORD <value>')
param sqlAdminPassword string

@description('Object id of the running user/service principal, to grant local data-plane access (Key Vault / Storage). azd sets AZURE_PRINCIPAL_ID automatically.')
param principalId string = ''

var tags = { 'azd-env-name': environmentName }

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

module resources 'resources.bicep' = {
  name: 'fmw-resources'
  scope: rg
  params: {
    location: location
    tags: tags
    resourceToken: toLower(uniqueString(subscription().id, environmentName, location))
    sqlAdminLogin: sqlAdminLogin
    sqlAdminPassword: sqlAdminPassword
    principalId: principalId
  }
}

// Consumed by azd (env vars) and the iOS app / API configuration.
output AZURE_LOCATION string = location
output RESOURCE_GROUP string = rg.name
output SERVICE_API_NAME string = resources.outputs.apiName
output SERVICE_API_URI string = resources.outputs.apiUri
output AZURE_KEY_VAULT_URI string = resources.outputs.keyVaultUri
output SQL_SERVER_FQDN string = resources.outputs.sqlServerFqdn
output RECEIPTS_CONTAINER string = resources.outputs.receiptsContainer
