# GitHub Actions - Quick Start Guide

## 🎯 Goal

Get your AKS infrastructure deployed using GitHub Actions in less than 30 minutes.

## ✅ Prerequisites

- GitHub repository with this code
- Azure subscription
- GitHub CLI installed (`brew install gh`)
- Azure CLI installed
- 10-15 minutes

## 🚀 5-Step Setup

### Step 1: Authenticate (2 minutes)

```bash
# Authenticate with GitHub
gh auth login

# Authenticate with Azure
az login
```

### Step 2: Run Setup Script (3 minutes)

```bash
# Make script executable (if needed)
chmod +x scripts/setup-github-secrets.sh

# Run setup
./scripts/setup-github-secrets.sh

# Follow prompts:
# - Choose to create new service principal: Y
# - Optional: Set up Infracost: Y (or N)
# - Set up environments: Y
```

The script will:
- ✅ Create Azure service principal
- ✅ Configure GitHub secrets
- ✅ Save credentials securely

### Step 3: Create Environments (5 minutes)

Navigate to: **Settings → Environments**

Create these environments with protection rules:

#### dev
```
Name: dev
Protection rules: None
```

#### staging  
```
Name: staging
Protection rules:
  ☑ Required reviewers: 1 person
```

#### prod
```
Name: prod
Protection rules:
  ☑ Required reviewers: 2 people
  ☑ Wait timer: 5 minutes (optional)
```

#### prod-approval
```
Name: prod-approval
Protection rules:
  ☑ Required reviewers: 2 people
```

#### Destroy environments (optional)
```
Names: dev-destroy, staging-destroy, prod-destroy
Protection rules:
  ☑ Required reviewers: 1+ people
```

### Step 4: Configure Environment Files (5 minutes)

```bash
# Create dev configuration
cat > environments/dev.tfvars <<EOF
project_name = "myproject"
environment  = "dev"
location     = "eastus"

admin_group_object_ids = [
  "YOUR_AZURE_AD_GROUP_ID"
]

common_tags = {
  Project     = "AKS-Demo"
  Environment = "Development"
  ManagedBy   = "Terraform-GitHub-Actions"
}
EOF

# Create prod configuration
cat > environments/prod.tfvars <<EOF
project_name = "myproject"
environment  = "prod"
location     = "eastus"

# Production settings
node_count         = 3
node_vm_size       = "Standard_D4s_v3"
enable_private_cluster = true

admin_group_object_ids = [
  "YOUR_AZURE_AD_GROUP_ID"
]

common_tags = {
  Project     = "AKS-Demo"
  Environment = "Production"
  ManagedBy   = "Terraform-GitHub-Actions"
}
EOF

# Get your Azure AD group ID
az ad group list --filter "displayname eq 'AKS-Admins'" --query [0].id -o tsv
```

### Step 5: Test & Deploy (10 minutes)

```bash
# Verify everything is set up
./scripts/verify-workflows.sh

# Create test branch
git checkout -b test/initial-setup

# Commit configuration
git add environments/
git commit -m "Add environment configurations"

# Push and create PR
git push origin test/initial-setup
gh pr create --title "Initial AKS setup" --body "Testing GitHub Actions workflows"
```

**What happens:**
1. ✅ PR triggers `pr-plan.yml`
2. 🔒 Security scans run automatically
3. 💰 Cost estimate generated
4. 📋 Terraform plan posted to PR
5. Review the plan in PR comments

**To deploy:**

```bash
# Option 1: Merge to develop (auto-deploys to dev)
gh pr merge --auto --merge

# Option 2: Manual deployment
gh workflow run deploy-dev.yml
```

## 🎓 What You've Set Up

### Automated Workflows

✅ **Pull Request Validation**
- Runs on every PR
- Validates Terraform
- Security scanning
- Cost estimation
- Posts results to PR

✅ **Development Deployment**
- Auto-deploys on merge to `develop`
- Post-deployment validation
- Smoke tests

✅ **Production Deployment**
- Requires manual trigger
- Pre-deployment checks
- Manual approval required
- Comprehensive validation
- Automatic tagging

✅ **Drift Detection**
- Runs daily at 2 AM UTC
- Detects configuration drift
- Creates GitHub issues
- Prevents configuration drift

✅ **Manual Operations**
- Ad-hoc Terraform operations
- Any environment
- Destroy protection

