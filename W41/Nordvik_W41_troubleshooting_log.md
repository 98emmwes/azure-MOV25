# Nordvik W41: deployment troubleshooting log

Azure exam (Uppgift 8), Nordvik Fastigheter AB. Session of 11 October 2026: from a failed `az login` to a working baseline deployment.

Repo: https://github.com/98emmwes/azure-MOV25 (folder W41)

## Summary

The baseline template (`azuredeploy.json`) and the script (`deploy.ps1`) were correct from the start. Every error in this session came from the environment around them: sign-in, PowerShell settings, a file name, and what Azure allows this subscription to create in Sweden Central. Seven problems were solved in order, and the result is 12 resources in `rg-nordvik`, with the website form showing.

| # | Problem | Root cause | Fix in one line |
|---|---------|------------|-----------------|
| 1 | az login: no subscriptions found | Tenant requires MFA | `az login --tenant TENANT_ID` |
| 2 | Running scripts is disabled | PowerShell execution policy | `Set-ExecutionPolicy -Scope Process Bypass` in an administrator window |
| 3 | SSH public key not found | Script expects `id_ed25519.pub` | `-SshKeyPath` to `nordviksshkey.pub` |
| 4 | QuotaExceeded (Basv2) | Quota for that VM family is 0 | Pick a family that has quota |
| 5 | Cannot convert System.Object[] | PowerShell 5.1 pipeline behaviour | Filter with `az --query` instead |
| 6 | SkuNotAvailable (B2s, D2s_v3) | Capacity restrictions in the region | Only use sizes without restrictions |
| 7 | Which size works? | Needs both quota and no restriction | `Standard_D2ls_v6` + NVMe |

## Starting point

From the earlier sessions the following existed on the school computer:

- **W41/infra/azuredeploy.json**: ARM template with storage account, private endpoint, private DNS zone, two NSGs, VNet, managed identity, public IP, NIC and a web VM.
- **deploy.ps1**: looks up your public IP and SSH public key, then runs group create, validate, what-if and (after confirmation) create.
- **azuredeploy.parameters.json**: committed parameter file with the static values. An optional `azuredeploy.parameters.local.json` (ignored by Git) is used first if it exists.
- A **public GitHub repo**, since the VM clones it on first boot to get the web page.

## 1. az login fails with a multi-factor authentication error

**What happened**
`az login` printed *Authentication failed against tenant ... AADSTS50076: you must use multi-factor authentication* and ended with *No subscriptions found*.

**Why**
The tenant (Default Directory) requires MFA. A plain `az login` tries all tenants and does not complete the MFA step for this one. The error message itself names the fix.

**Fix**

```powershell
az login --tenant <TENANT_ID>
# if the browser flow keeps failing:
az login --tenant <TENANT_ID> --use-device-code
az account list -o table
az account show
```

Approve the MFA prompt in the browser. Afterwards `az account show` displayed the account and subscription (Azure subscription 1). Always confirm the subscription before deploying, so nothing lands in the wrong one.

## 2. Running scripts is disabled on this system

**What happened**
`.\deploy.ps1` failed with *UnauthorizedAccess* and a link to about_Execution_Policies.

**Why**
This is a Windows PowerShell setting, not Azure and not the login. By default many Windows installs block `.ps1` files. It was unclear whether the school enforced it, so `Get-ExecutionPolicy -List` was used to check: all scopes showed *Undefined*, which means no central Group Policy was blocking it.

**Fix**

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
Get-ExecutionPolicy -List     # Process should now show Bypass
```

`-Scope Process` only affects the current PowerShell window and disappears when it is closed.

**What made it work in this session:** PowerShell was opened **as administrator** (right-click, Run as administrator), and the command above was run in that window, answering *A* (Yes to All) at the prompt. After that, `Get-ExecutionPolicy -List` showed *Bypass* for the Process scope and `deploy.ps1` started. Use the administrator window if the same error returns on a school computer.

**Related catch:** the script looks for `azuredeploy.json` in its own folder (`$PSScriptRoot`), so it must be run from:

```powershell
cd D:\MOV25\Azure\W41_Exam\W41\infra
```

## 3. SSH public key not found

**What happened**
The script stopped with *SSH public key not found at C:\Users\98emmwes\.ssh\id_ed25519.pub*.

**Why**
The script's default key name is `id_ed25519.pub`. The key that had been created was named `nordviksshkey` (private) and `nordviksshkey.pub` (public).

**Fix**

```powershell
.\deploy.ps1 -SshKeyPath "C:\Users\98emmwes\.ssh\nordviksshkey.pub"
```

Only the **.pub** file is ever passed to Azure.

**Security warning that came up:** a copy of the key was also in `W41\infra`, which is inside the Git repo, and the repo is public. The **private** key (the file without .pub) must never be in the repo. It should stay only in `C:\Users\<user>\.ssh`. If a private key was ever pushed, deleting it in a later commit is not enough because it stays in the Git history, so a new key pair must be generated.

## 4. Validate fails: QuotaExceeded for standardBasv2Family

**What happened**
The script ran group create and then validate, which failed with *InvalidTemplateDeployment* and the inner error *QuotaExceeded ... Current Limit: 0 ... New Limit Required: 4* for `Standard_B2ats_v2` in Sweden Central.

**Why**
The template itself is valid. The subscription simply has a quota of 0 vCPUs for that VM family. This is common on student and trial subscriptions, and the first guide had warned about it.

**Fix**
Two options exist: request a quota increase (Subscriptions, Usage + quotas), which can take minutes to days and may be refused, or use a VM family that already has quota. The second was chosen.

```powershell
az vm list-usage --location swedencentral `
  --query "[?limit!='0'].{Name:name.localizedValue, Used:currentValue, Limit:limit}" `
  -o table
