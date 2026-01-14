#!/bin/bash

# Master Setup and Fix Script for GitHub Actions Workflows
# This script orchestrates the complete setup process

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

clear

echo -e "${MAGENTA}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                                                           ║"
echo "║    GitHub Actions Workflows - Master Setup Script        ║"
echo "║                                                           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Function to show section headers
section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Function to show step
step() {
    echo -e "${CYAN}➤ $1${NC}"
}

# Function to show success
success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to show error
error() {
    echo -e "${RED}✗ $1${NC}"
}

# Function to show warning
warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Function to ask yes/no
ask() {
    while true; do
        read -p "$1 (y/n): " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

section "Pre-flight Checks"

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    error "Not in a git repository"
    exit 1
fi

success "Git repository detected"

# Check GitHub CLI
if ! command -v gh &> /dev/null; then
    error "GitHub CLI (gh) is not installed"
    echo "Install from: https://cli.github.com/"
    exit 1
fi

success "GitHub CLI installed"

# Check authentication
if ! gh auth status &> /dev/null; then
    warning "Not authenticated with GitHub"
    echo ""
    if ask "Would you like to authenticate now?"; then
        gh auth login
    else
        error "GitHub authentication required"
        exit 1
    fi
fi

success "GitHub authenticated"

# Get repository info
REPO_OWNER=$(gh repo view --json owner -q .owner.login)
REPO_NAME=$(gh repo view --json name -q .name)
REPO="$REPO_OWNER/$REPO_NAME"

echo ""
echo -e "${MAGENTA}Repository: $REPO${NC}"

section "Setup Workflow"

echo "This script will guide you through the complete setup process."
echo "We'll fix all issues found by the verification script."
echo ""
echo "The process includes:"
echo "  1. Checking current status"
echo "  2. Setting up Azure service principal (if needed)"
echo "  3. Creating configuration files"
echo "  4. Verifying GitHub environments"
echo "  5. Running final verification"
echo ""

if ! ask "Continue with setup?"; then
    echo "Setup cancelled"
    exit 0
fi

section "Step 1: Current Status Check"

step "Running verification..."
echo ""

# Create a temporary verification result file
VERIFY_RESULT=$(mktemp)

# Run verification script if it exists
if [ -f "scripts/verify-workflows.sh" ]; then
    bash scripts/verify-workflows.sh > "$VERIFY_RESULT" 2>&1 || true
    cat "$VERIFY_RESULT"
elif [ -f "verify-workflows-enhanced.sh" ]; then
    bash verify-workflows-enhanced.sh > "$VERIFY_RESULT" 2>&1 || true
    cat "$VERIFY_RESULT"
else
    warning "Verification script not found, skipping initial check"
fi

echo ""
read -p "Press Enter to continue..."

section "Step 2: Azure Credentials Setup"

step "Checking Azure secrets..."

NEEDS_SECRETS=false
for secret in AZURE_CLIENT_ID AZURE_CLIENT_SECRET AZURE_SUBSCRIPTION_ID AZURE_TENANT_ID; do
    if ! gh secret list | grep -q "^$secret"; then
        NEEDS_SECRETS=true
        break
    fi
done

if $NEEDS_SECRETS; then
    warning "Some Azure secrets are missing"
    echo ""
    
    if [ -f "setup-github-secrets-fixed.sh" ]; then
        if ask "Would you like to run the Azure setup script now?"; then
            bash setup-github-secrets-fixed.sh
        else
            warning "Skipping Azure setup - you'll need to configure secrets manually"
        fi
    else
        error "setup-github-secrets-fixed.sh not found"
        echo "Please set up Azure secrets manually or obtain the setup script"
    fi
else
    success "All Azure secrets are configured"
fi

section "Step 3: Configuration Files"

step "Checking configuration files..."

# Check for dev.tfvars
if [ ! -f "environments/dev.tfvars" ]; then
    warning "environments/dev.tfvars is missing"
    echo ""
    
    if [ -f "dev.tfvars" ]; then
        echo "Found dev.tfvars template"
        if ask "Would you like to copy it to environments/dev.tfvars?"; then
            mkdir -p environments
            cp dev.tfvars environments/dev.tfvars
            success "Created environments/dev.tfvars"
            echo ""
            echo -e "${YELLOW}IMPORTANT: Edit environments/dev.tfvars with your specific values${NC}"
            echo ""
            
            if ask "Would you like to edit it now?"; then
                ${EDITOR:-nano} environments/dev.tfvars
            fi
            
            if ask "Commit and push this file?"; then
                git add environments/dev.tfvars
                git commit -m "Add development environment configuration"
                git push
                success "Committed and pushed dev.tfvars"
            fi
        fi
    else
        error "dev.tfvars template not found"
        echo "Please create environments/dev.tfvars manually"
    fi
else
    success "environments/dev.tfvars exists"
fi

# Check for prod.tfvars
if [ ! -f "environments/prod.tfvars" ]; then
    warning "environments/prod.tfvars is missing"
    echo "You'll need to create this file for production deployments"
else
    success "environments/prod.tfvars exists"
fi

section "Step 4: GitHub Environments"

step "Checking GitHub Environments..."

MISSING_ENVS=()
for env in dev staging prod prod-approval; do
    if ! gh api "repos/$REPO_OWNER/$REPO_NAME/environments/$env" &> /dev/null; then
        MISSING_ENVS+=("$env")
    fi
done

if [ ${#MISSING_ENVS[@]} -gt 0 ]; then
    error "Missing environments: ${MISSING_ENVS[*]}"
    echo ""
    echo -e "${YELLOW}GitHub Environments must be created through the web interface.${NC}"
    echo ""
    echo "Required environments:"
    echo "  • dev (no protection rules)"
    echo "  • staging (optional: 1 reviewer)"
    echo "  • prod (REQUIRED: 2+ reviewers)"
    echo "  • prod-approval (REQUIRED: 2+ reviewers)"
    echo ""
    echo -e "${CYAN}Quick link: https://github.com/$REPO/settings/environments${NC}"
    echo ""
    
    if ask "Open GitHub Environments page in browser?"; then
        if command -v xdg-open &> /dev/null; then
            xdg-open "https://github.com/$REPO/settings/environments"
        elif command -v open &> /dev/null; then
            open "https://github.com/$REPO/settings/environments"
        elif command -v start &> /dev/null; then
            start "https://github.com/$REPO/settings/environments"
        else
            echo "Please open: https://github.com/$REPO/settings/environments"
        fi
    fi
    
    echo ""
    echo -e "${YELLOW}After creating the environments, press Enter to continue...${NC}"
    read
    
    # Verify environments were created
    step "Verifying environments..."
    STILL_MISSING=()
    for env in "${MISSING_ENVS[@]}"; do
        if ! gh api "repos/$REPO_OWNER/$REPO_NAME/environments/$env" &> /dev/null; then
            STILL_MISSING+=("$env")
        fi
    done
    
    if [ ${#STILL_MISSING[@]} -gt 0 ]; then
        warning "Still missing: ${STILL_MISSING[*]}"
        echo "You can continue, but workflows will fail until these are created"
    else
        success "All environments created!"
    fi
else
    success "All required environments exist"
    
    # Check for reviewers on prod environments
    step "Checking production environment protection..."
    for env in prod prod-approval; do
        REVIEWERS=$(gh api "repos/$REPO_OWNER/$REPO_NAME/environments/$env" -q '.protection_rules[0].reviewers | length' 2>/dev/null || echo "0")
        if [ "$REVIEWERS" -lt 2 ]; then
            warning "$env has $REVIEWERS reviewers (2+ recommended)"
        else
            success "$env has $REVIEWERS reviewers"
        fi
    done
fi

section "Step 5: Final Verification"

step "Running final verification check..."
echo ""

# Run verification again
if [ -f "verify-workflows-enhanced.sh" ]; then
    bash verify-workflows-enhanced.sh
elif [ -f "scripts/verify-workflows.sh" ]; then
    bash scripts/verify-workflows.sh
else
    warning "Verification script not found"
fi

section "Setup Complete!"

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                           ║${NC}"
echo -e "${GREEN}║                 Setup Process Complete!                   ║${NC}"
echo -e "${GREEN}║                                                           ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${CYAN}Next Steps:${NC}"
echo ""
echo "1. Test PR plan workflow:"
echo "   git checkout -b test/workflows"
echo "   echo 'test' >> README.md"
echo "   git add README.md && git commit -m 'test: workflows'"
echo "   git push origin test/workflows"
echo "   gh pr create --title 'Test Workflows' --body 'Testing'"
echo ""
echo "2. Monitor the workflow:"
echo "   gh run watch"
echo ""
echo "3. Check workflow status:"
echo "   gh run list --limit 10"
echo ""
echo "4. View detailed logs if needed:"
echo "   gh run view --log"
echo ""

if [ -f "quick-fix.sh" ]; then
    echo -e "${YELLOW}💡 Tip: Use ./quick-fix.sh for troubleshooting if issues arise${NC}"
    echo ""
fi

echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Cleanup
rm -f "$VERIFY_RESULT"