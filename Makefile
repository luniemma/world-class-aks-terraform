.PHONY: help init plan apply destroy validate format clean security-scan cost-estimate

# Variables
TERRAFORM := terraform
ENV ?= dev
VAR_FILE := environments/$(ENV).tfvars

# Default target
help:
	@echo "AKS Terraform Makefile"
	@echo ""
	@echo "Usage:"
	@echo "  make init          - Initialize Terraform"
	@echo "  make validate      - Validate Terraform configuration"
	@echo "  make format        - Format Terraform files"
	@echo "  make plan          - Generate execution plan"
	@echo "  make apply         - Apply Terraform configuration"
	@echo "  make destroy       - Destroy infrastructure"
	@echo "  make clean         - Clean Terraform files"
	@echo "  make security-scan - Run security scanning tools"
	@echo "  make cost-estimate - Estimate infrastructure costs"
	@echo "  make kubeconfig    - Get AKS credentials"
	@echo ""
	@echo "Environment:"
	@echo "  ENV=dev (default) - Use dev environment"
	@echo "  ENV=prod          - Use production environment"
	@echo ""
	@echo "Examples:"
	@echo "  make plan ENV=prod"
	@echo "  make apply ENV=dev"

# Initialize Terraform
init:
	@echo "Initializing Terraform..."
	$(TERRAFORM) init

# Validate configuration
validate: format
	@echo "Validating Terraform configuration..."
	$(TERRAFORM) validate

# Format Terraform files
format:
	@echo "Formatting Terraform files..."
	$(TERRAFORM) fmt -recursive

# Generate execution plan
plan: validate
	@echo "Generating execution plan for $(ENV)..."
	@if [ -f "$(VAR_FILE)" ]; then \
		$(TERRAFORM) plan -var-file=$(VAR_FILE) -out=tfplan; \
	else \
		$(TERRAFORM) plan -out=tfplan; \
	fi

# Apply configuration
apply: plan
	@echo "Applying Terraform configuration for $(ENV)..."
	@read -p "Are you sure you want to apply these changes? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		$(TERRAFORM) apply tfplan; \
	else \
		echo "Apply cancelled."; \
	fi

# Auto-approve apply (use with caution)
apply-auto:
	@echo "Applying Terraform configuration for $(ENV) (auto-approve)..."
	@if [ -f "$(VAR_FILE)" ]; then \
		$(TERRAFORM) apply -auto-approve -var-file=$(VAR_FILE); \
	else \
		$(TERRAFORM) apply -auto-approve; \
	fi

# Destroy infrastructure
destroy:
	@echo "Destroying infrastructure for $(ENV)..."
	@read -p "Are you ABSOLUTELY sure you want to destroy all resources? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		if [ -f "$(VAR_FILE)" ]; then \
			$(TERRAFORM) destroy -var-file=$(VAR_FILE); \
		else \
			$(TERRAFORM) destroy; \
		fi; \
	else \
		echo "Destroy cancelled."; \
	fi

# Clean Terraform files
clean:
	@echo "Cleaning Terraform files..."
	rm -rf .terraform
	rm -f .terraform.lock.hcl
	rm -f tfplan
	rm -f terraform.tfstate.backup
	@echo "Clean complete. Note: terraform.tfstate preserved."

# Security scanning
security-scan:
	@echo "Running security scans..."
	@echo "\n=== Running tfsec ==="
	@if command -v tfsec >/dev/null 2>&1; then \
		tfsec . --minimum-severity MEDIUM; \
	else \
		echo "tfsec not installed. Install with: brew install tfsec"; \
	fi
	@echo "\n=== Running Checkov ==="
	@if command -v checkov >/dev/null 2>&1; then \
		checkov -d . --framework terraform --quiet; \
	else \
		echo "Checkov not installed. Install with: pip install checkov"; \
	fi

# Cost estimation
cost-estimate:
	@echo "Estimating infrastructure costs..."
	@if command -v infracost >/dev/null 2>&1; then \
		infracost breakdown --path . --format table; \
	else \
		echo "Infracost not installed. Install from: https://www.infracost.io/docs/"; \
	fi

# Get kubeconfig
kubeconfig:
	@echo "Getting AKS credentials..."
	@RG_NAME=$$($(TERRAFORM) output -raw resource_group_name 2>/dev/null); \
	CLUSTER_NAME=$$($(TERRAFORM) output -raw aks_cluster_name 2>/dev/null); \
	if [ -n "$$RG_NAME" ] && [ -n "$$CLUSTER_NAME" ]; then \
		az aks get-credentials --resource-group $$RG_NAME --name $$CLUSTER_NAME --overwrite-existing; \
		echo "Credentials updated. Test with: kubectl get nodes"; \
	else \
		echo "Error: Could not retrieve cluster information. Run 'make apply' first."; \
	fi

# Show outputs
output:
	@echo "Terraform outputs:"
	$(TERRAFORM) output

# Refresh state
refresh:
	@echo "Refreshing Terraform state..."
	$(TERRAFORM) refresh

# Show current state
show:
	@echo "Current Terraform state:"
	$(TERRAFORM) show

# List resources
list:
	@echo "Terraform resources:"
	$(TERRAFORM) state list

# Upgrade providers
upgrade:
	@echo "Upgrading Terraform providers..."
	$(TERRAFORM) init -upgrade

# Generate documentation
docs:
	@echo "Generating Terraform documentation..."
	@if command -v terraform-docs >/dev/null 2>&1; then \
		terraform-docs markdown table --output-file TERRAFORM_DOCS.md .; \
	else \
		echo "terraform-docs not installed. Install from: https://terraform-docs.io/"; \
	fi
