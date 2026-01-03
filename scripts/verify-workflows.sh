#!/bin/bash

# GitHub Actions Workflow Verification Script
# Verifies that all required secrets and configurations are in place

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}  Workflow Configuration Checker${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""

ERRORS=0
WARNINGS=0

# Check GitHub CLI
echo -e "${YELLOW}Checking prerequisites...${NC}"
if ! command -v gh &> /dev/null; then
    echo -e "${RED}✗ GitHub CLI not installed${NC}"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✓ GitHub CLI installed${NC}"
fi

# Check authentication
if gh auth status &> /dev/null; then
    echo -e "${GREEN}✓ Authenticated with GitHub${NC}"
else
    echo -e "${RED}✗ Not authenticated with GitHub${NC}"
    ERRORS=$((ERRORS + 1))
fi

echo ""

# Get repository info
if gh repo view &> /dev/null; then
    REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
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

for secret in "${REQUIRED_SECRETS[@]}"; do
    if gh secret list | grep -q "^$secret"; then
        echo -e "${GREEN}✓ $secret configured${NC}"
    else
        echo -e "${RED}✗ $secret missing${NC}"
        ERRORS=$((ERRORS + 1))
    fi
done

# Check optional secrets
if gh secret list | grep -q "^INFRACOST_API_KEY"; then
    echo -e "${GREEN}✓ INFRACOST_API_KEY configured (optional)${NC}"
else
    echo -e "${YELLOW}⚠ INFRACOST_API_KEY not configured (optional)${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""
echo -e "${YELLOW}Checking GitHub Environments...${NC}"

# Check environments
REQUIRED_ENVS=("dev" "staging" "prod" "prod-approval")

for env in "${REQUIRED_ENVS[@]}"; do
    if gh api "repos/:owner/:repo/environments/$env" &> /dev/null; then
        echo -e "${GREEN}✓ Environment '$env' exists${NC}"
        
        # Check protection rules for prod
        if [ "$env" == "prod" ] || [ "$env" == "prod-approval" ]; then
            REVIEWERS=$(gh api "repos/:owner/:repo/environments/$env" -q '.protection_rules[0].reviewers | length' 2>/dev/null || echo "0")
            if [ "$REVIEWERS" -gt 0 ]; then
                echo -e "${GREEN}  ✓ $REVIEWERS reviewer(s) configured${NC}"
            else
                echo -e "${YELLOW}  ⚠ No reviewers configured${NC}"
                WARNINGS=$((WARNINGS + 1))
            fi
        fi
    else
        echo -e "${RED}✗ Environment '$env' missing${NC}"
        ERRORS=$((ERRORS + 1))
    fi
done

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
else
    echo -e "${YELLOW}⚠ environments/dev.tfvars missing${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

if [ -f "environments/prod.tfvars" ]; then
    echo -e "${GREEN}✓ environments/prod.tfvars exists${NC}"
    
    # Check critical production settings
    if grep -q "enable_private_cluster *= *true" environments/prod.tfvars; then
        echo -e "${GREEN}  ✓ Private cluster enabled${NC}"
    else
        echo -e "${RED}  ✗ Private cluster should be enabled for production${NC}"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${YELLOW}⚠ environments/prod.tfvars missing${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""
echo -e "${YELLOW}Testing GitHub API Access...${NC}"

# Test workflow trigger
if gh workflow list &> /dev/null; then
    echo -e "${GREEN}✓ Can list workflows${NC}"
    
    # Show workflow status
    echo ""
    echo -e "${BLUE}Recent workflow runs:${NC}"
    gh run list --limit 5 2>/dev/null || echo "No workflow runs yet"
else
    echo -e "${RED}✗ Cannot access workflows${NC}"
    ERRORS=$((ERRORS + 1))
fi

echo ""
echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}  Verification Summary${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo -e "${GREEN}Your GitHub Actions setup is ready.${NC}"
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ $WARNINGS warning(s) found${NC}"
    echo -e "${YELLOW}Configuration is functional but could be improved.${NC}"
else
    echo -e "${RED}✗ $ERRORS error(s) and $WARNINGS warning(s) found${NC}"
    echo -e "${RED}Please fix errors before using workflows.${NC}"
fi

echo ""
echo -e "${BLUE}Next Steps:${NC}"

if [ $ERRORS -gt 0 ]; then
    echo "  1. Fix the errors listed above"
    echo "  2. Run this script again to verify"
    echo "  3. For help, see GITHUB_ACTIONS_GUIDE.md"
elif [ $WARNINGS -gt 0 ]; then
    echo "  1. Review warnings (optional improvements)"
    echo "  2. Test with: gh workflow run pr-plan.yml"
    echo "  3. See GITHUB_ACTIONS_GUIDE.md for full documentation"
else
    echo "  1. Create a test branch: git checkout -b test/github-actions"
    echo "  2. Make a small change to any .tf file"
    echo "  3. Push and create a PR to test workflows"
    echo "  4. Review the automated plan comments"
fi

echo ""

# Provide specific fix commands for common issues
if [ $ERRORS -gt 0 ]; then
    echo -e "${YELLOW}Quick Fixes:${NC}"
    echo ""
    
    if ! gh secret list | grep -q "AZURE_CLIENT_ID"; then
        echo "Missing Azure secrets? Run:"
        echo "  ./scripts/setup-github-secrets.sh"
        echo ""
    fi
    
    if ! gh api "repos/:owner/:repo/environments/dev" &> /dev/null; then
        echo "Missing environments? Create them in GitHub:"
        echo "  Settings → Environments → New environment"
        echo ""
    fi
fi

exit $ERRORS
