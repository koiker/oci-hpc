resource "oci_core_instance" "ood" {
  count               = var.deploy_ood ? 1 : 0
  availability_domain = var.ood_ad == "" ? var.ad : var.ood_ad
  compartment_id      = var.targetCompartment
  display_name        = "${var.cluster_name}-ood"
  shape              = var.ood_shape

  create_vnic_details {
    subnet_id        = local.controller_subnet_id
    assign_public_ip = true
  }

  source_details {
    source_type = "image"
    source_id   = var.use_marketplace_image_ood ? data.oci_core_app_catalog_listing_resource_version.ood_image[0].listing_resource_id : var.custom_ood_image
    boot_volume_size_in_gbs = var.ood_boot_volume_size
  }

  metadata = {
    ssh_authorized_keys = var.ssh_key
  }

  shape_config {
    ocpus         = var.ood_ocpus
    memory_in_gbs = var.ood_memory
  }

  freeform_tags = {
    "cluster_name" = var.cluster_name
    "role"         = "ood"
  }
}

resource "random_string" "random_secret" {
  length           = 32
  special          = false
}

locals {
  ood_public_dns = "ood-${replace(oci_core_instance.ood[0].public_ip, ".", "-")}.nip.io"
}

resource "null_resource" "remote-exec" {
  depends_on = [oci_core_instance.ood, oci_identity_domains_app.ood_app]

  # Provisioner to install and configure Open OnDemand
  provisioner "remote-exec" {

    inline = [
      # Download and install the latest version of Open OnDemand
      "wget https://raw.githubusercontent.com/koiker/oci-hpc/master/scripts/ood.sh",
      "chmod +x ood.sh",
      "sudo OOD_DNS=${local.ood_public_dns} OOD_USERNAME=${var.ood_username} CLIENT_ID=${oci_identity_domains_app.ood_app.name} CLIENT_SECRET=${oci_identity_domains_app.ood_app.client_secret} IDCS_URL=${oci_identity_domain.idcs_domain.url} ./ood.sh",
      "echo 'Customizing UI'",
      "wget https://raw.githubusercontent.com/koiker/oci-hpc/master/scripts/customize_ui.sh",
      "chmod +x customize_ui.sh",
      "sudo ./customize_ui.sh"
    ]

    connection {
      type        = "ssh"
      user        = "opc"
      private_key = file(var.ssh_private_key_path)
      host        = oci_core_instance.ood[0].public_ip
    }
  }
}

# Marketplace image details
data "oci_core_app_catalog_listing_resource_version" "ood_image" {
  count         = var.use_marketplace_image_ood ? 1 : 0
  listing_id    = var.marketplace_listing_id_HPC
  resource_version = var.marketplace_version_id[var.marketplace_listing_ood]
}

output "ood_boostrap_cmd" {
  value = "sudo OOD_DNS=${local.ood_public_dns} OOD_USERNAME=${var.ood_username} CLIENT_ID=${oci_identity_domains_app.ood_app.name} CLIENT_SECRET=${oci_identity_domains_app.ood_app.client_secret} IDCS_URL=${oci_identity_domain.idcs_domain.url} ./ood.sh"
}

output "ood_public_dns" {
  value = local.ood_public_dns
}
# Path: scripts/ood.sh