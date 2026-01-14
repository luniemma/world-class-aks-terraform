#!/bin/bash

# GitHub Actions Secrets Setup Script
# This script helps you set up required secrets for GitHub Actions
# FIXED: Works with Git Bash on Windows

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}  GitHub Actions Secrets Setup${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI (gh) is not installed${NC}"
    echo "Please install it from: https://cli.github.com/"
    exit 1
fi

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo -e "${RED}Error: Azure CLI is not installed${NC}"
    echo "Please install it from: https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
fi

# Check GitHub CLI authentication
echo -e "${YELLOW}Checking GitHub CLI authentication...${NC}"
if ! gh auth status &> /dev/null; then
    echo -e "${YELLOW}Please authenticate with GitHub CLI:${NC}"
    gh auth login
fi

# Check Azure CLI authentication
echo -e "${YELLOW}Checking Azure CLI authentication...${NC}"
if ! az account show &> /dev/null; then
    echo -e "${YELLOW}Please authenticate with Azure CLI:${NC}"
    az login
fi

echo -e "${GREEN}✓ Authentication verified${NC}"
echo ""

# Get repository information
REPO_OWNER=$(gh repo view --json owner -q .owner.login)
REPO_NAME=$(gh repo view --json name -q .name)

echo -e "${BLUE}Repository: ${REPO_OWNER}/${REPO_NAME}${NC}"
echo ""

# Prompt for service principal creation
echo -e "${YELLOW}Do you want to create a new Azure Service Principal? (y/n)${NC}"
read -r CREATE_SP

if [[ "$CREATE_SP" =~ ^[Yy]$ ]]; then
    # Get subscription ID
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    echo -e "${BLUE}Using subscription: $SUBSCRIPTION_ID${NC}"
    
    # Create service principal
    SP_NAME="terraform-aks-github-${REPO_NAME}"
    echo -e "${YELLOW}Creating service principal: $SP_NAME${NC}"
    
    # Use MSYS_NO_PATHCONV to prevent Git Bash path conversion on Windows
    # Use --json-auth instead of deprecated --sdk-auth
    SP_OUTPUT=$(MSYS_NO_PATHCONV=1 az ad sp create-for-rbac \
        --name "$SP_NAME" \
        --role Contributor \
        --scopes "/subscriptions/$SUBSCRIPTION_ID" \
        --json-auth 2>/dev/null || \
        MSYS_NO_PATHCONV=1 az ad sp create-for-rbac \
        --name "$SP_NAME" \
        --role Contributor \
        --scopes "/subscriptions/$SUBSCRIPTION_ID" \
        --sdk-auth)
    
    # Extract values
    CLIENT_ID=$(echo "$SP_OUTPUT" | jq -r '.clientId')
    CLIENT_SECRET=$(echo "$SP_OUTPUT" | jq -r '.clientSecret')
    TENANT_ID=$(echo "$SP_OUTPUT" | jq -r '.tenantId')
    AZURE_CREDENTIALS="$SP_OUTPUT"
    
    echo -e "${GREEN}✓ Service Principal created${NC}"
    echo ""
else
    # Prompt for existing credentials
    echo -e "${YELLOW}Please enter your Azure credentials:${NC}"
    echo ""
    
    read -p "Azure Client ID: " CLIENT_ID
    read -p "Azure Tenant ID: " TENANT_ID
    read -sp "Azure Client Secret: " CLIENT_SECRET
    echo ""
    
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    
    # Build AZURE_CREDENTIALS JSON
    AZURE_CREDENTIALS=$(cat <<EOF
{
  "clientId": "$CLIENT_ID",
  "clientSecret": "$CLIENT_SECRET",
  "subscriptionId": "$SUBSCRIPTION_ID",
  "tenantId": "$TENANT_ID"
}
EOF
)
fi

echo -e "${YELLOW}Setting GitHub secrets...${NC}"

# Set secrets using GitHub CLI
gh secret set AZURE_CLIENT_ID --body "$CLIENT_ID" --repo "$REPO_OWNER/$REPO_NAME"
gh secret set AZURE_CLIENT_SECRET --body "$CLIENT_SECRET" --repo "$REPO_OWNER/$REPO_NAME"
gh secret set AZURE_SUBSCRIPTION_ID --body "$SUBSCRIPTION_ID" --repo "$REPO_OWNER/$REPO_NAME"
gh secret set AZURE_TENANT_ID --body "$TENANT_ID" --repo "$REPO_OWNER/$REPO_NAME"
gh secret set AZURE_CREDENTIALS --body "$AZURE_CREDENTIALS" --repo "$REPO_OWNER/$REPO_NAME"

echo -e "${GREEN}✓ Azure secrets configured${NC}"
echo ""

# Optional: Infracost API Key
echo -e "${YELLOW}Do you want to set up Infracost for cost estimation? (y/n)${NC}"
read -r SETUP_INFRACOST

if [[ "$SETUP_INFRACOST" =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${BLUE}Get your Infracost API key from: https://www.infracost.io/${NC}"
    read -p "Infracost API Key: " INFRACOST_API_KEY
    
    gh secret set INFRACOST_API_KEY --body "$INFRACOST_API_KEY" --repo "$REPO_OWNER/$REPO_NAME"
    echo -e "${GREEN}✓ Infracost API key configured${NC}"
fi

echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}  Setup Complete!${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo -e "${BLUE}Secrets configured:${NC}"
echo "  ✓ AZURE_CLIENT_ID"
echo "  ✓ AZURE_CLIENT_SECRET"
echo "  ✓ AZURE_SUBSCRIPTION_ID"
echo "  ✓ AZURE_TENANT_ID"
echo "  ✓ AZURE_CREDENTIALS"
if [[ "$SETUP_INFRACOST" =~ ^[Yy]$ ]]; then
    echo "  ✓ INFRACOST_API_KEY"
fi
echo ""

# Setup environments
echo -e "${YELLOW}Do you want to set up GitHub Environments? (y/n)${NC}"
read -r SETUP_ENVIRONMENTS

if [[ "$SETUP_ENVIRONMENTS" =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${YELLOW}Setting up GitHub Environments...${NC}"
    echo -e "${BLUE}Note: Environments must be created manually in GitHub UI${NC}"
    echo -e "${BLUE}Navigate to: Settings → Environments${NC}"
    echo ""
    echo "Required environments:"
    echo "  1. dev (no protection rules)"
    echo "  2. staging (optional reviewers)"
    echo "  3. prod (2+ required reviewers)"
    echo "  4. prod-approval (2+ required reviewers)"
    echo "  5. dev-destroy, staging-destroy, prod-destroy (approvals for destroy)"
    echo ""
    echo -e "${YELLOW}Press Enter when environments are created...${NC}"
    read
fi

echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "  1. Review and configure GitHub Environments"
echo "  2. Create terraform.tfvars files for each environment"
echo "  3. Update environments/*.tfvars with your values"
echo "  4. Test with: gh workflow run pr-plan.yml"
echo ""
echo -e "${BLUE}For detailed documentation, see GITHUB_ACTIONS_GUIDE.md${NC}"
echo ""

# Save credentials to a secure file for reference
CREDS_FILE=".github-setup-$(date +%Y%m%d-%H%M%S).txt"
cat > "$CREDS_FILE" <<EOF
GitHub Actions Setup Credentials
Generated: $(date)
Repository: ${REPO_OWNER}/${REPO_NAME}

AZURE_CLIENT_ID: $CLIENT_ID
AZURE_TENANT_ID: $TENANT_ID
AZURE_SUBSCRIPTION_ID: $SUBSCRIPTION_ID
# CLIENT_SECRET: (stored securely in GitHub Secrets)

Service Principal Name: $SP_NAME (if created)

IMPORTANT: Store this file securely and delete after setup!
EOF

echo -e "${YELLOW}Credentials saved to: $CREDS_FILE${NC}"
echo -e "${RED}IMPORTANT: Store this file securely and delete after setup!${NC}"
echo ""