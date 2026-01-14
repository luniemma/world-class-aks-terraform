
auto_scaler_profile = {
  balance_similar_node_groups      = true
  max_graceful_termination_sec     = 600
  scale_down_delay_after_add       = "10m"
  scale_down_unneeded              = "10m"
  scale_down_utilization_threshold = 0.5
  scan_interval                    = "10s"
  skip_nodes_with_local_storage    = false
}

# ===================
# Tags
# ===================

tags = {
  Environment = "dev"
  ManagedBy   = "Terraform"
  Project     = "AKS-Terraform"
  CostCenter  = "Engineering"
  Owner       = "Platform-Team"
}

# ===================
# Cost Optimization (Dev-specific)
# ===================

# Enable automatic stop/start for dev (requires additional configuration)
# auto_stop_enabled = true
# auto_stop_schedule = "0 20 * * 1-5"  # Stop at 8 PM on weekdays
# auto_start_schedule = "0 8 * * 1-5"  # Start at 8 AM on weekdays
