// Fox Mill Woods backend resources (resource-group scope). Deployed by azd via main.bicep.
//
//   Storage            — receipt images (private) + Function deployment package container
//   Log Analytics + AI — telemetry (workspace-based Application Insights)
//   Key Vault (RBAC)   — Stripe + IdP secrets (set outside source control)
//   Azure SQL          — serverless (auto-pause) app data (see spec §5 schema)
//   Function App (FC1) — the TypeScript API + Stripe webhook, Flex Consumption plan
//
// The Function App uses a system-assigned identity for storage (no secrets in config).

@description('Location for all resources.')
param location string

@description('Tags applied to every resource.')
param tags object

@description('Deterministic token for globally-unique resource names.')
param resourceToken string

@description('SQL administrator login.')
param sqlAdminLogin string

@secure()
@description('SQL administrator password.')
param sqlAdminPassword string

@description('Optional principal to grant data-plane access for local development.')
param principalId string = ''

@description('Google OAuth iOS client id (…apps.googleusercontent.com).')
param googleClientId string = ''

@description('Braintree environment: sandbox | production.')
param braintreeEnvironment string = 'sandbox'

var abbrs = {
  storage: 'st'
  keyVault: 'kv'
  functionApp: 'func'
  plan: 'plan'
  sql: 'sql'
  ai: 'appi'
  logs: 'log'
}
var deploymentContainerName = 'app-package'
var receiptsContainerName = 'receipts'

// Built-in role definition ids (data-plane, least privilege).
var roles = {
  storageBlobDataOwner: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
  storageQueueDataContributor: '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
  storageTableDataContributor: '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
  keyVaultSecretsUser: '4633458b-17de-408a-b874-0445c86b69e6'
}

// ---------- Storage (receipts + Function deployment package) ----------
resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: '${abbrs.storage}${resourceToken}'
  location: location
  tags: tags
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false // receipts are private; serve via API/SAS
    allowSharedKeyAccess: false // identity-based access only (no account keys)
    publicNetworkAccess: 'Enabled'
  }
}
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storage
  name: 'default'
}
resource receipts 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: receiptsContainerName
  properties: { publicAccess: 'None' }
}
resource deployContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: deploymentContainerName
  properties: { publicAccess: 'None' }
}

// ---------- Monitoring (workspace-based Application Insights) ----------
resource logs 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${abbrs.logs}-${resourceToken}'
  location: location
  tags: tags
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${abbrs.ai}-${resourceToken}'
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logs.id
  }
}

// ---------- Key Vault (secrets, RBAC) ----------
resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: '${abbrs.keyVault}-${resourceToken}'
  location: location
  tags: tags
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    softDeleteRetentionInDays: 7
    enableSoftDelete: true
  }
  // Store STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET, APPLE_IDP_SECRET,
  // GOOGLE_IDP_SECRET here (set outside source control).
}

// ---------- Azure SQL (serverless, auto-pause) ----------
resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: '${abbrs.sql}-${resourceToken}'
  location: location
  tags: tags
  properties: {
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}
resource sqlDb 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  parent: sqlServer
  name: 'foxmillwoods'
  location: location
  tags: tags
  sku: { name: 'GP_S_Gen5_1', tier: 'GeneralPurpose' } // serverless
  properties: {
    autoPauseDelay: 60
    minCapacity: json('0.5')
    zoneRedundant: false
  }
}
// Let Azure services (the Function App) reach SQL. Tighten to VNet later.
resource sqlAllowAzure 'Microsoft.Sql/servers/firewallRules@2023-08-01-preview' = {
  parent: sqlServer
  name: 'AllowAllAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// ---------- Function App (Flex Consumption) ----------
resource plan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: '${abbrs.plan}-${resourceToken}'
  location: location
  tags: tags
  kind: 'functionapp'
  sku: { name: 'FC1', tier: 'FlexConsumption' }
  properties: { reserved: true }
}

