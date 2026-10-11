<#
.SYNOPSIS
  Deploys the Nordvik baseline (W41/infra/azuredeploy.json) to Azure.

.DESCRIPTION
  Looks up your current public IP and SSH public key at run time and passes
  them as parameters, so no personal values are stored in the repo.
  Static values (namePrefix, userName, repoUrl ...) come from the parameter file.

.EXAMPLE
  .\deploy.ps1                 # group create + validate + what-if, then asks before create
  .\deploy.ps1 -Mode validate  # only validate
  .\deploy.ps1 -Mode whatif    # only what-if
  .\deploy.ps1 -Mode create    # create without the extra questions
#>
param(
    [ValidateSet("all", "validate", "whatif", "create")]
    [string]$Mode = "all",

    [string]$ResourceGroup  = "rg-nordvik",
    [string]$Location       = "swedencentral",
    [string]$TemplateFile   = (Join-Path $PSScriptRoot "azuredeploy.json"),
    [string]$ParameterFile  = "",   # empty = use *.local.json if it exists, else the committed file
    [string]$SshKeyPath     = (Join-Path $HOME ".ssh\id_ed25519.pub"),
    [string]$AdminIp        = ""   # leave empty to auto-detect
)

$ErrorActionPreference = "Stop"

function Assert-Ok($step) {
    if ($LASTEXITCODE -ne 0) { throw "Step failed: $step (exit code $LASTEXITCODE)" }
}

# --- 0. Pick the parameter file ---------------------------------------------
if (-not $ParameterFile) {
    $local = Join-Path $PSScriptRoot "azuredeploy.parameters.local.json"
    if (Test-Path $local) {
        $ParameterFile = $local
    } else {
        $ParameterFile = Join-Path $PSScriptRoot "azuredeploy.parameters.json"
    }
}
if (-not (Test-Path $ParameterFile)) { throw "Parameter file not found: $ParameterFile" }

# --- 1. Values that are looked up at run time -------------------------------
if (-not $AdminIp) {
    $AdminIp = (Invoke-RestMethod -Uri "https://api.ipify.org").ToString().Trim()
}
if ($AdminIp -notmatch '^\d{1,3}(\.\d{1,3}){3}$') {
    throw "Could not get a valid IPv4 address (got: '$AdminIp'). Pass -AdminIp x.x.x.x manually."
}
if (-not (Test-Path $SshKeyPath)) {
    throw "SSH public key not found at $SshKeyPath. Create one with: ssh-keygen -t ed25519"
}
$SshKey = (Get-Content $SshKeyPath -Raw).Trim()

Write-Host "Resource group : $ResourceGroup ($Location)"
Write-Host "Template       : $TemplateFile"
Write-Host "Parameter file : $ParameterFile"
Write-Host "Admin IP       : $AdminIp"
Write-Host "SSH key        : $SshKeyPath"
Write-Host ""

# Later --parameters override earlier ones, so these win over the placeholders in the file.
$paramArgs = @(
    "--parameters", "@$ParameterFile",
    "--parameters", "adminIp=$AdminIp", "sshPublicKey=$SshKey"
)

# --- 2. Steps ---------------------------------------------------------------
function Invoke-GroupCreate {
    Write-Host "== group create ==" -ForegroundColor Cyan
    az group create --name $ResourceGroup --location $Location | Out-Null
    Assert-Ok "group create"
}

function Invoke-Validate {
    Write-Host "== validate ==" -ForegroundColor Cyan
    az deployment group validate --resource-group $ResourceGroup --template-file $TemplateFile @paramArgs
    Assert-Ok "validate"
}

function Invoke-WhatIf {
    Write-Host "== what-if ==" -ForegroundColor Cyan
    az deployment group what-if --resource-group $ResourceGroup --template-file $TemplateFile @paramArgs
    Assert-Ok "what-if"
}

function Invoke-Create {
    Write-Host "== create ==" -ForegroundColor Cyan
    az deployment group create --resource-group $ResourceGroup --template-file $TemplateFile @paramArgs
    Assert-Ok "create"
}

# --- 3. Run -----------------------------------------------------------------
switch ($Mode) {
    "validate" { Invoke-GroupCreate; Invoke-Validate }
    "whatif"   { Invoke-GroupCreate; Invoke-WhatIf }
    "create"   { Invoke-GroupCreate; Invoke-Create }
    "all" {
        Invoke-GroupCreate
        Invoke-Validate
        Invoke-WhatIf
        $answer = Read-Host "Continue with create? (y/n)"
        if ($answer -eq "y") { Invoke-Create } else { Write-Host "Stopped before create." }
    }
}