```

## 5. A PowerShell pipeline error while listing quota

**What happened**
The first attempt to filter the quota list in PowerShell failed with *Cannot convert the System.Object[] value to type System.Int32*.

**Why**
In Windows PowerShell 5.1, `ConvertFrom-Json` passes the whole array on as one object, so `Where-Object` compared the entire list with a number. This was a mistake in the command that was suggested, not in the setup.

**Fix**
Two reliable patterns: let the Azure CLI filter with `--query` (JMESPath), or pipe the JSON through `Out-String` before `ConvertFrom-Json`.

The result showed *Standard BS Family vCPUs* at 0 of 10 used, and Total Regional vCPUs at 2 of 10 used. The Basv2 family was not listed at all, which explains the first failure.

## 6. SkuNotAvailable for Standard_B2s and Standard_D2s_v3

**What happened**
After the size was changed in the parameter files (local and committed), validate failed again, now with *SkuNotAvailable: Following SKUs have failed for Capacity Restrictions*. This happened first for `Standard_B2s` and then for `Standard_D2s_v3`.

**Why**
This is a different limit from quota. **Quota** is how much you are allowed. A **capacity restriction** is what Azure will currently provide to this subscription in this region. Both checks must pass. Having quota for the BS and DSv3 families did not help, because those sizes were restricted.

**Fix**
Azure can list which sizes are unrestricted for the subscription:

```powershell
$skus = az vm list-skus --location swedencentral `
  --resource-type virtualMachines -o json | Out-String | ConvertFrom-Json
$skus |
  Where-Object { ($_.restrictions | Where-Object type -eq 'Location').Count -eq 0 } |
  Where-Object { [int](($_.capabilities |
    Where-Object name -eq 'vCPUs').value) -le 2 } |
  Select-Object name, family | Sort-Object name | Format-Table -AutoSize
```

## 7. Finding a size that passes both checks

**What happened**
The unrestricted list contained about 80 sizes, but several of them had no quota.

**Why**
The two lists were compared. A usable size must be in the unrestricted list **and** belong to a family with quota. For example the B-series v2 sizes (including `Standard_B2s_v2`, which was suggested earlier before this cross-check) are unrestricted but have no quota, and the whole v5 generation does not appear in the quota list.

**Fix**
The chosen size was **Standard_D2ls_v6** (2 vCPU, 4 GB, family Dlsv6, limit 10). The v6 and v7 generations require the NVMe disk controller, which the template already exposes as a parameter. Sizes with a *p* in the name are ARM processors and do not fit the x64 Ubuntu image.

In `azuredeploy.parameters.json` (and the local copy):

```json
"vmSize": { "value": "Standard_D2ls_v6" },
"vmDiskControllerType": { "value": "NVMe" }
```

```powershell
.\deploy.ps1 `
  -SshKeyPath "C:\Users\98emmwes\.ssh\nordviksshkey.pub"
```

Validate and what-if passed, the question *Continue with create?* was answered with y, and the deployment succeeded.

## Result

The Azure portal shows 12 resources in `rg-nordvik` (Sweden Central), deployment status Succeeded, and the website form displays:

| Resource | Type |
|----------|------|
| id-nordvik-app | Managed identity (for the portal to reach storage) |
| vnet-nordvik | Virtual network with snet-web and snet-data |
| nsg-nordvik-web / nsg-nordvik-data | Network security groups, one per subnet |
| stnordvik98emmwes01 | Storage account (ZRS, no public blob access, firewall default Deny) |
| pe-nordvik-storage + NIC | Private endpoint for blob storage in snet-data |
| privatelink.blob.core.windows.net | Private DNS zone linked to the VNet |
| pip-nordvik-web, nic-nordvik-web | Public IP and network card for the web server |
| vm-nordvik-web + osdisk | Ubuntu web server (Standard_D2ls_v6, NVMe) running nginx |

## Lessons and checklist

- **Read the error's own hint.** The MFA message named the tenant switch, and the quota message gave the exact limit and family. Both pointed straight at the fix.
- **Separate the layers.** Login, local PowerShell settings, your files, and Azure's limits fail in different ways. The template was never the problem here.
- **Quota and capacity are two different checks.** Check both before choosing a VM size.
- **Keep the committed parameter file in sync** with what you actually deployed, so the solution can be recreated from the repo (Delmoment 5 in the assignment).
- **Never commit a private key.** Only the .pub file is ever needed, and only from your .ssh folder.
- **Your public IP changes.** If storage or SSH is suddenly blocked later, run the script again so it picks up the new IP.

### Commands to reuse

```powershell
az login --tenant <TENANT_ID>
az account show
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
cd D:\MOV25\Azure\W41_Exam\W41\infra
.\deploy.ps1 -SshKeyPath "C:\Users\98emmwes\.ssh\nordviksshkey.pub"

# website address from the deployment output
az deployment group show --resource-group rg-nordvik --name azuredeploy `
  --query properties.outputs.webUrl.value -o tsv

# save money when not working (restart with az vm start)
az vm deallocate --resource-group rg-nordvik --name vm-nordvik-web
```
