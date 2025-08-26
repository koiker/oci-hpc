servername: ${ood_public_dns}
# Use OIDC authentication
auth:
  - "AuthType openid-connect"
  - "Require valid-user"
# Use OIDC logout
logout_redirect: "/oidc?logout=https%3A%2F%2F${ood_public_dns}%2F"
oidc_uri: "/oidc"
oidc_provider_metadata_url: "${IDCS_URL}/.well-known/openid-configuration"
oidc_client_id: "${CLIENT_ID}"
oidc_client_secret: "${CLIENT_SECRET}"
oidc_remote_user_claim: "sub"
oidc_scope: "urn:opc:idm:t.user.me openid email"
oidc_session_inactivity_timeout: 28800
oidc_session_max_duration: 28800
oidc_state_max_number_of_cookies: "10 true"
oidc_settings:
  OIDCPassIDTokenAs: "serialized"
  OIDCPassRefreshToken: "On"
  OIDCPassClaimsAs: "environment"
  OIDCStripCookies: "mod_auth_openidc_session mod_auth_openidc_session_chunks mod_auth_openidc_session_0 mod_auth_openidc_session_1"
  OIDCResponseType: "code"

ssl:
  - 'SSLCertificateFile "/etc/letsencrypt/live/${OOD_DNS}/fullchain.pem"'
  - 'SSLCertificateKeyFile "/etc/letsencrypt/live/${OOD_DNS}/privkey.pem"'