Describe "Add-IssueAssignee" {
    BeforeAll {
        $script:IssueNumber = "1"
        $script:Assignee    = "test-user"
        $script:Token       = "fake-token"
        $script:Owner       = "test-owner"
        $script:RepoName    = "test-repo"
        $script:MockApiUrl  = "http://127.0.0.1:3000"
        . "$PSScriptRoot/../action.ps1"
    }
    BeforeEach {
        $env:GITHUB_OUTPUT = "$PSScriptRoot/github_output.temp"
        if (Test-Path $env:GITHUB_OUTPUT) { Remove-Item $env:GITHUB_OUTPUT }
        $env:MOCK_API = $script:MockApiUrl
    }
    AfterEach {
        if (Test-Path $env:GITHUB_OUTPUT) { Remove-Item $env:GITHUB_OUTPUT }
        Remove-Variable -Name MOCK_API -Scope Global -ErrorAction SilentlyContinue
    }

    It "assign_issue succeeds with HTTP 201" {
        # GET returns no assignees, POST returns created assignee
        Mock Invoke-WebRequest {
            if (-not $global:AssignIssueCallCount) { $global:AssignIssueCallCount = 0 }
            $global:AssignIssueCallCount++
            if ($global:AssignIssueCallCount -eq 1) {
                [PSCustomObject]@{ StatusCode = 200; Content = '{"assignees": []}' }
            } elseif ($global:AssignIssueCallCount -eq 2) {
                [PSCustomObject]@{ StatusCode = 201; Content = '{"assignees": [{"login": "test-user"}]}' }
            }
        } -Verifiable

        Add-IssueAssignee -IssueNumber $IssueNumber -Assignee $Assignee -Token $Token -Owner $Owner -RepoName $RepoName
        $output = Get-Content $env:GITHUB_OUTPUT
        $output | Should -Contain "result=success"
    }

    It "assign_issue succeeds when user is already assigned" {
        Mock Invoke-WebRequest {
            [PSCustomObject]@{ StatusCode = 200; Content = '{"assignees": [{"login": "test-user"}]}' }
        }

        Add-IssueAssignee -IssueNumber $IssueNumber -Assignee $Assignee -Token $Token -Owner $Owner -RepoName $RepoName
        $output = Get-Content $env:GITHUB_OUTPUT
        $output | Should -Contain "result=success"
    }

    It "assign_issue fails to fetch issue with HTTP 404" {
        Mock Invoke-WebRequest {
            [PSCustomObject]@{ StatusCode = 404; Content = '{"message": "Issue not found"}' }
        }

        Add-IssueAssignee -IssueNumber $IssueNumber -Assignee $Assignee -Token $Token -Owner $Owner -RepoName $RepoName
        $output = Get-Content $env:GITHUB_OUTPUT
        $output | Should -Contain "result=failure"
        $output | Should -Contain "error-message=Failed to fetch issue details. Status: 404"
    }

    It "assign_issue fails to assign issue with HTTP 403" {
        $script:called = 0
        Mock Invoke-WebRequest {
            $script:called++
            if ($script:called -eq 1) {
                [PSCustomObject]@{ StatusCode = 200; Content = '{"assignees": []}' }
            } else {
                [PSCustomObject]@{ StatusCode = 403; Content = '{"message": "Forbidden"}' }
            }
        }

        Add-IssueAssignee -IssueNumber $IssueNumber -Assignee $Assignee -Token $Token -Owner $Owner -RepoName $RepoName
        $output = Get-Content $env:GITHUB_OUTPUT
        $output | Should -Contain "result=failure"
        $output | Should -Contain "error-message=Failed to assign issue to test-user. Status: 403"
    }

    It "assign_issue fails with empty issue_number" {
        Add-IssueAssignee -IssueNumber "" -Assignee $Assignee -Token $Token -Owner $Owner -RepoName $RepoName
        $output = Get-Content $env:GITHUB_OUTPUT
        $output | Should -Contain "result=failure"
        $output | Should -Contain "error-message=Missing required parameters: issue_number, assignee, repo_name, owner, and token must be provided."
    }

    It "assign_issue fails with empty assignee" {
        Add-IssueAssignee -IssueNumber $IssueNumber -Assignee "" -Token $Token -Owner $Owner -RepoName $RepoName
        $output = Get-Content $env:GITHUB_OUTPUT
        $output | Should -Contain "result=failure"
        $output | Should -Contain "error-message=Missing required parameters: issue_number, assignee, repo_name, owner, and token must be provided."
    }

    It "assign_issue fails with empty token" {
        Add-IssueAssignee -IssueNumber $IssueNumber -Assignee $Assignee -Token "" -Owner $Owner -RepoName $RepoName
        $output = Get-Content $env:GITHUB_OUTPUT
        $output | Should -Contain "result=failure"
        $output | Should -Contain "error-message=Missing required parameters: issue_number, assignee, repo_name, owner, and token must be provided."
    }

    It "assign_issue fails with empty owner" {
        Add-IssueAssignee -IssueNumber $IssueNumber -Assignee $Assignee -Token $Token -Owner "" -RepoName $RepoName
        $output = Get-Content $env:GITHUB_OUTPUT
        $output | Should -Contain "result=failure"
        $output | Should -Contain "error-message=Missing required parameters: issue_number, assignee, repo_name, owner, and token must be provided."
    }

    It "assign_issue fails with empty repo_name" {
        Add-IssueAssignee -IssueNumber $IssueNumber -Assignee $Assignee -Token $Token -Owner $Owner -RepoName ""
        $output = Get-Content $env:GITHUB_OUTPUT
        $output | Should -Contain "result=failure"
        $output | Should -Contain "error-message=Missing required parameters: issue_number, assignee, repo_name, owner, and token must be provided."
    }
	
	It "writes result=failure and error-message on exception" {
		Mock Invoke-WebRequest { throw "API Error" }

		try {
			Add-IssueAssignee -IssueNumber $IssueNumber -Assignee $Assignee -Token $Token -Owner $Owner -RepoName$RepoName
		} catch {}

		$output = Get-Content $env:GITHUB_OUTPUT
		$output | Should -Contain "result=failure"
		$output | Where-Object { $_ -match "^error-message=Error: Failed to assign issue to test-user. Exception:" } |
			Should -Not -BeNullOrEmpty
	}
}
