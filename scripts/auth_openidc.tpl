# Apache auth_openidc.conf
OIDCProviderMetadataURL ${IDCS_URL}/.well-known/openid-configuration
OIDCClientID ${CLIENT_ID}
OIDCClientSecret ${CLIENT_SECRET}
OIDCRedirectURI https://${OOD_DNS}/oidc
OIDCCryptoPassphrase ${CRYPTO_PASSPHRASE}
OIDCScope "urn:opc:idm:t.user.me openid email"