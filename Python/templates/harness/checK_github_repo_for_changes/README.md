# Check GitHub Repo For Changes

This script, when run, checks a specific github repo (also a folder within the repo), to monitor any changes that have been done in the past 8hours (from the time it runs), so it should ideally be run on a cron schedule. The changes (if any have been found), gets sent to a Microsoft Teams channel via a webhook.

| VARIABLE | FUNCTION | STATUS |
|:---------|:---------|:-------|
| REPO_OWNER | GitHub Enterprise Owner | required |
| REPO_NAME | Name of the GitHub repository | required |
| FOLDER_PATH | Specific folder to check | *not required |
| BRANCH | Specific branch to check | *required |
| BASE_URL | Base url used in forming the complete link to the repository | required |
| GITHUB_TOKEN | Secret token used to connect to GitHub | required |
| CHECK_HOURS | How far back to check for changes (in mins). Default is 720mins | *not required |
| TEAMS_WEBHOOK_URL | Microsoft Teams Webhook to send notifications to | required |

> If the script is run with the --verbose flag, you get a more detailed commit information.
