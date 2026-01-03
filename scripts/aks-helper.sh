#!/bin/bash

# AKS Helper Script
# Provides common operations for AKS cluster management

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit 1
}

success() {
    echo -e "${GREEN}SUCCESS: $1${NC}"
}

warning() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

info() {
    echo -e "INFO: $1"
}

# Check if required commands exist
check_requirements() {
    local requirements=("az" "kubectl" "terraform")
    for cmd in "${requirements[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            error "$cmd is not installed. Please install it first."
        fi
    done
}

# Get cluster credentials
get_credentials() {
    info "Getting AKS credentials..."
    
    local rg_name
    local cluster_name
    
    rg_name=$(terraform output -raw resource_group_name 2>/dev/null) || error "Failed to get resource group name"
    cluster_name=$(terraform output -raw aks_cluster_name 2>/dev/null) || error "Failed to get cluster name"
    
    az aks get-credentials \
        --resource-group "$rg_name" \
        --name "$cluster_name" \
        --overwrite-existing
    
    success "Credentials configured for cluster: $cluster_name"
}

# Check cluster health
check_health() {
    info "Checking cluster health..."
    
    echo ""
    echo "=== Nodes ==="
    kubectl get nodes -o wide
    
    echo ""
    echo "=== System Pods ==="
    kubectl get pods -n kube-system
    
    echo ""
    echo "=== Cluster Info ==="
    kubectl cluster-info
    
    echo ""
    echo "=== Component Status ==="
    kubectl get --raw='/readyz?verbose'
}

# Get cluster version
check_version() {
    info "Checking Kubernetes version..."
    
    echo "Server Version:"
    kubectl version --short
    
    echo ""
    echo "Available Upgrades:"
    local rg_name
    local cluster_name
    
    rg_name=$(terraform output -raw resource_group_name 2>/dev/null)
    cluster_name=$(terraform output -raw aks_cluster_name 2>/dev/null)
    
    az aks get-upgrades \
        --resource-group "$rg_name" \
        --name "$cluster_name" \
        --output table
}

# Install NGINX Ingress Controller
install_nginx_ingress() {
    info "Installing NGINX Ingress Controller..."
    
    kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply -f -
    
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
    
    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz \
        --set controller.service.externalTrafficPolicy=Local
    
    success "NGINX Ingress Controller installed"
    
    info "Waiting for external IP..."
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=120s
    
    kubectl get service -n ingress-nginx
}

# Install cert-manager
install_cert_manager() {
    info "Installing cert-manager..."
    
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml
    
    info "Waiting for cert-manager pods..."
    kubectl wait --namespace cert-manager \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/instance=cert-manager \
        --timeout=120s
    
    success "cert-manager installed"
}

# Setup monitoring
setup_monitoring() {
    info "Setting up Prometheus and Grafana..."
    
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
        --set grafana.adminPassword=admin
    
    success "Monitoring stack installed"
    
    info "Access Grafana with:"
    echo "kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
    echo "Then visit http://localhost:3000 (admin/admin)"
}

# Get logs from system pods
get_logs() {
    local pod_name=$1
    
    if [ -z "$pod_name" ]; then
        echo "Available system pods:"
        kubectl get pods -n kube-system
        echo ""
        read -p "Enter pod name: " pod_name
    fi
    
    kubectl logs -n kube-system "$pod_name" --tail=100
}

# Run security scan
security_scan() {
    info "Running security scan..."
    
    if ! command -v kubesec &> /dev/null; then
        warning "kubesec not installed. Install with: brew install kubesec"
        return
    fi
    
    # Scan all YAML files in current directory
    find . -name "*.yaml" -o -name "*.yml" | while read -r file; do
        echo "Scanning $file..."
        kubesec scan "$file"
    done
}

# Show resource usage
show_resources() {
    info "Cluster resource usage..."
    
    echo "=== Node Resources ==="
    kubectl top nodes
    
    echo ""
    echo "=== Pod Resources (kube-system) ==="
    kubectl top pods -n kube-system
    
    echo ""
    echo "=== All Namespaces Pod Count ==="
    kubectl get pods --all-namespaces --no-headers | \
        awk '{print $1}' | sort | uniq -c | sort -rn
}

# Cleanup failed pods
cleanup_failed_pods() {
    warning "This will delete all failed pods..."
    read -p "Continue? (y/N) " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kubectl get pods --all-namespaces --field-selector status.phase=Failed -o json | \
            kubectl delete -f -
        success "Failed pods cleaned up"
    else
        info "Cleanup cancelled"
    fi
}

# Main menu
show_menu() {
    echo ""
    echo "==================================="
    echo "    AKS Management Helper"
    echo "==================================="
    echo "1.  Get cluster credentials"
    echo "2.  Check cluster health"
    echo "3.  Check Kubernetes version"
    echo "4.  Install NGINX Ingress"
    echo "5.  Install cert-manager"
    echo "6.  Setup monitoring (Prometheus/Grafana)"
    echo "7.  Get pod logs"
    echo "8.  Show resource usage"
    echo "9.  Run security scan"
    echo "10. Cleanup failed pods"
    echo "11. Exit"
    echo "==================================="
    echo ""
}

# Main script
main() {
    check_requirements
    
    while true; do
        show_menu
        read -p "Select option [1-11]: " choice
        
        case $choice in
            1) get_credentials ;;
            2) check_health ;;
            3) check_version ;;
            4) install_nginx_ingress ;;
            5) install_cert_manager ;;
            6) setup_monitoring ;;
            7) get_logs ;;
            8) show_resources ;;
            9) security_scan ;;
            10) cleanup_failed_pods ;;
            11) info "Goodbye!"; exit 0 ;;
            *) error "Invalid option" ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Run main if executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
