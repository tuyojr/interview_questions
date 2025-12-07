#!/usr/bin/env python3
"""
Simple Python script to send emails with attachments from Harness pipeline
Uses environment variables from Harness and sends via delegate's SMTP configuration
"""

import os
import smtplib
import glob
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders

def send_email_with_attachments():
    from_email = os.environ.get('FROM_EMAIL', 'noreply@company.com')
    to_emails = [email.strip() for email in os.environ.get('TO_EMAILS', '').split(',') if email.strip()]
    cc_emails = [email.strip() for email in os.environ.get('CC_EMAILS', '').split(',') if email.strip()] if os.environ.get('CC_EMAILS') else []
    subject = os.environ.get('EMAIL_SUBJECT', f'Pipeline Report - {os.environ.get("HARNESS_PIPELINE_ID", "Unknown")}')
    body = os.environ.get('EMAIL_BODY', 'Pipeline execution completed. Please see attached files.')
    
    body = body.replace('\\n', '\n')
    
    smtp_host = os.environ.get('SMTP_HOST', 'localhost')
    smtp_port = int(os.environ.get('SMTP_PORT', '587'))
    smtp_user = os.environ.get('SMTP_USER', '')
    smtp_pass = os.environ.get('SMTP_PASS', '')
    use_tls = os.environ.get('SMTP_TLS', 'true').lower() == 'true'
    
    attachment_pattern = os.environ.get('ATTACHMENT_PATTERN', '*')  # e.g., '*.csv', '*.pdf', '*report*'
    working_dir = os.getcwd()
    
    print(f"Working directory: {working_dir}")
    print(f"From: {from_email}")
    print(f"To: {', '.join(to_emails)}")
    if cc_emails and cc_emails != ['']:
        print(f"CC: {', '.join(cc_emails)}")
    print(f"Subject: {subject}")
    print(f"SMTP Host: {smtp_host}:{smtp_port}")
    
    msg = MIMEMultipart()
    msg['From'] = from_email
    msg['To'] = ', '.join(to_emails)
    if cc_emails and cc_emails != ['']:
        msg['Cc'] = ', '.join(cc_emails)
    msg['Subject'] = subject
    
    msg.attach(MIMEText(body, 'plain'))
    
    attachment_files = glob.glob(attachment_pattern)
    
    if not attachment_files:
        print(f"No files found matching pattern: {attachment_pattern}")
        print("Available files in current directory:")
        for file in os.listdir(working_dir):
            print(f"  - {file}")
    else:
        print(f"Found {len(attachment_files)} attachment(s):")
        
        for file_path in attachment_files:
            if os.path.isfile(file_path):
                file_name = os.path.basename(file_path)
                file_size = os.path.getsize(file_path)
                print(f"{file_name} ({file_size} bytes)")
                
                try:
                    with open(file_path, "rb") as attachment:
                        part = MIMEBase('application', 'octet-stream')
                        part.set_payload(attachment.read())
                    
                    encoders.encode_base64(part)
                    part.add_header(
                        'Content-Disposition',
                        f'attachment; filename= {file_name}'
                    )
                    msg.attach(part)
                    
                except Exception as e:
                    print(f"Failed to attach {file_name}: {e}")
    
    try:
        print(f"\nConnecting to SMTP server...")
        
        if smtp_port == 465:
            server = smtplib.SMTP_SSL(smtp_host, smtp_port)
        else:
            server = smtplib.SMTP(smtp_host, smtp_port)
            if use_tls:
                server.starttls()
        
        if smtp_user and smtp_pass:
            print("Authenticating...")
            server.login(smtp_user, smtp_pass)
        
        all_recipients = to_emails + (cc_emails if cc_emails != [''] else [])
        all_recipients = [email.strip() for email in all_recipients if email.strip()]
        
        print(f"Sending email to {len(all_recipients)} recipient(s)...")
        server.send_message(msg, to_addrs=all_recipients)
        server.quit()
        
        print("Email sent successfully!")
        
    except Exception as e:
        print(f"Failed to send email: {e}")
        exit(1)

def main():
    print("=== Harness Email Sender ===")
    print("Environment variables:")
    
    env_vars = [
        'FROM_EMAIL', 'TO_EMAILS', 'CC_EMAILS', 'EMAIL_SUBJECT', 'EMAIL_BODY',
        'SMTP_HOST', 'SMTP_PORT', 'SMTP_USER', 'SMTP_TLS', 'ATTACHMENT_PATTERN',
        'HARNESS_PIPELINE_ID', 'HARNESS_BUILD_ID', 'HARNESS_STAGE_ID'
    ]
    
    for var in env_vars:
        value = os.environ.get(var, 'Not set')
        if var == 'SMTP_PASS':
            value = '***' if os.environ.get(var) else 'Not set'
        print(f"  {var}: {value}")
    
    print("\n" + "="*50)
    
    send_email_with_attachments()

if __name__ == "__main__":
    main()