#!/usr/bin/env bats

# Load the Bash script containing the assign_issue function
load ../action.sh

# Mock the curl command to simulate API responses
mock_curl() {
  local http_code=$1
  local response_file=$2
  local output_file=$3

  # Ensure the output file is created
  cp "$response_file" "$output_file" || { echo "Error: Failed to copy $response_file to $output_file" >&3; exit 1; }
  # Return the HTTP status code to mimic curl -s -o response.json -w "%{http_code}"
  echo "$http_code"
}

# Mock the jq command to simulate JSON parsing
mock_jq() {
  local field="$1"
  local assignee="$2"
  local file="response.json"
  if [ -f "$file" ] && [ "$field" = '.assignees[]?.login | select(. == $assignee)' ] && [ "$assignee" = "test-user" ]; then
    # Check if response.json contains test-user as an assignee
    if grep -q "\"login\": \"test-user\"" "$file"; then
      echo "test-user"
    else
      echo ""
    fi
  else
    echo ""
  fi
}

# Setup function to run before each test
setup() {
  export GITHUB_OUTPUT=$(mktemp)
  # Ensure mock files are created in the current directory
  touch mock_response.json mock_assign_response.json
}

# Teardown function to clean up after each test
teardown() {
  rm -f response.json assign_response.json mock_response.json mock_assign_response.json "$GITHUB_OUTPUT"
}

@test "assign_issue succeeds with HTTP 201" {
  echo '{"assignees": []}' > mock_response.json
  echo '{"assignees": [{"login": "test-user"}]}' > mock_assign_response.json

  curl() {
    if echo "${*}" | grep -q "/repos/test-owner/test-repo/issues/1$"; then
      mock_curl "200" mock_response.json response.json
    elif echo "${*}" | grep -q "/repos/test-owner/test-repo/issues/1/assignees"; then
      mock_curl "201" mock_assign_response.json assign_response.json
    fi
  }
  export -f curl

  jq() {
    local flag="$1"
    local arg_flag="$2"
    local arg_name="$3"
    local arg_value="$4"
    local query="$5"

     if [ "$flag" = "-r" ] && [ "$arg_flag" = "--arg" ] && [ "$arg_name" = "assignee" ] && [ "$query" = '.assignees[]?.login | select(. == $assignee)' ]; then
      mock_jq "$query" "$arg_value"
    else
      echo "Error: Unexpected jq arguments: $*"
      return 1
    fi
  }
  export -f jq

  run assign_issue "1" "test-user" "fake-token" "test-owner" "test-repo"

  [ "$status" -eq 0 ]
  [ "$(grep 'result' "$GITHUB_OUTPUT")" = "result=success" ]
}

@test "assign_issue succeeds when user is already assigned" {
  echo '{"assignees": [{"login": "test-user"}]}' > mock_response.json

  curl() {
    if echo "${*}" | grep -q "/repos/test-owner/test-repo/issues/1$"; then
      mock_curl "200" mock_response.json response.json
    else
      echo "Error: Unexpected curl call: $*"
      exit 1
    fi
#    echo "DEBUG: curl invoked with: $*"
  }
  export -f curl

  jq() {
    local flag="$1"
    local arg_flag="$2"
    local arg_name="$3"
    local arg_value="$4"
    local query="$5"

    if [ "$flag" = "-r" ] && [ "$arg_flag" = "--arg" ] && [ "$arg_name" = "assignee" ] && [ "$query" = '.assignees[]?.login | select(. == $assignee)' ]; then
      mock_jq "$query" "$arg_value"
    else
      echo "Error: Unexpected jq arguments: $*"
      return 1
    fi
  }
  export -f jq

  run assign_issue "1" "test-user" "fake-token" "test-owner" "test-repo"

  [ "$status" -eq 0 ]
  [ "$(grep 'result' "$GITHUB_OUTPUT")" = "result=success" ]
}

@test "assign_issue fails to fetch issue with HTTP 404" {
  echo '{"message": "Issue not found"}' > mock_response.json

  curl() {
    mock_curl "404" mock_response.json response.json
#    echo "DEBUG: curl invoked with: $*"
  }
  export -f curl

  jq() {
    local flag="$1"
    local arg_flag="$2"
    local arg_name="$3"
    local arg_value="$4"
    local query="$5"

    if [ "$flag" = "-r" ] && [ "$arg_flag" = "--arg" ] && [ "$arg_name" = "assignee" ] && [ "$query" = '.assignees[]?.login | select(. == $assignee)' ]; then
      mock_jq "$query" "$arg_value"
    else
      echo "Error: Unexpected jq arguments: $*"
      return 1
    fi
  }
  export -f jq

  run assign_issue "1" "test-user" "fake-token" "test-owner" "test-repo"

  [ "$status" -eq 0 ]
  [ "$(grep 'result' "$GITHUB_OUTPUT")" = "result=failure" ]
  [ "$(grep 'error-message' "$GITHUB_OUTPUT")" = "error-message=Failed to fetch issue details. Status: 404" ]
}

