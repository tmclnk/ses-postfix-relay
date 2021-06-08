################################################################################
# Postfix relay for SES Email
# https://docs.aws.amazon.com/ses/latest/DeveloperGuide/postfix.html
################################################################################
# Use debian because Centos 2021 EOL and future unknowns
FROM debian:bullseye-slim

# If the AWS Region of your SES host isn't in the region
# as the current AWS environment, then set AWS_REGION_OVERRIDE
# at buildtime or at runtime. If unspecified, postfix will
# be configured with the region obtained from "aws configure".
ARG AWS_REGION_OVERRIDE
ENV AWS_REGION_OVERRIDE=${AWS_REGION_OVERRIDE}

# Allow the SSM parameter names to be overridden
ARG SES_USERNAME_PARAM=/ses-relay/smtpusername
ENV SES_USERNAME_PARAM=${SES_USERNAME_PARAM}

ARG SES_PASSWORD_PARAM=/ses-relay/smtppassword
ENV SES_PASSWORD_PARAM=${SES_PASSWORD_PARAM}

# Networks we're allowing to connect. 
# CIDRs separated by spaces. Default to localhosty and docker-y
# address ranges. Your container orchestration system may assign
# other network ranges, so be sure to override at Docker build
# time or runtime.
ARG MYNETWORKS="127.0.0.0/8 172.0.0.0/8 192.0.0.0/8"
ENV MYNETWORKS=${MYNETWORKS}

# libsasl2-modules: to connect to SES
# rsyslog: because postfix wants to write to a syslog
# curl and unzip: to unzip the cli package
RUN apt-get update && \
DEBIAN_FRONTEND=noninteractive apt-get -yq install \
postfix libsasl2-modules rsyslog \
curl unzip

ADD ./helo_access /root/helo_access

# Disable kernel logging support in rsyslog
RUN sed -i '/module(load="imklog")/d' /etc/rsyslog.conf

# We need aws-cli to look up credentials
RUN curl https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o /root/awscliv2.zip && cd /root && unzip awscliv2.zip && ./aws/install && rm /root/awscliv2.zip

ADD ./startup.sh /usr/local/bin/startup.sh

ENTRYPOINT exec startup.sh

EXPOSE 25
