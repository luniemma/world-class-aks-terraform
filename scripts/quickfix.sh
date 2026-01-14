#!/bin/bash

# Quick Fix Script for GitHub Workflows
# This script automates common fixes for workflow failures

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}  GitHub Workflows Quick Fix${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""

# Get repository info
REPO_OWNER=$(gh repo view --json owner -q .owner.login 2>/dev/null)
REPO_NAME=$(gh repo view --json name -q .name 2>/dev/null)

if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ]; then
    echo -e "${RED}Error: Not in a git repository or not authenticated with GitHub CLI${NC}"
    exit 1
fi

echo -e "${BLUE}Repository: ${REPO_OWNER}/${REPO_NAME}${NC}"
echo ""

# Function to check if file exists
check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} $1 exists"
        return 0
    else
        echo -e "${RED}✗${NC} $1 missing"
        return 1
    fi
}

# Function to check if directory exists
check_dir() {
    if [ -d "$1" ]; then
        echo -e "${GREEN}✓${NC} $1 exists"
        return 0
    else
        echo -e "${RED}✗${NC} $1 missing"
        return 1
    fi
}

echo -e "${YELLOW}What would you like to fix?${NC}"
echo ""
echo "1. Check workflow logs for latest failure"
echo "2. View detailed error from specific workflow run"
echo "3. Test Azure service principal authentication"
echo "4. Validate Terraform configuration"
echo "5. Check for missing environments"
echo "6. Verify all required files exist"
echo "7. Enable debug logging for workflows"
echo "8. Re-run failed workflow"
echo "9. View environment configuration"
echo "10. Full diagnostic check"
echo "0. Exit"
echo ""

read -p "Select option (0-10): " OPTION