## 📊 Workflow Status

Check workflow status:

```bash
# List recent runs
gh run list

# View specific run
gh run view <run-id>

# Watch run in real-time
gh run watch
```

## 🔄 Typical Workflow

### Making Changes

```mermaid
graph LR
    A[Create Branch] --> B[Make Changes]
    B --> C[Push & Create PR]
    C --> D[Auto: Plan & Scan]
    D --> E[Review PR Comments]
    E --> F[Merge to develop]
    F --> G[Auto: Deploy to Dev]
    G --> H[Create PR to main]
    H --> I[Auto: Plan Prod]
    I --> J[Merge to main]
    J --> K[Manual: Trigger Deploy]
    K --> L[Approve Deployment]
    L --> M[Auto: Deploy to Prod]
```

### Commands

```bash
# 1. Create feature branch
git checkout -b feature/my-change

# 2. Make changes
vim main.tf

# 3. Commit and push
git add .
git commit -m "feat: add new resource"
git push origin feature/my-change

# 4. Create PR (triggers pr-plan.yml)
gh pr create --base develop

# 5. Review automated plan in PR
# 6. Merge PR (triggers deploy-dev.yml)
gh pr merge --auto --merge

# 7. For production, create PR to main
git checkout main
git pull
git checkout -b release/v1.0.0
git merge develop
git push origin release/v1.0.0
gh pr create --base main

# 8. After merge to main, manually trigger production
gh workflow run deploy-prod.yml
```

## 🔍 Monitoring

### View Workflow Runs

```bash
# List all workflow runs
gh run list --limit 10

# List for specific workflow
gh run list --workflow=deploy-dev.yml

# View detailed run
gh run view <run-id>

# View logs
gh run view <run-id> --log
```

### Check Deployment Status

```bash
# Get cluster info from outputs
gh run view <run-id> --log | grep "cluster_name"

# Access Azure Portal
# Navigate to resource group shown in outputs
```

## 🆘 Troubleshooting

### Workflows Not Running

```bash
# Check if workflows exist
gh workflow list

# Verify secrets
gh secret list

# Check environment configuration
# Settings → Environments
```

### Plan Failures

```bash
# View detailed logs
gh run view <run-id> --log

# Common issues:
# - Missing admin_group_object_ids
# - Invalid tfvars syntax
# - Backend not initialized
```

### Approval Not Appearing

```bash
# Verify environment protection rules
# Settings → Environments → prod → Protection rules
# - Should have "Required reviewers" configured
```

### Authentication Errors

```bash
# Verify secrets are set
gh secret list

# Check service principal
az ad sp show --id <CLIENT_ID>

# Recreate if needed
./scripts/setup-github-secrets.sh
```

## 📚 Next Steps

### Essential Reading
1. [GITHUB_ACTIONS_GUIDE.md](GITHUB_ACTIONS_GUIDE.md) - Complete documentation
2. [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - Deployment details
3. [SECURITY_CHECKLIST.md](SECURITY_CHECKLIST.md) - Security validation

### Advanced Topics
- Custom validation rules
- Notification setup (Slack/Teams)
- Multi-region deployment
- Blue-green deployments
- Automated rollbacks

### Production Readiness
1. Configure production admin reviewers
2. Set up monitoring alerts
3. Configure backup strategy
4. Document runbooks
5. Test disaster recovery

## 💡 Pro Tips

1. **Use Draft PRs** for work-in-progress
   ```bash
   gh pr create --draft
   ```

2. **Review costs before merging**
   - Check Infracost comment on PR
   - Verify against budget

3. **Test in dev first**
   - Always validate in dev environment
   - Use same Terraform code for all envs

4. **Monitor drift daily**
   - Check Issues tab for drift alerts
   - Investigate immediately

5. **Tag production releases**
   - Automatically done by workflow
   - Use for rollback reference

## 🎉 Success!

You now have:
- ✅ Automated Terraform validation
- ✅ Security scanning on every PR
- ✅ Cost estimation
- ✅ Multi-environment deployment
- ✅ Production approval gates
- ✅ Drift detection
- ✅ Comprehensive audit trail

Your infrastructure is now fully automated and production-ready!

---

**Questions?** Check [GITHUB_ACTIONS_GUIDE.md](GITHUB_ACTIONS_GUIDE.md) for detailed documentation.
