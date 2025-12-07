#!/usr/bin/env python3
"""
GitHub Enterprise Repository Folder Change Checker

This script checks if there are any changes in a specific folder of a GitHub Enterprise
repository on a specified branch since a given time period, and optionally sends
notifications to Microsoft Teams via webhook.
"""

import os
import sys
from datetime import datetime, timedelta
from typing import Dict, List, Any
import argparse
import json
from github import Github, Auth, GithubException
import requests


class RepoChecker:
    """Check for changes in a specific folder of a GitHub Enterprise repository."""
    
    def __init__(
        self,
        repo_owner: str,
        repo_name: str,
        folder_path: str,
        branch: str,
        base_url: str
    ):
        """
        Initialize the GitHub folder checker.
        
        Args:
            repo_owner: GitHub repository owner/organization
            repo_name: Repository name
            folder_path: Path to the folder to monitor (e.g., 'src/components')
            branch: Branch to check
            base_url: Base URL for GitHub Enterprise
        """
        self.repo_owner = repo_owner
        self.repo_name = repo_name
        self.folder_path = folder_path.strip('/') if folder_path else ""
        self.branch = branch
        self.base_url = base_url
        self.github = None
        self.repo = None
        
        self._connect()
        
    def _connect(self) -> None:
        """Establish connection to GitHub Enterprise API."""
        try:
            github_token = os.environ.get("GITHUB_TOKEN")
            
            if not github_token:
                print("Error: GITHUB_TOKEN environment variable not set")
                print("  Set token with: export GITHUB_TOKEN=your_token_here")
                raise ValueError("GITHUB_TOKEN environment variable is required")
            
            auth = Auth.Token(github_token)
            self.github = Github(base_url=self.base_url, auth=auth)
            print(f"Connected to {self.base_url}")
            
            repo_full_name = f"{self.repo_owner}/{self.repo_name}"
            self.repo = self.github.get_repo(repo_full_name)
            print(f"Found {self.repo.full_name}")
            
        except ValueError as e:
            print(f"Configuration error: {e}")
            raise
        except GithubException as e:
            print(f"GitHub API error during connection: {e.status} - {e.data.get('message', str(e))}")
            raise
        except Exception as e:
            print(f"Unexpected error connecting to GitHub: {e}")
            raise
    
    def check_branch_exists(self) -> bool:
        """
        Check if the specified branch exists in the repository.
        
        Returns:
            True if branch exists, False otherwise
        """
        try:
            self.repo.get_branch(self.branch)
            print(f"Branch '{self.branch}' exists.")
            return True
            
        except GithubException as e:
            if e.status == 404:
                print(f"Branch '{self.branch}' NOT FOUND.")
                return False
            else:
                print(f"GitHub API error checking branch: {e.status} - {e.data.get('message', str(e))}")
                return False
        except Exception as e:
            print(f"Unexpected error checking branch: {e}")
            return False
    
    def get_commits(
        self,
        since: datetime,
        until: datetime,
        verbose: bool = False
    ) -> List[Any]:
        """
        Get commits for the specified folder and branch.
        
        Args:
            since: Only commits after this date
            until: Only commits before this date
            verbose: Print detailed debug information
            
        Returns:
            List of commit objects
        """
        try:
            if verbose:
                print(f"\n Debug Info:")
                print(f"  Folder path: '{self.folder_path}'")
                print(f"  Branch: {self.branch}")
                print(f"  Since: {since.strftime('%Y-%m-%d %H:%M:%S')} UTC")
                print(f"  Until: {until.strftime('%Y-%m-%d %H:%M:%S')} UTC")
            
            print(f"Fetching commits for folder: {self.folder_path if self.folder_path else '(entire repo)'}")
            
            if self.folder_path:
                commits = self.repo.get_commits(
                    sha=self.branch,
                    path=self.folder_path,
                    since=since,
                    until=until
                )
            else:
                commits = self.repo.get_commits(
                    sha=self.branch,
                    since=since,
                    until=until
                )
            
            commit_list = list(commits)
            print(f"Retrieved {len(commit_list)} commit(s)")
            
            if verbose and len(commit_list) == 0:
                print("\nNo commits found. This could mean:")
                print("  1. The folder path is incorrect")
                print("  2. No changes were made in the specified time period")
                print("  3. The folder exists but had no commits in this timeframe")
                
            return commit_list
            
        except GithubException as e:
            print(f"GitHub API error fetching commits: {e.status} - {e.data.get('message', str(e))}")
            if verbose:
                print(f"  Full error: {e}")
            return []
        except Exception as e:
            print(f"Unexpected error fetching commits: {e}")
            if verbose:
                import traceback
                print(f"  Traceback:\n{traceback.format_exc()}")
            return []
    
    def check_for_changes(self, verbose: bool, hours: int) -> Dict[str, Any]:
        """
        Check if there are any changes in the folder within the specified time period.
        
        Args:
            verbose: Print detailed commit information
            hours: Number of hours to look back
            
        Returns:
            Dictionary with results including 'has_changes', 'commit_count', and 'commits'
        """
        try:
            since = datetime.utcnow() - timedelta(hours=hours)
            until = datetime.utcnow()
            
            print(f"\n{'='*60}")
            print(f"Checking for changes in: {self.repo_owner}/{self.repo_name}")
            print(f"Folder: {self.folder_path}/")
            print(f"Branch: {self.branch}")
            print(f"Time period: Last {hours} hours")
            print(f"{'='*60}\n")
            
            if not self.check_branch_exists():
                return {
                    "has_changes": False,
                    "commit_count": 0,
                    "commits": [],
                    "error": "Branch not found"
                }
            
            commits = self.get_commits(since=since, until=until, verbose=verbose)
            
            result = {
                "has_changes": len(commits) > 0,
                "commit_count": len(commits),
                "commits": commits,
                "folder_path": self.folder_path,
                "branch": self.branch,
                "time_period_hours": hours
            }
            
            print(f"\n{'='*60}")
            if result["has_changes"]:
                print(f"Changes Detected: {result['commit_count']} commit(s) found.")
            else:
                print(f"No Changes: Folder has not been modified")
            print(f"{'='*60}\n")
            
            if verbose and commits:
                print("Recent commits:")
                for i, commit in enumerate(commits, 1):
                    try:
                        sha = commit.sha[:7]
                        author = commit.commit.author.name
                        date = commit.commit.author.date.strftime('%Y-%m-%d %H:%M:%S')
                        message = commit.commit.message.split('\n')[0]
                        
                        print(f"\n{i}. {sha} - {author}")
                        print(f"   Date: {date}")
                        print(f"   Message: {message}")
                        
                        try:
                            files = commit.files
                            if files:
                                print(f"   Modified files:")
                                for file in files:
                                    status = file.status
                                    filename = file.filename
                                    print(f"     [{status}] {filename}")
                            else:
                                print(f"   No file information available")
                        except Exception as file_error:
                            print(f"   ✗ Error fetching files: {file_error}")
                            
                    except Exception as e:
                        print(f"   ✗ Error parsing commit {i}: {e}")
            
            return result
            
        except Exception as e:
            print(f"Unexpected error in check_for_changes: {e}")
            return {
                "has_changes": False,
                "commit_count": 0,
                "commits": [],
                "error": str(e)
            }
    
    def send_teams_notification(
        self,
        webhook_url: str,
        result: Dict[str, Any],
        verbose: bool = False
    ) -> bool:
        """
        Send a notification to Microsoft Teams via webhook.
        
        Args:
            webhook_url: Microsoft Teams webhook URL
            result: The result dictionary from check_for_changes()
            verbose: Print detailed information
            
        Returns:
            True if notification sent successfully, False otherwise
        """
        try:
            if not result.get("has_changes"):
                if verbose:
                    print("\n📧 No changes to report, skipping Teams notification")
                return True
            
            print(f"\n📧 Sending notification to Teams...")
            
            # unset CA bundle for Teams webhook request
            # this was casuing errors sending notifications to teams, if unset.
            if 'REQUESTS_CA_BUNDLE' in os.environ:
                del os.environ['REQUESTS_CA_BUNDLE']
                if verbose:
                    print("  Removed REQUESTS_CA_BUNDLE for Teams webhook")
            
            commits = result.get("commits", [])
            commit_count = result.get("commit_count", 0)
            folder_path = result.get("folder_path", "")
            branch = result.get("branch", "")
            hours = result.get("time_period_hours", 0)
            
            # show days if 24+ hours
            if hours >= 24:
                days = hours // 24
                remaining_hours = hours % 24
                if remaining_hours > 0:
                    time_period_str = f"{days} day{'s' if days > 1 else ''}, {remaining_hours} hour{'s' if remaining_hours > 1 else ''}"
                else:
                    time_period_str = f"{days} day{'s' if days > 1 else ''}"
            else:
                time_period_str = f"{hours} hour{'s' if hours > 1 else ''}"
            
            sections = []
            for i, commit in enumerate(commits[:10], 1):
                try:
                    sha = commit.sha[:7]
                    author = commit.commit.author.name
                    date = commit.commit.author.date.strftime('%Y-%m-%d %H:%M:%S')
                    message = commit.commit.message.split('\n')[0]
                    
                    # this is how I get the modified files
                    files_text = ""
                    try:
                        files = commit.files
                        if files:
                            file_list = []
                            for file in files[:5]:
                                status_emoji = {
                                    "added": "➕",
                                    "modified": "✏️",
                                    "removed": "❌",
                                    "renamed": "📝"
                                }.get(file.status, "📄")
                                file_list.append(f"{status_emoji} {file.filename}")
                            
                            if len(files) > 5:
                                file_list.append(f"... and {len(files) - 5} more files")
                            
                            files_text = "\n\n**Modified files:**\n" + "\n".join(file_list)
                    except Exception:
                        files_text = ""
                    
                    section = {
                        "activityTitle": f"**{i}. Commit {sha}** by {author}",
                        "activitySubtitle": date,
                        "text": f"{message}{files_text}"
                    }
                    sections.append(section)
                    
                except Exception as e:
                    if verbose:
                        print(f"  ⚠ Error processing commit {i} for Teams: {e}")
                    continue
            
            if commit_count > 10:
                sections.append({
                    "text": f"_... and {commit_count - 10} more commits_"
                })
            
            payload = {
                "@type": "MessageCard",
                "@context": "https://schema.org/extensions",
                "summary": f"Changes detected in {self.repo_name}",
                "themeColor": "0078D4",
                "sections": [
                    {
                        "text": f"<div style='background-color:#0078D4; padding:20px; text-align:center;'><span style='color:white; font-size:24px; font-weight:bold;'>CHANGES DETECTED IN {self.repo_owner.upper()}/{self.repo_name.upper()}</span></div>"
                    },
                    {
                        "activityTitle": "Repository Update",
                        "facts": [
                            {"name": "Folder:", "value": folder_path or "(entire repo)"},
                            {"name": "Branch:", "value": branch},
                            {"name": "Time Period:", "value": f"Last {time_period_str}"},
                            {"name": "Commits Found:", "value": str(commit_count)}
                        ]
                    }
                ] + sections,
                "potentialAction": [
                    {
                        "@type": "OpenUri",
                        "name": "View Repository",
                        "targets": [
                            {
                                "os": "default",
                                "uri": f"{self.base_url.replace('/api/v3', '')}/{self.repo_owner}/{self.repo_name}"
                            }
                        ]
                    }
                ]
            }
            
            response = requests.post(
                webhook_url,
                headers={"Content-Type": "application/json"},
                data=json.dumps(payload),
                timeout=10
            )
            
            response.raise_for_status()
            print("Teams notification sent successfully")
            
            if verbose:
                print(f"  Response status: {response.status_code}")
            
            return True
            
        except requests.exceptions.RequestException as e:
            print(f"Error sending Teams notification: {e}")
            if verbose and hasattr(e, 'response') and e.response is not None:
                print(f"  Response: {e.response.text}")
            return False
        except Exception as e:
            print(f"Unexpected error sending Teams notification: {e}")
            return False
    
    def close(self) -> None:
        """Close the GitHub connection."""
        try:
            if self.github:
                self.github.close()
                print("\nGitHub connection closed.")
        except Exception as e:
            print(f"\nError closing GitHub connection: {e}")


