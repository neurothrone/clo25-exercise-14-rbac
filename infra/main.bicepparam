using './main.bicep'

// Your name, written once. Every name below is built from it.
var yourName = 'name'

param planName = 'asp-clo25-rbac-${yourName}'
param appName = 'app-clo25-rbac-${yourName}'
param identityName = 'id-clo25-rbac-${yourName}'
param vaultName = 'kv-clo25-rbac-${yourName}'
param owner = yourName

// The secret is never written here. It is read from the environment at deploy
// time, and the deploy stops with BCP427 if it has not been set.
param secretValue = readEnvironmentVariable('SECRET_VALUE')