case $OPTION in
    1)
        echo ""
        echo -e "${BLUE}Fetching latest workflow run...${NC}"
        gh run list --limit 5
        echo ""
        RUN_ID=$(gh run list --limit 1 --json databaseId --jq '.[0].databaseId')
        echo -e "${YELLOW}Viewing logs for run #${RUN_ID}...${NC}"
        gh run view $RUN_ID --log
        ;;
    
    2)
        echo ""
        gh run list --limit 10
        echo ""
        read -p "Enter run ID to view: " RUN_ID
        echo ""
        echo -e "${BLUE}Viewing logs for run #${RUN_ID}...${NC}"
        gh run view $RUN_ID --log
        ;;
    
    3)
        echo ""
        echo -e "${YELLOW}Testing Azure service principal authentication...${NC}"
        echo ""
        
        # Get secrets (note: can't actually read secret values via CLI)
        echo -e "${BLUE}Getting Azure credentials from environment or prompts...${NC}"
        
        if [ -z "$AZURE_CLIENT_ID" ]; then
            read -p "Azure Client ID: " AZURE_CLIENT_ID
        fi
        if [ -z "$AZURE_TENANT_ID" ]; then
            read -p "Azure Tenant ID: " AZURE_TENANT_ID
        fi
        if [ -z "$AZURE_CLIENT_SECRET" ]; then
            read -sp "Azure Client Secret: " AZURE_CLIENT_SECRET
            echo ""
        fi
        if [ -z "$AZURE_SUBSCRIPTION_ID" ]; then
            read -p "Azure Subscription ID [000b9192-a8ef-4cbb-b3a4-8da097b7b301]: " AZURE_SUBSCRIPTION_ID
            AZURE_SUBSCRIPTION_ID=${AZURE_SUBSCRIPTION_ID:-000b9192-a8ef-4cbb-b3a4-8da097b7b301}
        fi
        
        echo ""
        echo -e "${BLUE}Attempting login...${NC}"
        
        if az login --service-principal \
            --username "$AZURE_CLIENT_ID" \
            --password "$AZURE_CLIENT_SECRET" \
            --tenant "$AZURE_TENANT_ID" > /dev/null 2>&1; then
            
            echo -e "${GREEN}✓ Authentication successful${NC}"
            echo ""
            
            az account set --subscription "$AZURE_SUBSCRIPTION_ID"
            echo -e "${BLUE}Current subscription:${NC}"
            az account show --output table
            echo ""
            
            echo -e "${BLUE}Testing permissions - listing resource groups:${NC}"
            az group list --output table
            
        else
            echo -e "${RED}✗ Authentication failed${NC}"
            echo "Please check your credentials and try again."
        fi
        ;;
    
    4)
        echo ""
        echo -e "${YELLOW}Validating Terraform configuration...${NC}"
        echo ""
        
        if ! check_dir "terraform"; then
            echo -e "${RED}terraform/ directory not found${NC}"
            exit 1
        fi
        
        cd terraform
        
        echo -e "${BLUE}Running terraform fmt...${NC}"
        terraform fmt -recursive
        
        echo ""
        echo -e "${BLUE}Running terraform validate...${NC}"
        
        # Try to initialize first
        if ! terraform init -backend=false > /dev/null 2>&1; then
            echo -e "${YELLOW}Note: Backend initialization skipped (use option 10 for full check)${NC}"
        fi
        
        if terraform validate; then
            echo -e "${GREEN}✓ Terraform configuration is valid${NC}"
        else
            echo -e "${RED}✗ Terraform validation failed${NC}"
        fi
        
        cd ..
        ;;
    
    5)
        echo ""
        echo -e "${YELLOW}Checking for GitHub Environments...${NC}"
        echo ""
        
        # List environments via API
        echo -e "${BLUE}Configured environments:${NC}"
        gh api repos/$REPO_OWNER/$REPO_NAME/environments --jq '.environments[].name' 2>/dev/null || {
            echo -e "${YELLOW}No environments found or unable to query${NC}"
            echo ""
            echo -e "${BLUE}Required environments:${NC}"
            echo "  - dev"
            echo "  - staging"
            echo "  - prod"
            echo "  - prod-approval"
            echo ""
            echo "See GITHUB_ENVIRONMENTS_SETUP.md for setup instructions"
        }
        ;;
    
    6)
        echo ""
        echo -e "${YELLOW}Checking for required files...${NC}"
        echo ""
        
        MISSING_FILES=0
        
        echo -e "${BLUE}Environment configuration files:${NC}"
        check_file "environments/dev.tfvars" || ((MISSING_FILES++))
        check_file "environments/staging.tfvars" || echo -e "${YELLOW}⚠${NC} environments/staging.tfvars missing (optional)"
        check_file "environments/prod.tfvars" || ((MISSING_FILES++))
        
        echo ""
        echo -e "${BLUE}Terraform files:${NC}"
        check_dir "terraform" || ((MISSING_FILES++))
        check_file "terraform/main.tf" || ((MISSING_FILES++))
        check_file "terraform/variables.tf" || ((MISSING_FILES++))
        check_file "terraform/backend.tf" || echo -e "${YELLOW}⚠${NC} terraform/backend.tf missing (may be using local backend)"
        
        echo ""
        echo -e "${BLUE}Workflow files:${NC}"
        check_file ".github/workflows/pr-plan.yml" || ((MISSING_FILES++))
        check_file ".github/workflows/deploy-dev.yml" || ((MISSING_FILES++))
        check_file ".github/workflows/deploy-prod.yml" || ((MISSING_FILES++))
        
        echo ""
        if [ $MISSING_FILES -eq 0 ]; then
            echo -e "${GREEN}✓ All required files present${NC}"
        else
            echo -e "${RED}✗ $MISSING_FILES required file(s) missing${NC}"
            echo ""
            echo "If environments/dev.tfvars is missing, use the provided template."
        fi
        ;;
    
    7)
        echo ""
        echo -e "${YELLOW}Enabling debug logging for workflows...${NC}"
        echo ""
        
        gh secret set ACTIONS_RUNNER_DEBUG --body "true" --repo "$REPO_OWNER/$REPO_NAME"
        gh secret set ACTIONS_STEP_DEBUG --body "true" --repo "$REPO_OWNER/$REPO_NAME"
        
        echo -e "${GREEN}✓ Debug logging enabled${NC}"
        echo ""
        echo "Re-run your workflow to see detailed debug output."
        echo "To disable debug logging, delete these secrets:"
        echo "  gh secret delete ACTIONS_RUNNER_DEBUG"
        echo "  gh secret delete ACTIONS_STEP_DEBUG"
        ;;
    
    8)
        echo ""
        echo -e "${YELLOW}Available workflows:${NC}"
        gh workflow list
        echo ""
        
        read -p "Enter workflow filename (e.g., pr-plan.yml): " WORKFLOW
        echo ""
        
        echo -e "${BLUE}Triggering workflow: $WORKFLOW${NC}"
        gh workflow run "$WORKFLOW"
        
        echo ""
        echo -e "${GREEN}✓ Workflow triggered${NC}"
        echo ""
        echo "Watch the run with:"
        echo "  gh run watch"
        ;;
    
    9)
        echo ""
        echo -e "${YELLOW}Environment Configuration${NC}"
        echo ""
        
        for env in dev staging prod prod-approval; do
            echo -e "${BLUE}Environment: $env${NC}"
            gh api "repos/$REPO_OWNER/$REPO_NAME/environments/$env" 2>/dev/null | jq '{
                name: .name,
                protection_rules: .protection_rules | length,
                deployment_branch_policy: .deployment_branch_policy
            }' || echo -e "${RED}  Not found${NC}"
            echo ""
        done
        ;;
    
    10)
        echo ""
        echo -e "${YELLOW}Running full diagnostic check...${NC}"
        echo ""
        
        # Run the verify script if it exists
        if [ -f "scripts/verify-workflows.sh" ]; then
            echo -e "${BLUE}Running verification script...${NC}"
            bash scripts/verify-workflows.sh
        else
            echo -e "${YELLOW}verify-workflows.sh not found, running manual checks...${NC}"
            echo ""
            
            # Check secrets
            echo -e "${BLUE}Checking secrets...${NC}"
            for secret in AZURE_CLIENT_ID AZURE_CLIENT_SECRET AZURE_SUBSCRIPTION_ID AZURE_TENANT_ID AZURE_CREDENTIALS; do
                if gh secret list | grep -q "^$secret"; then
                    echo -e "${GREEN}✓${NC} $secret"
                else
                    echo -e "${RED}✗${NC} $secret"
                fi
            done
            
            echo ""
            echo -e "${BLUE}Checking environments...${NC}"
            for env in dev staging prod prod-approval; do
                if gh api "repos/$REPO_OWNER/$REPO_NAME/environments/$env" &>/dev/null; then
                    echo -e "${GREEN}✓${NC} $env"
                else
                    echo -e "${RED}✗${NC} $env"
                fi
            done
            
            echo ""
            echo -e "${BLUE}Checking files...${NC}"
            check_file "environments/dev.tfvars"
            check_file "environments/prod.tfvars"
            
            echo ""
            echo -e "${BLUE}Recent workflow runs:${NC}"
            gh run list --limit 5
        fi
        ;;
    
    0)
        echo "Exiting..."
        exit 0
        ;;
    
    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}  Done!${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""