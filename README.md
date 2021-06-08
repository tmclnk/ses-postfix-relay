# SES Postfix Relay
A rather bloated Docker image containing a Postfix installation which
will forward SMTP requests to Amazon [SES](https://aws.amazon.com/ses/).
This allows you to use plain SMTP wired to SES over port 25.

Requires two params to be specified in SES.

* `/ses-relay/smtpusername` # unencrypted
* `/ses-relay/smtppassword` # encrypted

For information about credentials, see [Obtaining your Amazon SES SMTP Credentials](https://docs.aws.amazon.com/ses/latest/DeveloperGuide/smtp-credentials.html).

## Environment Variables 
|ENV Var|Value|
|-|-|
|SES_USERNAME_PARAM| Key in SSM of username parameter in ses, defaults to `/ses-relay/smtpusername` |
|SES_PASSWORD_PARAM| Key in SSM of password parameter in ses, defaults to `/ses-relay/smtppassword` |
|AWS_REGION_OVERRIDE| An AWS Region. Defaults to whatever region is configured with your AWS configuration. |
|MYNETWORKS| Networks from which we will accept messages. CIDRs separated by spaces. This will usually be the docker network itself, but you may want to open it up to the VPC. Is passed as-is postfix [mynetworks](http://www.postfix.org/postconf.5.html#mynetworks). See the [Dockerfile](./Dockerfile) for the defaults. |

If you wish, you can pack default values into the above by overriding them as 
[ARG](https://docs.docker.com/engine/reference/builder/#arg) at build time. 
You must AWS credentials available in any of the usual ways. This may
involve specifying environment variables `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_DEFAULT_REGION`
(not recommended), mounting `.aws/credentials` and `.aws/config` into `/root/.aws`, 
AWS Instance Roles, etc.

## helo_access
In addition to `MYNETWORKS`, you will need to specify the hosts from 
which you accept `HELO` messages in [helo_access](./helo_access). You can use POSIX Regular Expressions (PCRE) here if you wish.

See [access(5)](http://www.postfix.org/access.5.html) and [regex_table(5)](http://www.postfix.org/regexp_table.5.html) for details on the HOST NAME patterns allowed here.

## Running
```sh
# run using aws credentials in ~/.aws
docker run -v ~/.aws:/root/.aws --rm -p 25:25 tmclnk/ses-postfix-relay
```

## Testing
You can attach to the container and send a test message. The final line must contain a period with no other content.
```sh
sendmail -f noreply@mydomain.com recipient@example.com
From: MyDomain Notification
Subject: Amazon SES Test                
This message was sent using Amazon SES.                
.
```

## Troubleshooting
```
 Feb 17 17:56:02 ip-10-150-241-58 postfix/smtpd[978]: NOQUEUE: reject: RCPT from localhost[127.0.0.1]: 451 4.3.0 <ip-10-150-241-58.ec2.internal>: Temporary lookup failure; from=<from@example.com> to=<to@example.com> proto=ESMTP helo=<ip-10-150-241-58.ec2.internal>
 ```
 Some things to check:

* is the `RCPT from` address in `MYNETWORKS`
* is the `from=` address permissible in your SES relay
* is the `to=` address permissible in your SES relay
* does the hostname in `helo=` match an entry in [helo_access](./helo_access)

## Related Links
* https://docs.aws.amazon.com/ses/latest/DeveloperGuide/postfix.html
* https://docs.aws.amazon.com/ses/latest/DeveloperGuide/smtp-credentials.html
