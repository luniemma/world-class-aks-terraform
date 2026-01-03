# AKS Terraform Build Script for Windows
# Alternative to Makefile for Windows users

param(
    [Parameter(Position=0, Mandatory=$false)]
    [ValidateSet('help','init','validate','format','plan','apply','destroy','output','kubeconfig','clean','security-scan')]
    [string]$Command = 'help',
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('dev','staging','prod')]
    [string]$Environment = 'dev'
)

$ErrorActionPreference = "Stop"

# Colors for output
function Write-Success { param($Message) Write-Host "✓ $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "→ $Message" -ForegroundColor Cyan }
function Write-Warning { param($Message) Write-Host "⚠ $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "✗ $Message" -ForegroundColor Red }

# Variable file path
$VarFile = "environments\$Environment.tfvars"
if (-not (Test-Path $VarFile) -and $Environment -ne 'dev') {
    $VarFile = "terraform.tfvars"
}

function Show-Help {
    Write-Host ""
    Write-Host "AKS Terraform Build Script" -ForegroundColor Cyan
    Write-Host "===========================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: .\build.ps1 <command> [-Environment <env>]" -ForegroundColor White
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor Yellow
    Write-Host "  help           - Show this help message"
    Write-Host "  init           - Initialize Terraform"
    Write-Host "  validate       - Validate Terraform configuration"
    Write-Host "  format         - Format Terraform files"
    Write-Host "  plan           - Generate execution plan"
    Write-Host "  apply          - Apply Terraform configuration"
    Write-Host "  destroy        - Destroy infrastructure"
    Write-Host "  output         - Show Terraform outputs"
    Write-Host "  kubeconfig     - Get AKS credentials"
    Write-Host "  clean          - Clean Terraform files"
    Write-Host "  security-scan  - Run security scans"
    Write-Host ""
    Write-Host "Environments:" -ForegroundColor Yellow
    Write-Host "  -Environment dev (default)"
    Write-Host "  -Environment staging"
    Write-Host "  -Environment prod"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\build.ps1 plan -Environment dev"
    Write-Host "  .\build.ps1 apply -Environment prod"
    Write-Host "  .\build.ps1 kubeconfig"
    Write-Host ""
}

function Initialize-Terraform {
    Write-Info "Initializing Terraform..."
    terraform init
    Write-Success "Terraform initialized"
}

function Test-Configuration {
    Write-Info "Validating Terraform configuration..."
    
    # Format check
    Write-Info "Checking format..."
    $formatResult = terraform fmt -check -recursive
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Files need formatting. Run: .\build.ps1 format"
    } else {
        Write-Success "Format check passed"
    }
    
    # Validate
    terraform validate
    Write-Success "Configuration validated"
}

function Format-Code {
    Write-Info "Formatting Terraform files..."
    terraform fmt -recursive
    Write-Success "Files formatted"
}

function New-Plan {
    Write-Info "Generating execution plan for $Environment..."
    
    Test-Configuration
    
    $planFile = "tfplan"
    
    if (Test-Path $VarFile) {
        Write-Info "Using variable file: $VarFile"
        terraform plan -var-file=$VarFile -out=$planFile
    } else {
        terraform plan -out=$planFile
    }
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Plan generated: $planFile"
        Write-Info "Review the plan above, then run: .\build.ps1 apply"
    }
}

function Invoke-Apply {
    if (-not (Test-Path "tfplan")) {
        Write-Error "Plan file not found. Run: .\build.ps1 plan"
        exit 1
    }
    
    Write-Warning "You are about to apply changes to $Environment environment"
    $confirmation = Read-Host "Continue? (yes/no)"
    
    if ($confirmation -ne 'yes') {
        Write-Info "Apply cancelled"
        exit 0
    }
    
    Write-Info "Applying Terraform configuration..."
    terraform apply tfplan
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Infrastructure deployed successfully"
        Write-Info "Run '.\build.ps1 kubeconfig' to configure kubectl access"
    }
}

function Invoke-Destroy {
    Write-Warning "⚠ WARNING: You are about to DESTROY the $Environment environment!"
    Write-Warning "This action cannot be undone."
    Write-Host ""
    $confirmation = Read-Host "Type 'DESTROY' to confirm"
    
    if ($confirmation -ne 'DESTROY') {
        Write-Info "Destroy cancelled"
        exit 0
    }
    
    Write-Info "Destroying infrastructure..."
    
    if (Test-Path $VarFile) {
        terraform destroy -var-file=$VarFile
    } else {
        terraform destroy
    }
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Infrastructure destroyed"
    }
}

function Show-Outputs {
    Write-Info "Terraform outputs:"
    terraform output
}

function Get-KubeConfig {
    Write-Info "Getting AKS credentials..."
    
    try {
        $resourceGroup = terraform output -raw resource_group_name
        $clusterName = terraform output -raw aks_cluster_name
        
        Write-Info "Resource Group: $resourceGroup"
        Write-Info "Cluster Name: $clusterName"
        
        az aks get-credentials `
            --resource-group $resourceGroup `
            --name $clusterName `
            --overwrite-existing
        
        Write-Success "Credentials configured"
        Write-Info "Test with: kubectl get nodes"
    }
    catch {
        Write-Error "Failed to get credentials. Make sure infrastructure is deployed."
        Write-Info "Run: .\build.ps1 apply"
    }
}

function Clear-TerraformFiles {
    Write-Info "Cleaning Terraform files..."
    
    $itemsToRemove = @(
        ".terraform",
        ".terraform.lock.hcl",
        "tfplan",
        "terraform.tfstate.backup"
    )
    
    foreach ($item in $itemsToRemove) {
        if (Test-Path $item) {
            Remove-Item $item -Recurse -Force
            Write-Success "Removed: $item"
        }
    }
    
    Write-Warning "Note: terraform.tfstate preserved"
    Write-Success "Clean complete"
}

function Invoke-SecurityScan {
    Write-Info "Running security scans..."
    
    # Check for tfsec
    $tfsecInstalled = Get-Command tfsec -ErrorAction SilentlyContinue
    if ($tfsecInstalled) {
        Write-Info "Running tfsec..."
        tfsec . --minimum-severity MEDIUM
    } else {
        Write-Warning "tfsec not installed"
        Write-Info "Install from: https://github.com/aquasecurity/tfsec"
    }
    
    # Check for checkov
    $checkovInstalled = Get-Command checkov -ErrorAction SilentlyContinue
    if ($checkovInstalled) {
        Write-Info "Running Checkov..."
        checkov -d . --framework terraform --quiet
    } else {
        Write-Warning "Checkov not installed"
        Write-Info "Install with: pip install checkov"
    }
    
    if (-not $tfsecInstalled -and -not $checkovInstalled) {
        Write-Warning "No security scanning tools found"
        Write-Info "Install tfsec or checkov for security scanning"
    }
}

# Main execution
try {
    Write-Host ""
    
    switch ($Command) {
        'help' { Show-Help }
        'init' { Initialize-Terraform }
        'validate' { Test-Configuration }
        'format' { Format-Code }
        'plan' { New-Plan }
        'apply' { Invoke-Apply }
        'destroy' { Invoke-Destroy }
        'output' { Show-Outputs }
        'kubeconfig' { Get-KubeConfig }
        'clean' { Clear-TerraformFiles }
        'security-scan' { Invoke-SecurityScan }
        default { Show-Help }
    }
    
    Write-Host ""
}
catch {
    Write-Error "An error occurred: $_"
    exit 1
}
