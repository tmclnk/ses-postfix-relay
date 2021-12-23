#!/usr/bin/env sh
################################################################################
# AWS CLI Setup
################################################################################
# Turn of aws-cli pager
export AWS_PAGER=

# Make sure we have AWS credentials
aws sts get-caller-identity || exit 1

# Postfix config files themselves rely on the region, so
# we are going to assume the credentials passed in come
# from the default region, even though that may not
# necessarily be the case if you configured a your mail server
# in a different region.
if [ -z "$AWS_REGION_OVERRIDE" ]; then
    # this isn't guaranteed to work!
    region="$(aws configure get region)"
else 
    region="$AWS_REGION_OVERRIDE"
fi 

# Fail if we still don't have a region.
if [ -n "$region" ]; then
    echo "Configuring relay with region $region..."
else
    >&2 echo "AWS Region not found! Try setting AWS_REGION_OVERRIDE."
    exit 1
fi

################################################################################
# Generate Credentials Database w/SSM Params
################################################################################
SMTPUSERNAME=$(aws ssm get-parameter --name "$SES_USERNAME_PARAM" --query "Parameter.Value" --output text) || exit 1
SMTPPASSWORD=$(aws ssm get-parameter --name "$SES_PASSWORD_PARAM" --with-decryption --query "Parameter.Value" --output text) || exit 1
cat <<EOF > /etc/postfix/sasl_passwd
[email-smtp.$region.amazonaws.com]:587 $SMTPUSERNAME:$SMTPPASSWORD
EOF
postmap hash:/etc/postfix/sasl_passwd
chmod 0600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db

################################################################################
# Hostnames must identify themselves; these are the permitted values.
################################################################################
cp /root/helo_access /etc/postfix/helo_access || exit 1
postmap /etc/postfix/helo_access || exit 1

################################################################################
# Certificate Boilerplate taken from Amazon SES Documentation (Debian Specific)
################################################################################
# See https://www.saic.it/postfix-configuration-for-helo-hostname/ for details
# on alternatives for what we allow on incoming connections. Since this is
# intended as a sidecar, we can control the network environment. Within ECS 
# Tasks you may want to assign hostnames explicitly to containers, then add them
# in the helo_access file. The same goes for docker-compose. If you aren't
# using this as a sidecar, you should consider locking down your postfix
# config even further here.
postconf -e 'smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt' \
"relayhost = [email-smtp.$region.amazonaws.com]:587" \
"mynetworks = $MYNETWORKS" \
"smtp_sasl_auth_enable = yes" \
"smtp_sasl_security_options = noanonymous" \
"smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd" \
"smtp_use_tls = yes" \
"smtp_tls_security_level = encrypt" \
"smtp_tls_note_starttls_offer = yes" \
"smtpd_helo_required = yes" \
"smtpd_helo_restrictions = permit_mynetworks, check_helo_access hash:/etc/postfix/helo_access, permit" 

postconf -e "maillog_file = /dev/stdout" 

# postfix chroot needs resolv.conf for DNS lookups
cat /etc/resolv.conf > /var/spool/postfix/etc/resolv.conf

exec postfix start-fg