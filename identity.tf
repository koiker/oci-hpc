resource "oci_identity_domain" "idcs_domain" {
  compartment_id= var.targetCompartment
  display_name  = var.domain_name
  description   = "IDCS domain for OOD authentication"
  home_region   = "${var.region}"
  license_type  = "premium" # The license type can be "free" or "premium"
}

resource "oci_identity_domains_setting" "idcs_settings" {
  # Optional attributes
  signing_cert_public_access = true
  timezone = "America/New_York"
  # Required attributes
  schemas = ["urn:ietf:params:scim:schemas:oracle:idcs:Settings"]
  setting_id =  "Settings"
  idcs_endpoint = oci_identity_domain.idcs_domain.url
  csr_access = "none"
}

# data "oci_identity_domains_app_roles" "idcs_app_role_signin" {
#   idcs_endpoint = oci_identity_domain.idcs_domain.url
#   app_role_filter = "displayName eq \"Signin\""
# }

resource "oci_identity_domains_app" "ood_app" {
  display_name = "ood"
  description = "Identity Domain application"
  idcs_endpoint = oci_identity_domain.idcs_domain.url
  schemas = ["urn:ietf:params:scim:schemas:oracle:idcs:App"]
  based_on_template {
    value = "CustomWebAppTemplateId"
  }
  active = true
  allowed_grants = ["authorization_code", "client_credentials"]
  client_type = "confidential"
  is_oauth_client = true
  force_delete = true
  show_in_my_apps = true
  client_ip_checking = "anywhere"
  # Dynamically construct redirect URIs using the OOD instance public IP
  redirect_uris = [
    "https://ood-${replace(oci_core_instance.ood[0].public_ip, ".", "-")}.nip.io/oidc"
  ]
  post_logout_redirect_uris = [
    "https://ood-${replace(oci_core_instance.ood[0].public_ip, ".", "-")}.nip.io/"
  ]
}

resource "oci_identity_domains_user" "ood_user" {
  idcs_endpoint = oci_identity_domain.idcs_domain.url
  schemas       = ["urn:ietf:params:scim:schemas:core:2.0:User"]
  user_name     = var.ood_username
  display_name  = var.ood_username
  emails {
    value = var.ood_user_email
    type  = "work"
    primary = true
  }
  name {
    given_name  = var.ood_username
    family_name = var.ood_username
  }
  active = true
}

# Define App Roles for the ood_app
# resource "oci_identity_domains_app_role" "ood_app_role_signin" {
#   app {
#       value = oci_identity_domains_app.ood_app.id
#   }
#   admin_role = true
#   idcs_endpoint = oci_identity_domain.idcs_domain.url
#   schemas      = ["urn:ietf:params:scim:schemas:oracle:idcs:AppRole"]
#   display_name = "Signin"
#   description  = "Role user sign-in"
# }

# resource "oci_identity_domains_app_role" "ood_app_role_id_admin" {
#   app {
#       value = oci_identity_domains_app.ood_app.id
#   }
#   admin_role = true
#   available_to_clients = true
#   idcs_endpoint = oci_identity_domain.idcs_domain.url
#   schemas       = ["urn:ietf:params:scim:schemas:oracle:idcs:AppRole"]
#   display_name  = "Identity Domain Administrator"
#   description   = "Role for managing the identity domain"
# }

# resource "oci_identity_domains_app_role" "ood_app_role_me" {
#   app {
#       value = oci_identity_domains_app.ood_app.id
#   }
#   admin_role = true
#   idcs_endpoint = oci_identity_domain.idcs_domain.url
#   schemas      = ["urn:ietf:params:scim:schemas:oracle:idcs:AppRole"]
#   display_name = "Me"
#   description  = "Role for user-specific actions"

# }

output "ood_url" {
  value = "https://ood-${replace(oci_core_instance.ood[0].public_ip, ".", "-")}.nip.io"
}

output "app_client_id" {
  value = oci_identity_domains_app.ood_app.name
}