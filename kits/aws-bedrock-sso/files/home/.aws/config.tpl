[sso-session live]
sso_start_url = https://${SSO_SUBDOMAIN}.awsapps.com/start
sso_region = ${SSO_REGION}
sso_registration_scopes = sso:account:access
region = ${SSO_REGION}

[profile sso-live]
sso_session = live
sso_role_name = ${SSO_ROLE_NAME}
sso_account_id = ${SSO_ACCOUNT_ID}
region = ${SSO_REGION}
