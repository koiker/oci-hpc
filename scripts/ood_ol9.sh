#!/bin/bash

# Check if OOD_DNS environment variable exists
if [ -z "${OOD_DNS}" ]; then
    echo "Error: OOD_DNS environment variable is not set. Public IP is required."
    exit 1
fi

if [ -z "${OOD_USERNAME}" ]; then
    echo "Error: OOD_USERNAME environment variable is not set. Username is required."
    exit 1
fi
CRYPTO_PASSPHRASE=$(openssl rand -hex 40)

# Update system and install EPEL repository
sudo dnf update -y
sudo dnf install -y epel-release
# sudo dnf module enable -y ruby:3.1 nodejs:18
sudo dnf module enable -y ruby:3.3 nodejs:20

# Enable CodeReady and Developer Toolset repositories
sudo dnf config-manager --enable ol9_codeready_builder ol9_distro_builder ol9_developer

# Install Open OnDemand
# sudo dnf install -y https://yum.osc.edu/ondemand/3.1/ondemand-release-web-3.1-1.el8.noarch.rpm
sudo dnf install --disablerepo=* -y https://yum.osc.edu/ondemand/4.0/ondemand-release-web-4.0-1.el9.noarch.rpm
sudo dnf install -y rclone
sudo dnf install -y ondemand

# Install Apache OIDC module
sudo dnf install httpd mod_auth_openidc -y
# Required this configuration to work with OL9. Otheriwise you will see errors about curl not downloading the well-known config
sudo setsebool -P httpd_can_network_connect 1
sudo setsebool -P httpd_mod_auth_pam 1
sudo setsebool -P httpd_read_user_content 1
sudo setsebool -P httpd_run_stickshift 1
sudo setsebool -P httpd_setrlimit 1
FILENAME=~/oodpolicy
sudo touch "$FILENAME.te"
cat << EOF > "$$FILENAME.te"

module mycustompolicy 1.0;

require {
	type var_t;
	type rpcbind_var_run_t;
	type httpd_t;
	type pcp_var_run_t;
	type setroubleshoot_var_run_t;
	type irqbalance_var_run_t;
	type fixed_disk_device_t;
	type faillog_t;
	type httpd_tmp_t;
	type udev_var_run_t;
	type user_home_dir_t;
	type configfs_t;
	type lsmd_var_run_t;
	class dir { add_name create getattr write };
	class fifo_file { create getattr ioctl open read setattr unlink write };
	class blk_file getattr;
	class sock_file getattr;
}

#============= httpd_t ==============
allow httpd_t configfs_t:dir getattr;

#!!!! This avc is allowed in the current policy
allow httpd_t faillog_t:dir write;
allow httpd_t fixed_disk_device_t:blk_file getattr;

#!!!! This avc is allowed in the current policy
allow httpd_t httpd_tmp_t:fifo_file create;
allow httpd_t httpd_tmp_t:fifo_file { getattr ioctl open read setattr unlink write };
allow httpd_t irqbalance_var_run_t:sock_file getattr;
allow httpd_t lsmd_var_run_t:sock_file getattr;
allow httpd_t pcp_var_run_t:sock_file getattr;
allow httpd_t rpcbind_var_run_t:sock_file getattr;
allow httpd_t setroubleshoot_var_run_t:sock_file getattr;
allow httpd_t udev_var_run_t:sock_file getattr;
allow httpd_t user_home_dir_t:dir { add_name create };
allow httpd_t var_t:sock_file getattr;
EOF

sudo checkmodule -M -m -o "$FILENAME.mod" "$FILENAME.te"
sudo semodule_package -o "$FILENAME.pp" -m "$FILENAME.mod"
sudo semodule -i "$FILENAME.pp"
sudo systemctl enable httpd

# Configure firewall
sudo firewall-cmd --zone=public --permanent --add-port=80/tcp
sudo firewall-cmd --zone=public --permanent --add-port=443/tcp
sudo firewall-cmd --reload

# Install Python Pyenv dependencies
sudo dnf install git sqlite-devel readline-devel libffi-devel bzip2-devel -y

# Install dependencies required by certbot
sudo dnf install -y augeas-libs  augeas-devel

# Update Pip OL8
# python3 -m pip install --upgrade pip
# Update Pip OL9
python -m ensurepip --upgrade
# Install Certbot
/usr/local/bin/pip3 install certbot

# Stop web server
systemctl stop httpd

# Generate certificate
/usr/local/bin/certbot certonly --standalone --non-interactive --agree-tos -m rafael.koike@oracle.com --cert-name $OOD_DNS -d $OOD_DNS --webroot-path /

# Add certbot renewal to crontab
echo "0 0,12 * * * root /opt/certbot/bin/python -c 'import random; import time; time.sleep(random.random() * 3600)' && sudo certbot renew -q" | sudo tee -a /etc/crontab > /dev/null

# Configure OOD user
sudo adduser -m $OOD_USERNAME


# Create OOD portal config
cat << EOF > /etc/ood/config/ood_portal.yml
---
servername: ${OOD_DNS}
# Use OIDC authentication
auth:
  - "AuthType openid-connect"
  - "Require valid-user"
# Use OIDC logout
logout_redirect: "/oidc?logout=https%3A%2F%2F${OOD_DNS}%2F"
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
EOF

# Create Apache OIDC config
cat << EOF > /etc/httpd/conf.d/auth_openidc.conf
# Apache auth_openidc.conf
OIDCProviderMetadataURL ${IDCS_URL}/.well-known/openid-configuration
OIDCClientID ${CLIENT_ID}
OIDCClientSecret ${CLIENT_SECRET}
OIDCRedirectURI https://${OOD_DNS}/oidc
OIDCCryptoPassphrase ${CRYPTO_PASSPHRASE}
OIDCScope "urn:opc:idm:t.user.me openid email"
EOF

# Update Apache config based on ood_portal.yml file
/opt/ood/ood-portal-generator/sbin/update_ood_portal

# Restart Apache service
sudo systemctl restart httpd