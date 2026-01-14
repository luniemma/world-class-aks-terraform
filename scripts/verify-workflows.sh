#!/bin/bash

# Enhanced GitHub Actions Workflow Verification Script
# Verifies all required secrets and configurations with actionable fix suggestions

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}  Workflow Configuration Checker${NC}"
echo -e "${BLUE}  Enhanced Version${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""

ERRORS=0
WARNINGS=0
MISSING_ENVS=()
MISSING_FILES=()
FIX_SUGGESTIONS=()

# Check GitHub CLI
echo -e "${YELLOW}Checking prerequisites...${NC}"
if ! command -v gh &> /dev/null; then
    echo -e "${RED}✗ GitHub CLI not installed${NC}"
    ERRORS=$((ERRORS + 1))
    FIX_SUGGESTIONS+=("Install GitHub CLI: https://cli.github.com/")
else
    echo -e "${GREEN}✓ GitHub CLI installed${NC}"
fi

# Check authentication
if gh auth status &> /dev/null; then
    echo -e "${GREEN}✓ Authenticated with GitHub${NC}"
else
    echo -e "${RED}✗ Not authenticated with GitHub${NC}"
    ERRORS=$((ERRORS + 1))
    FIX_SUGGESTIONS+=("Run: gh auth login")
fi

echo ""

# Get repository info
if gh repo view &> /dev/null; then
    REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
    REPO_OWNER=$(gh repo view --json owner -q .owner.login)
    REPO_NAME=$(gh repo view --json name -q .name)
    echo -e "${BLUE}Repository: $REPO${NC}"
else
    echo -e "${RED}✗ Not in a Git repository${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Checking GitHub Secrets...${NC}"

# Check required secrets
REQUIRED_SECRETS=(
    "AZURE_CLIENT_ID"
    "AZURE_CLIENT_SECRET"
    "AZURE_SUBSCRIPTION_ID"
    "AZURE_TENANT_ID"
    "AZURE_CREDENTIALS"
)

MISSING_SECRETS=()
for secret in "${REQUIRED_SECRETS[@]}"; do
    if gh secret list | grep -q "^$secret"; then
        echo -e "${GREEN}✓ $secret configured${NC}"
    else
        echo -e "${RED}✗ $secret missing${NC}"
        ERRORS=$((ERRORS + 1))
        MISSING_SECRETS+=("$secret")
    fi
done

# Check optional secrets
if gh secret list | grep -q "^INFRACOST_API_KEY"; then
    echo -e "${GREEN}✓ INFRACOST_API_KEY configured (optional)${NC}"
else
    echo -e "${YELLOW}⚠ INFRACOST_API_KEY not configured (optional)${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# Add fix suggestion for missing secrets
