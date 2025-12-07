# Send Email With Attachments On Harness

This is a [script](./send_email_with_attachments.py) that allows you to send an email with attachments from within a step in harness. This is because the native harness plugin does not have room for attachments, at least at the time of writing this.

![harness_email_plugin_sample_usage](https://developer.harness.io/assets/images/email-step-82f4d4984c953cbe3a091057a819dc32.png)

Now, this script has some environment variables that can be used with it.

| VARIABLE | FUNCTION | STATUS |
|:---------|:---------|:-------|
| FROM_EMAIL | The senders valid email | required |
| TO_EMAILS | A list of comma separated emails | required |
| CC_EMAILS | A list of comma separated emails to | not required |
| EMAIL_SUBJECT | Subject of the email | required |
| HARNESS_PIPELINE_ID | ID of the pipeline the script was executed | not required |
| EMAIL_BODY | Custom message body for the email to be sent | *required |
| SMTP_HOST | SMTP domain | *required |
| SMTP_PORT | SMTP port | *required |
| SMTP_USER | SMTP username | *required |
| SMTP_PASS | SMTP password | *required |
| SMTP_TLS | Boolean value to ensure if SMTP connection is done over TLS or not | not required |
| ATTACHMENT_PATTERN | This tells the script for specific file formats to look for | required |
