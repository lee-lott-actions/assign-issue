# Assign Issue Action

This GitHub Action assigns a GitHub issue to a specified user using the GitHub API. It checks if the user is already assigned to the issue and returns the result of the assignment attempt.

## Features
- Assigns a GitHub issue to a specified user via the GitHub API.
- Checks if the user is already assigned to avoid redundant assignments.
- Outputs the result of the assignment (`success`, `already-assigned`, or `failure`) and an error message if applicable.
- Requires a GitHub token with repository write access for authentication.

## Inputs
| Name          | Description                                      | Required | Default |
|---------------|--------------------------------------------------|----------|---------|
| `issue-number`| The issue number to assign.                     | Yes      | N/A     |
| `assignee`    | The GitHub username to assign the issue to.     | Yes      | N/A     |
| `token`       | GitHub token with repository write access.      | Yes      | N/A     |
| `owner`       | The owner of the organization (user or organization). | Yes | N/A    |
| `repo-name`  | The repository name to which the issue is assigned.    | Yes      | N/A     |

## Outputs
| Name           | Description                                           |
|----------------|-------------------------------------------------------|
| `result`       | Result of the assignment attempt ("success" or "failure"). |
| `error-message`| Error message if the assignment fails.                |

## Usage
1. **Add the Action to Your Workflow**:
   Create or update a workflow file (e.g., `.github/workflows/assign-issue.yml`) in your repository.

2. **Reference the Action**:
   Use the action by referencing the repository and version (e.g., `v1`).

3. **Example Workflow**:
   ```yaml
   name: Assign Issue
   on:
     issues:
       types: [opened]
   jobs:
     assign-issue:
       runs-on: ubuntu-latest
       steps:
         - name: Assign Issue
           id: assign
           uses: la-actions/assign-issue@v1.0.0
           with:
             issue-number: ${{ github.event.issue.number }}
             assignee: 'username'
             token: ${{ secrets.GITHUB_TOKEN }}
             owner: ${{ github.repository_owner }}
             repo-name: ${{ github.event.repository.name }}
         - name: Print Result
           run: |
             case "${{ steps.assign.outputs.result }}" in
               "success")
                 echo "Issue successfully assigned to ${{ inputs.assignee }}."
                 ;;
               "failure")
                 echo "Error: ${{ steps.assign.outputs.error-message }}"
                 exit 1
                 ;;
             esac
