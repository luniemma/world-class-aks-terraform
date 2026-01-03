# AKS Security Checklist

## Pre-Deployment Security Checks

### Identity & Access Management
- [ ] Azure AD integration enabled (`azure_rbac_enabled = true`)
- [ ] Admin group Object IDs configured
- [ ] Local accounts disabled (`local_account_disabled = true`)
- [ ] Managed identity configured (User-assigned identity)
- [ ] Workload identity enabled for pod authentication
- [ ] RBAC enabled at both cluster and Azure levels

### Network Security
- [ ] Private cluster enabled (`enable_private_cluster = true`) for production
- [ ] Network Security Groups (NSG) configured on AKS subnet
- [ ] Network policies enabled (`network_policy = "azure"` or `"calico"`)
- [ ] Azure CNI networking configured for better network integration
- [ ] VNet peering configured (if connecting to other networks)
- [ ] Service endpoints configured for Azure services
- [ ] Appropriate firewall rules for API server access

### Container Security
- [ ] Microsoft Defender for Containers enabled
- [ ] Azure Policy add-on enabled
- [ ] Image scanning configured in CI/CD pipeline
- [ ] Container registry vulnerability scanning enabled
- [ ] Pod Security Standards/Policies defined
- [ ] No privileged containers allowed (policy)

### Secrets Management
- [ ] Key Vault Secrets Provider enabled
- [ ] Secret rotation enabled and configured
- [ ] Secrets never stored in Git repository
- [ ] Environment variables used for sensitive data
- [ ] OIDC workload identity for external service access

### Monitoring & Logging
- [ ] Azure Monitor Container Insights enabled
- [ ] Log Analytics workspace configured
- [ ] Diagnostic settings enabled for all log categories
- [ ] Alert rules configured for security events
- [ ] Log retention policy meets compliance requirements
- [ ] Microsoft Defender alerts configured

### Cluster Configuration
- [ ] Kubernetes version is supported and recent
- [ ] Automatic upgrades enabled (`automatic_channel_upgrade = "patch"`)
- [ ] Maintenance window configured
- [ ] Run command disabled (`run_command_enabled = false`)
- [ ] Authorized IP ranges configured (if not private cluster)
- [ ] API server access limited to specific IPs/VNets

### Node Security
- [ ] Nodes use managed disks with encryption
- [ ] OS disk encryption enabled
- [ ] Node image auto-upgrade enabled
- [ ] Minimal node pool configuration
- [ ] No public IP addresses on nodes
- [ ] SSH access restricted or disabled

### Compliance & Governance
- [ ] Required tags applied to all resources
- [ ] Resource naming follows organizational standards
- [ ] Cost allocation tags configured
- [ ] Backup and disaster recovery plan documented
- [ ] Data residency requirements met
- [ ] Compliance frameworks mapped (HIPAA, PCI-DSS, etc.)

## Post-Deployment Security Checks

### Immediate Actions
- [ ] Verify cluster is accessible only from authorized networks
- [ ] Test Azure AD authentication
- [ ] Verify RBAC permissions are working
- [ ] Check that local accounts are disabled
- [ ] Verify monitoring and logging are active
- [ ] Review initial security scan results

### Configuration Validation
- [ ] Run `kubectl get nodes` from authorized location only
- [ ] Verify network policies are enforced
- [ ] Test pod-to-pod communication restrictions
- [ ] Verify secrets are accessible via Key Vault
- [ ] Test workload identity configuration
- [ ] Validate Azure Policy compliance

### Security Scanning
```bash
# Run security audit
kubectl get all --all-namespaces

# Check for privileged pods
kubectl get pods --all-namespaces -o json | \
  jq '.items[] | select(.spec.containers[].securityContext.privileged==true) | .metadata.name'

# Check pod security policies
kubectl get psp

# Review RBAC permissions
kubectl get clusterrolebindings
kubectl get rolebindings --all-namespaces
```

### Monitoring Setup
- [ ] Configure alerts for:
  - Failed authentication attempts
  - Privileged pod creation
  - High resource utilization
  - Suspicious network activity
  - Policy violations
  - Certificate expiration warnings

## Ongoing Security Maintenance

### Weekly Tasks
- [ ] Review Azure Advisor security recommendations
- [ ] Check for available Kubernetes patches
- [ ] Review security logs for anomalies
- [ ] Verify backup completion

### Monthly Tasks
- [ ] Review and update network policies
- [ ] Audit RBAC permissions
- [ ] Review and rotate secrets
- [ ] Update security documentation
- [ ] Review cost optimization opportunities
- [ ] Test disaster recovery procedures

### Quarterly Tasks
- [ ] Conduct security assessment
- [ ] Review and update security policies
- [ ] Penetration testing (if required)
- [ ] Compliance audit
- [ ] Review and update incident response plan
- [ ] Team security training

## Security Incident Response

### Detection
1. Monitor Azure Security Center alerts
2. Review Log Analytics queries for suspicious activity
3. Set up automated alerting for security events

### Response Procedure
1. Isolate affected resources
2. Document the incident
3. Investigate root cause
4. Apply remediation
5. Update security controls
6. Conduct post-mortem

### Contact Information
- Security Team: [Add contact]
- Azure Support: [Add support plan details]
- Incident Response Team: [Add contact]

## Compliance Requirements

### Industry Standards
- [ ] CIS Kubernetes Benchmark
- [ ] Azure Security Benchmark
- [ ] NIST Cybersecurity Framework
- [ ] ISO 27001
- [ ] SOC 2
- [ ] [Add your specific requirements]

### Audit Trail
- [ ] All changes logged to audit trail
- [ ] Terraform state changes tracked
- [ ] Change approval process documented
- [ ] Regular compliance reports generated

## Security Tools Integration

### Recommended Tools
- **Static Analysis**: tfsec, Checkov, Terrascan
- **Runtime Security**: Falco, Aqua Security
- **Image Scanning**: Trivy, Clair, Azure Container Registry
- **Policy Management**: Open Policy Agent (OPA), Kyverno
- **Secret Management**: Azure Key Vault, HashiCorp Vault
- **Monitoring**: Prometheus, Grafana, Azure Monitor

### CI/CD Security Gates
```yaml
# Example GitHub Actions security gate
- name: Run tfsec
  run: tfsec . --soft-fail

- name: Run Checkov
  run: checkov -d . --framework terraform

- name: Scan for secrets
  run: gitleaks detect --source . --verbose
```

## References
- [Azure AKS Security Best Practices](https://learn.microsoft.com/azure/aks/security-best-practices)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [Kubernetes Security Documentation](https://kubernetes.io/docs/concepts/security/)
- [Azure Security Baseline for AKS](https://learn.microsoft.com/security/benchmark/azure/baselines/aks-security-baseline)
