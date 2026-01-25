function Add-IssueAssignee {
    param(
        [string]$IssueNumber,
        [string]$Assignee,
        [string]$Token,
        [string]$Owner,
        [string]$RepoName
    )

    # Validate required inputs
    if ([string]::IsNullOrEmpty($IssueNumber) -or
        [string]::IsNullOrEmpty($Assignee) -or
        [string]::IsNullOrEmpty($RepoName) -or
        [string]::IsNullOrEmpty($Token) -or
        [string]::IsNullOrEmpty($Owner)) {
        Write-Host "Error: Missing required parameters"
        Add-Content -Path $env:GITHUB_OUTPUT -Value "error-message=Missing required parameters: issue_number, assignee, repo_name, owner, and token must be provided."
        Add-Content -Path $env:GITHUB_OUTPUT -Value "result=failure"
        return
    }
    
    Write-Host "Debug: Checking assignees for issue #$IssueNumber"

    # Use MOCK_API if set, otherwise default to GitHub API
    $apiBaseUrl = $env:MOCK_API
    if (-not $apiBaseUrl) { $apiBaseUrl = "https://api.github.com" }
    
    # Fetch current assignees
    $issueUri = "$apiBaseUrl/repos/$Owner/$RepoName/issues/$IssueNumber"
    $headers = @{
        Authorization  = "Bearer $Token"
        Accept         = "application/vnd.github.v3+json"
        "Content-Type" = "application/json"
        "User-Agent"   = "pwsh-action"
    }

    try {
        $issueResponse = Invoke-WebRequest -Uri $issueUri -Headers $headers -Method Get
		
	    if ($issueResponse.StatusCode -ne 200) {
			Add-Content -Path $env:GITHUB_OUTPUT -Value "result=failure"
			Add-Content -Path $env:GITHUB_OUTPUT -Value "error-message=Failed to fetch issue details. Status: $($issueResponse.StatusCode)"
			Write-Host "Error: Failed to fetch issue details. Status: $($issueResponse.StatusCode)"
			return
		}
    } catch {
        $httpStatus = $_.Exception.Response.StatusCode.value__
        Add-Content -Path $env:GITHUB_OUTPUT -Value "result=failure"
        Add-Content -Path $env:GITHUB_OUTPUT -Value "error-message=Failed to fetch issue details. Status: $httpStatus"
        Write-Host "Error: Failed to fetch issue details. Status: $httpStatus"
        return
    }

    # Check if assignee is already assigned
    $json = $issueResponse.Content | ConvertFrom-Json
    $isAssigned = $false
    if ($json.assignees) {
        foreach ($assigned in $json.assignees) {
            if ($assigned.login -eq $Assignee) {
                $isAssigned = $true
                break
            }
        }
    }

    if ($isAssigned) {
        Add-Content -Path $env:GITHUB_OUTPUT -Value "result=success"
        Write-Host "Issue #$IssueNumber is already assigned to $Assignee, skipping assignment"
    } else {
        Write-Host "Assigning issue #$IssueNumber to $Assignee"

        $assignUri = "$apiBaseUrl/repos/$Owner/$RepoName/issues/$IssueNumber/assignees"
        $body = @{ assignees = @($Assignee) } | ConvertTo-Json

        try {
            $assignResp = Invoke-WebRequest -Uri $assignUri -Headers $headers -Method Post -Body $body
			
		    if ($assignResp.StatusCode -ne 201) {
				Add-Content -Path $env:GITHUB_OUTPUT -Value "result=failure"
				Add-Content -Path $env:GITHUB_OUTPUT -Value "error-message=Failed to assign issue to $Assignee. Status: $($assignResp.StatusCode)"
				Write-Host "Error: Failed to assign issue to $Assignee. Status: $($assignResp.StatusCode)"
			} else {
				Add-Content -Path $env:GITHUB_OUTPUT -Value "result=success"
				Write-Host "Successfully assigned issue #$IssueNumber to $Assignee"
			}
        } catch {
            $httpStatus = $_.Exception.Response.StatusCode.value__
            Add-Content -Path $env:GITHUB_OUTPUT -Value "result=failure"
            Add-Content -Path $env:GITHUB_OUTPUT -Value "error-message=Failed to assign issue to $Assignee. Status: $httpStatus"
            Write-Host "Error: Failed to assign issue to $Assignee. Status: $httpStatus"
            return
        }
    }
}