if [ ${#MISSING_SECRETS[@]} -gt 0 ]; then
    FIX_SUGGESTIONS+=("Missing Azure secrets? Run: ./setup-github-secrets-fixed.sh")
fi

echo ""
echo -e "${YELLOW}Checking GitHub Environments...${NC}"

# Check environments with detailed status
REQUIRED_ENVS=("dev" "staging" "prod" "prod-approval")
PROD_ENVS=("prod" "prod-approval")

for env in "${REQUIRED_ENVS[@]}"; do
    if gh api "repos/$REPO_OWNER/$REPO_NAME/environments/$env" &> /dev/null; then
        echo -e "${GREEN}✓ Environment '$env' exists${NC}"
        
        # Check protection rules for prod
        if [[ " ${PROD_ENVS[@]} " =~ " ${env} " ]]; then
            PROTECTION_RULES=$(gh api "repos/$REPO_OWNER/$REPO_NAME/environments/$env" -q '.protection_rules | length' 2>/dev/null || echo "0")
            REVIEWERS=$(gh api "repos/$REPO_OWNER/$REPO_NAME/environments/$env" -q '.protection_rules[0].reviewers | length' 2>/dev/null || echo "0")
            
            if [ "$REVIEWERS" -gt 1 ]; then
                echo -e "${GREEN}  ✓ $REVIEWERS reviewers configured${NC}"
            elif [ "$REVIEWERS" -eq 1 ]; then
                echo -e "${YELLOW}  ⚠ Only 1 reviewer (2+ recommended for production)${NC}"
                WARNINGS=$((WARNINGS + 1))
            else
                echo -e "${RED}  ✗ No reviewers configured (CRITICAL for production)${NC}"
                ERRORS=$((ERRORS + 1))
                FIX_SUGGESTIONS+=("Add reviewers to '$env' environment: https://github.com/$REPO/settings/environments")
            fi
        fi
    else
        echo -e "${RED}✗ Environment '$env' missing${NC}"
        ERRORS=$((ERRORS + 1))
        MISSING_ENVS+=("$env")
    fi
done

# Add fix suggestion for missing environments
if [ ${#MISSING_ENVS[@]} -gt 0 ]; then
    FIX_SUGGESTIONS+=("Create missing environments: See GITHUB_ENVIRONMENTS_SETUP.md")
    FIX_SUGGESTIONS+=("Quick link: https://github.com/$REPO/settings/environments")
fi

echo ""
echo -e "${YELLOW}Checking Workflow Files...${NC}"

# Check workflow files exist
WORKFLOW_FILES=(
    ".github/workflows/terraform-reusable.yml"
    ".github/workflows/pr-plan.yml"
    ".github/workflows/deploy-dev.yml"
    ".github/workflows/deploy-prod.yml"
    ".github/workflows/manual-operations.yml"
    ".github/workflows/drift-detection.yml"
)

for workflow in "${WORKFLOW_FILES[@]}"; do
    if [ -f "$workflow" ]; then
        echo -e "${GREEN}✓ $(basename "$workflow")${NC}"
    else
        echo -e "${RED}✗ $(basename "$workflow") missing${NC}"
        ERRORS=$((ERRORS + 1))
    fi
done

echo ""
echo -e "${YELLOW}Checking Configuration Files...${NC}"

# Check tfvars files
if [ -f "environments/dev.tfvars" ]; then
    echo -e "${GREEN}✓ environments/dev.tfvars exists${NC}"
    
    # Validate it's not empty
    if [ ! -s "environments/dev.tfvars" ]; then
        echo -e "${YELLOW}  ⚠ File is empty${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo -e "${RED}✗ environments/dev.tfvars missing${NC}"
    ERRORS=$((ERRORS + 1))
    MISSING_FILES+=("environments/dev.tfvars")
    FIX_SUGGESTIONS+=("Copy dev.tfvars template to environments/dev.tfvars")
fi

if [ -f "environments/prod.tfvars" ]; then
    echo -e "${GREEN}✓ environments/prod.tfvars exists${NC}"
    
    # Check critical production settings
    if grep -q "private_cluster_enabled.*=.*true" environments/prod.tfvars 2>/dev/null; then
        echo -e "${GREEN}  ✓ Private cluster enabled${NC}"
    else
        echo -e "${YELLOW}  ⚠ Private cluster should be enabled for production${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
    
    # Check if auto-scaling is configured
    if grep -q "enable_auto_scaling.*=.*true" environments/prod.tfvars 2>/dev/null; then
        echo -e "${GREEN}  ✓ Auto-scaling enabled${NC}"
    fi
else
    echo -e "${RED}✗ environments/prod.tfvars missing${NC}"
    ERRORS=$((ERRORS + 1))
    MISSING_FILES+=("environments/prod.tfvars")
fi

echo ""
echo -e "${YELLOW}Testing GitHub API Access...${NC}"

# Test workflow trigger
if gh workflow list &> /dev/null; then
    echo -e "${GREEN}✓ Can list workflows${NC}"
    
    # Show workflow status
    echo ""
    echo -e "${BLUE}Recent workflow runs:${NC}"
    
    # Get recent runs with better formatting
    RECENT_RUNS=$(gh run list --limit 5 --json conclusion,displayTitle,workflowName,event,createdAt 2>/dev/null)
    
    if [ ! -z "$RECENT_RUNS" ] && [ "$RECENT_RUNS" != "[]" ]; then
        echo "$RECENT_RUNS" | jq -r '.[] | 
            if .conclusion == "success" then
                "\u001b[32m✓\u001b[0m " + .displayTitle + " (" + .workflowName + ")"
            elif .conclusion == "failure" then
                "\u001b[31m✗\u001b[0m " + .displayTitle + " (" + .workflowName + ")"
            else
                "\u001b[33m○\u001b[0m " + .displayTitle + " (" + .workflowName + ")"
            end'
        
        # Count failures
        FAILURES=$(echo "$RECENT_RUNS" | jq '[.[] | select(.conclusion == "failure")] | length')
        if [ "$FAILURES" -gt 0 ]; then
            echo ""
            echo -e "${YELLOW}⚠ $FAILURES recent workflow failure(s) detected${NC}"
            WARNINGS=$((WARNINGS + 1))
            FIX_SUGGESTIONS+=("Debug workflow failures: Run ./quick-fix.sh and select option 1")
            FIX_SUGGESTIONS+=("Or view logs: gh run view --log")
        fi
    else
        echo -e "${CYAN}No workflow runs yet${NC}"
    fi
else
    echo -e "${RED}✗ Cannot access workflows${NC}"
    ERRORS=$((ERRORS + 1))
fi

echo ""
echo -e "${YELLOW}Checking Terraform Backend...${NC}"

# Check if backend.tf exists
if [ -f "terraform/backend.tf" ]; then
    echo -e "${GREEN}✓ terraform/backend.tf exists${NC}"
    
    # Try to extract backend config
    if grep -q "backend.*\"azurerm\"" terraform/backend.tf 2>/dev/null; then
        echo -e "${GREEN}  ✓ Using Azure backend${NC}"
    fi
else
    echo -e "${YELLOW}⚠ terraform/backend.tf not found (may use local backend)${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""
echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}  Verification Summary${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""

# Detailed summary
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Your GitHub Actions setup is ready.${NC}"
    echo ""
    echo -e "${CYAN}🚀 Ready to deploy!${NC}"
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}⚠ $WARNINGS warning(s) found${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Configuration is functional but could be improved.${NC}"
else
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}✗ $ERRORS error(s) and $WARNINGS warning(s) found${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}Please fix errors before using workflows.${NC}"
fi

echo ""

# Show what's missing
if [ ${#MISSING_ENVS[@]} -gt 0 ]; then
    echo -e "${RED}Missing Environments:${NC}"
    for env in "${MISSING_ENVS[@]}"; do
        echo -e "  • $env"
    done
    echo ""
fi

if [ ${#MISSING_FILES[@]} -gt 0 ]; then
    echo -e "${RED}Missing Files:${NC}"
    for file in "${MISSING_FILES[@]}"; do
        echo -e "  • $file"
    done
    echo ""
fi

# Provide fix suggestions
if [ ${#FIX_SUGGESTIONS[@]} -gt 0 ]; then
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}💡 Fix Suggestions:${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    for i in "${!FIX_SUGGESTIONS[@]}"; do
        echo -e "${YELLOW}$(($i + 1)).${NC} ${FIX_SUGGESTIONS[$i]}"
    done
    echo ""
fi

# Next steps
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📋 Next Steps:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ $ERRORS -gt 0 ]; then
    echo "  1. Follow the fix suggestions above"
    echo "  2. Run this script again to verify"
    echo "  3. Use ./quick-fix.sh for guided troubleshooting"
    echo "  4. See ACTION_PLAN.md for complete setup guide"
elif [ $WARNINGS -gt 0 ]; then
    echo "  1. Review warnings (optional improvements)"
    echo "  2. Test with: gh workflow run pr-plan.yml"
    echo "  3. Monitor: gh run watch"
else
    echo "  1. Create a test branch: git checkout -b test/github-actions"
    echo "  2. Make a small change to any .tf file"
    echo "  3. Push and create a PR to test workflows"
    echo "  4. Review the automated plan comments"
fi

echo ""

# Provide quick actions
if [ $ERRORS -gt 0 ]; then
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}⚡ Quick Actions:${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if [ ${#MISSING_ENVS[@]} -gt 0 ]; then
        echo -e "${YELLOW}Create environments:${NC}"
        echo "  open https://github.com/$REPO/settings/environments"
        echo ""
    fi
    
    if [ ${#MISSING_FILES[@]} -gt 0 ]; then
        echo -e "${YELLOW}Create missing configuration files:${NC}"
        if [[ " ${MISSING_FILES[@]} " =~ " environments/dev.tfvars " ]]; then
            echo "  cp dev.tfvars environments/dev.tfvars"
            echo "  nano environments/dev.tfvars  # Edit with your values"
            echo "  git add environments/dev.tfvars && git commit -m 'Add dev config' && git push"
        fi
        echo ""
    fi
    
    if [ ${#MISSING_SECRETS[@]} -gt 0 ]; then
        echo -e "${YELLOW}Setup Azure secrets:${NC}"
        echo "  ./setup-github-secrets-fixed.sh"
        echo ""
    fi
    
    echo -e "${YELLOW}Interactive troubleshooting:${NC}"
    echo "  ./quick-fix.sh"
    echo ""
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Exit with error code if there are errors
exit $ERRORS