// Infrastructure for Secrets.Api: an App Service that reads a secret from a Key Vault,
// with RBAC instead of access policies. Deployed into an existing resource group with
// az deployment group create.
//
// Four things to look for:
//   1. The Key Vault has enableRbacAuthorization: true, so access policies are ignored.
//   2. The app's identity is a resource of its own (user-assigned), not part of the app.
//   3. Access is given with role assignments, one for the identity and one for you.
//   4. deployer() gives your own objectId, so it never has to be looked up or pasted in.

@description('Region. Defaults to the location of the resource group.')
param location string = resourceGroup().location

@description('Name of the App Service plan.')
param planName string

@description('Name of the web app. Part of the URL, must be globally unique.')
param appName string

@description('Name of the user-assigned managed identity.')
param identityName string

@description('Name of the Key Vault. 3-24 chars, must start with a letter, globally unique.')
@minLength(3)
@maxLength(24)
param vaultName string

@description('Name of the secret in the vault.')
param secretName string = 'demo-secret'

@secure()
@description('Secret value. Read from the environment at deploy time, never committed.')
param secretValue string

@description('Owner tag.')
param owner string

@description('Plan size. B1 = Basic. P0v3 = Premium v3, for when West Europe has no B1 capacity left.')
@allowed([
  'B1'
  'P0v3'
])
param skuName string = 'B1'

var tags = {
  owner: owner
  course: 'clo25'
  environment: 'dev'
  'managed-by': 'bicep'
}

// Built-in role definitions. The ids are the same in every tenant.
// Look them up with: az role definition list --name "Key Vault Secrets User" --query "[].name"
var secretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6' // read secrets
var secretsOfficerRoleId = 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7' // read, write and delete secrets

// ======== Identity ========

// A resource of its own. It is not part of the app, so it can exist before the app
// does, and more than one app could use it.
resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: identityName
  location: location
  tags: tags
}

// ======== Key Vault ========

resource vault 'Microsoft.KeyVault/vaults@2026-02-01' = {
  name: vaultName
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true // RBAC decides who gets in. No accessPolicies below.
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
  }
}

resource secret 'Microsoft.KeyVault/vaults/secrets@2026-02-01' = {
  parent: vault
  name: secretName
  properties: {
    value: secretValue
  }
}

// ======== Role assignments ========

// The identity may read secrets in this vault, and nothing else.
resource identityCanRead 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vault.id, identity.id, secretsUserRoleId)
  scope: vault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', secretsUserRoleId)
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal' // a managed identity is a service principal
  }
}

// You may read, write and delete secrets in this vault. deployer() is whoever runs
// the deployment, so there is no objectId to look up and paste into a file.
resource deployerCanManage 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vault.id, deployer().objectId, secretsOfficerRoleId)
  scope: vault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', secretsOfficerRoleId)
    principalId: deployer().objectId
  }
}

// ======== App Service ========

resource plan 'Microsoft.Web/serverfarms@2025-03-01' = {
  name: planName
  location: location
  tags: tags
  kind: 'linux'
  sku: {
    name: skuName
  }
  properties: {
    reserved: true
  }
}

resource app 'Microsoft.Web/sites@2025-03-01' = {
  name: appName
  location: location
  tags: tags
  kind: 'app,linux'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity.id}': {}
    }
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    // Which identity App Service uses to resolve Key Vault references. Without this
    // line it tries the system-assigned identity, and this app has none.
    keyVaultReferenceIdentity: identity.id
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|10.0'
      minTlsVersion: '1.3'
      appSettings: [
        {
          name: 'MY_SECRET'
          value: '@Microsoft.KeyVault(SecretUri=${secret.properties.secretUri})'
        }
      ]
    }
  }
  dependsOn: [
    identityCanRead // the role has to exist before the app first resolves the reference
  ]
}

output appHost string = app.properties.defaultHostName
output vaultName string = vault.name
output identityPrincipalId string = identity.properties.principalId
