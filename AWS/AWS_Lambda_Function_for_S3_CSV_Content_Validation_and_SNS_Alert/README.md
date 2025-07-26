# Objective

Create an AWS Lambda function that is triggered by S3 uploads (put events) of CSV files. The function must validate the contents of each CSV file for specific rules, and send an SNS notification if any file is invalid, with error details.

## Requirements

- Trigger: S3 ObjectCreated:Put events, for a specified bucket and for files with .csv extension.
- Input: Each event may include multiple records.
- Processing: For each file uploaded:
  - Download the CSV from S3.
  - Validate that the CSV:
    - Has a header row containing: user_id, email, signup_date
  - Each row:
    - user_id is non-empty and alphanumeric.
    - email is a valid email address.
    - signup_date is in YYYY-MM-DD format and not in the future.
- SNS Alert:(Bonus)
  - If any validation fails, send an SNS message to a configured topic with:
    - S3 bucket
    - File name
    - Line number and description of first error found
    - If all rows pass, no alert is sent.
- Logging: Log every processed file, including if it was valid or invalid (and reason for failure).
