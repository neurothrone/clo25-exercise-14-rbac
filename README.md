# Secrets.Api

A small Web API that reads a secret from Azure Key Vault, with RBAC instead of access policies.

| Method | Path            | What it does                                                     |
|--------|-----------------|------------------------------------------------------------------|
| `GET`  | `/`             | Says the app is running                                          |
| `GET`  | `/secret-check` | Whether the secret arrived, and how long it is - never the value |

It belongs to **Exercise 14**. **The app is finished.** The exercise is about the infrastructure: a Key Vault that
uses RBAC, a user-assigned managed identity, and role assignments written in Bicep.

## What's in here

| Path                    | What it is                                                                      |
|-------------------------|---------------------------------------------------------------------------------|
| `src/Secrets.Api/`      | The app: one endpoint that reports on the secret without returning it           |
| `infra/main.bicep`      | Identity, Key Vault, secret, two role assignments, App Service plan and web app |
| `infra/main.bicepparam` | The names - replace `name` with your own. The secret is **not** in here         |
| `requests.http`         | Ready-made calls against the app, in the cloud and locally                      |

## Why it doesn't do much locally

The app reads `MY_SECRET` from its environment, and App Service fills that in from Key Vault. Locally there is no
Key Vault reference to resolve, so `/secret-check` answers `"present": false`. Run it in Azure, as the exercise
describes.

## Tear it down when you're done

Everything lives in its own resource group, `rg-clo25-rbac-name`, so tearing it down can't take anything else with it:

```bash
az group delete \
  --name rg-clo25-rbac-name \
  --yes \
  --no-wait
```