def main():
    """Main function to run the script from command line."""
    parser = argparse.ArgumentParser(
        description="Check for changes in a specific folder of a GitHub Repo"
    )
    parser.add_argument("--verbose", action="store_true", help="Print detailed commit information")
    
    args = parser.parse_args()
    
    repo_owner = os.environ.get("REPO_OWNER", "tuyojr")
    repo_name = os.environ.get("REPO_NAME", "interview_questions")
    folder_path = os.environ.get("FOLDER_PATH", ".harness")
    branch = os.environ.get("BRANCH", "main")
    base_url = os.environ.get("BASE_URL", "https://api.github.com/api/v3")
    hours_str = os.environ.get("CHECK_HOURS", "720")
    teams_webhook_url = os.environ.get("TEAMS_WEBHOOK_URL")
    
    missing_vars = []
    if not repo_name:
        missing_vars.append("REPO_NAME")
    if not hours_str:
        missing_vars.append("CHECK_HOURS")
    
    if missing_vars:
        print("Some required environment variables are not set:")
        for var in missing_vars:
            print(f"  - {var}")
        sys.exit(1)
    
    try:
        hours = int(hours_str)
    except ValueError:
        print(f"Error: CHECK_HOURS must be a valid integer, got: {hours_str}")
        sys.exit(1)
    
    checker = None
    
    try:
        checker = RepoChecker(
            repo_owner=repo_owner,
            repo_name=repo_name,
            folder_path=folder_path,
            base_url=base_url,
            branch=branch,
        )
        
        result = checker.check_for_changes(hours=hours, verbose=args.verbose)
        
        if teams_webhook_url and result.get("has_changes"):
            checker.send_teams_notification(
                webhook_url=teams_webhook_url,
                result=result,
                verbose=args.verbose
            )
        
        if result.get("error"):
            sys.exit(1)
        elif result["has_changes"]:
            sys.exit(0)
        else:
            sys.exit(0)
            
    except KeyboardInterrupt:
        print("Interrupted by user.")
        sys.exit(130)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)
    finally:
        if checker:
            checker.close()


if __name__ == "__main__":
    main()