#!/bin/bash
assign_issue() {
  local issue_number="$1"
  local assignee="$2"
  local token="$3"
  local owner="$4"
  local repo_name="$5"

  # Validate required inputs
  if [ -z "$issue_number" ] || [ -z "$assignee" ] || [ -z "$repo_name" ] || [ -z "$token" ] || [ -z "$owner" ]; then
    echo "Error: Missing required parameters" >&2
    echo "error-message=Missing required parameters: issue_number, assignee, repo_name, owner, and token must be provided." >> "$GITHUB_OUTPUT"
    echo "result=failure" >> "$GITHUB_OUTPUT"
    return 0
  fi
  
  echo "Debug: Checking assignees for issue #$issue_number"

  # Use MOCK_API if set, otherwise default to GitHub API
  local api_base_url="${MOCK_API:-https://api.github.com}"
  
  # Fetch current assignees
  RESPONSE=$(curl -s -o response.json -w "%{http_code}" \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Content-Type: application/json" \
    "$api_base_url/repos/$owner/$repo_name/issues/$issue_number")

  if [[ "$RESPONSE" != "200" ]]; then
    echo "result=failure" >> "$GITHUB_OUTPUT"
    echo "error-message=Failed to fetch issue details. Status: $RESPONSE" >> "$GITHUB_OUTPUT"
    echo "Error: Failed to fetch issue details. Status: $RESPONSE"
    return 0
  fi
  
  # Check if commenter is already assigned
  IS_ASSIGNED=$(jq -r --arg assignee "$assignee" '.assignees[]?.login | select(. == $assignee)' response.json)
      
  if [[ -n "$IS_ASSIGNED" ]]; then
    echo "result=success" >> "$GITHUB_OUTPUT"
    echo "Debug: Issue #$issue_number is already assigned to $assignee, skipping assignment"
  else
    echo "Debug: Assigning issue #$issue_number to $assignee"
    
    ASSIGN_RESPONSE=$(curl -s -o assign_response.json -w "%{http_code}" \
      -X POST \
      -H "Authorization: Bearer $token" \
      -H "Accept: application/vnd.github.v3+json" \
      -H "Content-Type: application/json" \
      "$api_base_url/repos/$owner/$repo_name/issues/$issue_number/assignees" \
      -d "{\"assignees\": [\"$assignee\"]}")
        
    if [[ "$ASSIGN_RESPONSE" != "201" ]]; then
      echo "result=failure" >> "$GITHUB_OUTPUT"
      echo "error-message=Failed to assign issue to $assignee. Status: $ASSIGN_RESPONSE" >> "$GITHUB_OUTPUT"
      echo "Error: Failed to assign issue to $assignee. Status: $ASSIGN_RESPONSE"
    else
      echo "result=success" >> "$GITHUB_OUTPUT"
      echo "Successfully assigned issue #$issue_number to $assignee"
    fi
  fi
}