@test "assign_issue fails to assign issue with HTTP 403" {
  echo '{"assignees": []}' > mock_response.json
  echo '{"message": "Forbidden"}' > mock_assign_response.json

  curl() {
    if echo "${*}" | grep -q "/repos/test-owner/test-repo/issues/1$"; then
      mock_curl "200" mock_response.json response.json
    elif echo "${*}" | grep -q "/repos/test-owner/test-repo/issues/1/assignees"; then
      mock_curl "403" mock_assign_response.json assign_response.json
    fi
  }
  export -f curl

  jq() {
    local flag="$1"
    local arg_flag="$2"
    local arg_name="$3"
    local arg_value="$4"
    local query="$5"

    if [ "$flag" = "-r" ] && [ "$arg_flag" = "--arg" ] && [ "$arg_name" = "assignee" ] && [ "$query" = '.assignees[]?.login | select(. == $assignee)' ]; then
      mock_jq "$query" "$arg_value"
    else
      echo "Error: Unexpected jq arguments: $*"
      return 1
    fi
  }
  export -f jq

  run assign_issue "1" "test-user" "fake-token" "test-owner" "test-repo"

  [ "$status" -eq 0 ]
  [ "$(grep 'result' "$GITHUB_OUTPUT")" = "result=failure" ]
  [ "$(grep 'error-message' "$GITHUB_OUTPUT")" = "error-message=Failed to assign issue to test-user. Status: 403" ]
}

@test "assign_issue fails with empty issue_number" {
  run assign_issue "" "test-user" "fake-token" "test-owner" "test-repo"

  cat "$GITHUB_OUTPUT"

  [ "$status" -eq 0 ]
  [ "$(grep 'result' "$GITHUB_OUTPUT")" = "result=failure" ]
  [ "$(grep 'error-message' "$GITHUB_OUTPUT")" = "error-message=Missing required parameters: issue_number, assignee, repo_name, owner, and token must be provided." ]
}

@test "assign_issue fails with empty assignee" {
  run assign_issue "1" "" "fake-token" "test-owner" "test-repo"

  cat "$GITHUB_OUTPUT"

  [ "$status" -eq 0 ]
  [ "$(grep 'result' "$GITHUB_OUTPUT")" = "result=failure" ]
  [ "$(grep 'error-message' "$GITHUB_OUTPUT")" = "error-message=Missing required parameters: issue_number, assignee, repo_name, owner, and token must be provided." ]
}

@test "assign_issue fails with empty token" {
  run assign_issue "1" "test-user" "" "test-owner" "test-repo"

  cat "$GITHUB_OUTPUT"

  [ "$status" -eq 0 ]
  [ "$(grep 'result' "$GITHUB_OUTPUT")" = "result=failure" ]
  [ "$(grep 'error-message' "$GITHUB_OUTPUT")" = "error-message=Missing required parameters: issue_number, assignee, repo_name, owner, and token must be provided." ]
}

@test "assign_issue fails with empty owner" {
  run assign_issue "1" "test-user" "fake-token" "" "test-repo"

  cat "$GITHUB_OUTPUT"

  [ "$status" -eq 0 ]
  [ "$(grep 'result' "$GITHUB_OUTPUT")" = "result=failure" ]
  [ "$(grep 'error-message' "$GITHUB_OUTPUT")" = "error-message=Missing required parameters: issue_number, assignee, repo_name, owner, and token must be provided." ]
}

@test "assign_issue fails with empty repo_name" {
  run assign_issue "1" "test-user" "fake-token" "test-owner" ""

  cat "$GITHUB_OUTPUT"

  [ "$status" -eq 0 ]
  [ "$(grep 'result' "$GITHUB_OUTPUT")" = "result=failure" ]
  [ "$(grep 'error-message' "$GITHUB_OUTPUT")" = "error-message=Missing required parameters: issue_number, assignee, repo_name, owner, and token must be provided." ]
}
