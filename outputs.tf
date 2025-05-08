output "controller" {
  value = local.host
}

output "private_ips" {
  value = join(" ", local.cluster_instances_ips)
}

output "backup" {
  value = var.slurm_ha ? local.host_backup : "No Slurm Backup Defined"
}

output "login" {
  value = var.login_node ? local.host_login : "No Login Node Defined"
}

output "monitoring" {
  value = var.monitoring_node ? local.host_monitoring : "No Monitoring Node Defined"
}

output "ood_private_ip" {
  value = var.deploy_ood ? oci_core_instance.ood[0].private_ip : null
}

output "ood_public_ip" {
  value = var.deploy_ood ? oci_core_instance.ood[0].public_ip : null
}

output "idcs_endpoint" {
  value = oci_identity_domain.idcs_domain.url
}

output "openid_configuration_url" {
  value = "${oci_identity_domain.idcs_domain.url}/.well-known/openid-configuration"
}