resource api 'Microsoft.Web/sites@2024-04-01' = {
  name: '${abbrs.functionApp}-${resourceToken}'
  location: location
  tags: union(tags, { 'azd-service-name': 'api' }) // azd maps the "api" service here
  kind: 'functionapp,linux'
  identity: { type: 'SystemAssigned' }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${storage.properties.primaryEndpoints.blob}${deploymentContainerName}'
          authentication: { type: 'SystemAssignedIdentity' }
        }
      }
      scaleAndConcurrency: {
        maximumInstanceCount: 100
        instanceMemoryMB: 2048
      }
      runtime: { name: 'node', version: '20' }
    }
    siteConfig: {
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      appSettings: [
        { name: 'AzureWebJobsStorage__accountName', value: storage.name }
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsights.properties.ConnectionString }
        { name: 'KEY_VAULT_URI', value: kv.properties.vaultUri }
        { name: 'SQL_SERVER_FQDN', value: sqlServer.properties.fullyQualifiedDomainName }
        { name: 'SQL_DATABASE', value: sqlDb.name }
        // Native Apple + Google sign-in; APP_JWT_SECRET signs our own session tokens.
        { name: 'APP_JWT_SECRET', value: '@Microsoft.KeyVault(VaultName=${kv.name};SecretName=app-jwt-secret)' }
        { name: 'APPLE_BUNDLE_ID', value: 'com.foxmillwoods.app' }
        { name: 'GOOGLE_CLIENT_ID', value: googleClientId }
        // Braintree (events/rentals) — secrets from Key Vault; environment is plain:
        { name: 'BRAINTREE_ENVIRONMENT', value: braintreeEnvironment }
        { name: 'BRAINTREE_MERCHANT_ID', value: '@Microsoft.KeyVault(VaultName=${kv.name};SecretName=braintree-merchant-id)' }
        { name: 'BRAINTREE_PUBLIC_KEY', value: '@Microsoft.KeyVault(VaultName=${kv.name};SecretName=braintree-public-key)' }
        { name: 'BRAINTREE_PRIVATE_KEY', value: '@Microsoft.KeyVault(VaultName=${kv.name};SecretName=braintree-private-key)' }
        // Stripe (dues, low-fee ACH) — secrets from Key Vault:
        { name: 'STRIPE_SECRET_KEY', value: '@Microsoft.KeyVault(VaultName=${kv.name};SecretName=stripe-secret-key)' }
        { name: 'STRIPE_WEBHOOK_SECRET', value: '@Microsoft.KeyVault(VaultName=${kv.name};SecretName=stripe-webhook-secret)' }
      ]
    }
  }
  dependsOn: [deployContainer]
}

// ---------- RBAC: Function identity → storage (blob/queue/table) + Key Vault ----------
resource blobOwner 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storage.id, api.id, roles.storageBlobDataOwner)
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.storageBlobDataOwner)
    principalId: api.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
resource queueContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storage.id, api.id, roles.storageQueueDataContributor)
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.storageQueueDataContributor)
    principalId: api.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
resource tableContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storage.id, api.id, roles.storageTableDataContributor)
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.storageTableDataContributor)
    principalId: api.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
resource kvSecretsUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(kv.id, api.id, roles.keyVaultSecretsUser)
  scope: kv
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.keyVaultSecretsUser)
    principalId: api.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Optional: grant the running developer/CI principal the same data-plane access locally.
resource devBlobOwner 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(principalId)) {
  name: guid(storage.id, principalId, roles.storageBlobDataOwner)
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.storageBlobDataOwner)
    principalId: principalId
    principalType: 'User'
  }
}
resource devKvSecretsUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(principalId)) {
  name: guid(kv.id, principalId, roles.keyVaultSecretsUser)
  scope: kv
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.keyVaultSecretsUser)
    principalId: principalId
    principalType: 'User'
  }
}

output apiName string = api.name
output apiUri string = 'https://${api.properties.defaultHostName}'
output keyVaultUri string = kv.properties.vaultUri
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output receiptsContainer string = receipts.name
output storageAccountName string = storage.name
