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
        $env:GITHUB_OUTPUT = New-TemporaryFile
        $env:MOCK_API = $script:MockApiUrl
    }
	
    AfterEach {
        if (Test-Path $env:GITHUB_OUTPUT) { Remove-Item $env:GITHUB_OUTPUT }
        Remove-Item Env:MOCK_API -ErrorAction SilentlyContinue
    }

	Context "Success Cases" {
	    It "unit: Add-IssueAssignee succeeds with HTTP 201" {
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

	    It "unit: Add-IssueAssignee succeeds when user is already assigned" {
	        Mock Invoke-WebRequest {
	            [PSCustomObject]@{ StatusCode = 200; Content = '{"assignees": [{"login": "test-user"}]}' }
	        }
	
	        Add-IssueAssignee -IssueNumber $IssueNumber -Assignee $Assignee -Token $Token -Owner $Owner -RepoName $RepoName
	        $output = Get-Content $env:GITHUB_OUTPUT
	        $output | Should -Contain "result=success"
	    }		
	}

	Context "HTTP Failure Cases" {
	    It "unit: Add-IssueAssignee fails to fetch issue with HTTP 404" {
	        Mock Invoke-WebRequest {
	            [PSCustomObject]@{ StatusCode = 404; Content = '{"message": "Issue not found"}' }
	        }
	
	        Add-IssueAssignee -IssueNumber $IssueNumber -Assignee $Assignee -Token $Token -Owner $Owner -RepoName $RepoName
	        $output = Get-Content $env:GITHUB_OUTPUT
	        $output | Should -Contain "result=failure"
	        $output | Should -Contain "error-message=Error: Failed to fetch issue details. Status: 404"
	    }
	
	    It "unit: Add-IssueAssignee fails to assign issue with HTTP 403" {
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
	        $output | Should -Contain "error-message=Error: Failed to assign issue to test-user. Status: 403"
	    }	
	}

	Context "Parameter Validation Failure Cases" {
		It "unit: Add-IssueAssignee fails with empty IssueNumber" {
	        Add-IssueAssignee -IssueNumber "" -Assignee $Assignee -Token $Token -Owner $Owner -RepoName $RepoName
	        $output = Get-Content $env:GITHUB_OUTPUT
	        $output | Should -Contain "result=failure"
	        $output | Should -Contain "error-message=Missing required parameters: issue_number, assignee, repo_name, owner, and token must be provided."
	    }
	
	    It "unit: Add-IssueAssignee fails with empty Assignee" {
	        Add-IssueAssignee -IssueNumber $IssueNumber -Assignee "" -Token $Token -Owner $Owner -RepoName $RepoName
	        $output = Get-Content $env:GITHUB_OUTPUT
	        $output | Should -Contain "result=failure"
	        $output | Should -Contain "error-message=Missing required parameters: issue_number, assignee, repo_name, owner, and token must be provided."
	    }
	
	    It "unit: Add-IssueAssignee fails with empty Token" {
	        Add-IssueAssignee -IssueNumber $IssueNumber -Assignee $Assignee -Token "" -Owner $Owner -RepoName $RepoName
	        $output = Get-Content $env:GITHUB_OUTPUT
	        $output | Should -Contain "result=failure"
	        $output | Should -Contain "error-message=Missing required parameters: issue_number, assignee, repo_name, owner, and token must be provided."
	    }
	
	    It "unit: Add-IssueAssignee fails with empty Owner" {
	        Add-IssueAssignee -IssueNumber $IssueNumber -Assignee $Assignee -Token $Token -Owner "" -RepoName $RepoName
	        $output = Get-Content $env:GITHUB_OUTPUT
	        $output | Should -Contain "result=failure"
	        $output | Should -Contain "error-message=Missing required parameters: issue_number, assignee, repo_name, owner, and token must be provided."
	    }
	
	    It "unit: Add-IssueAssignee fails with empty RepoName" {
	        Add-IssueAssignee -IssueNumber $IssueNumber -Assignee $Assignee -Token $Token -Owner $Owner -RepoName ""
	        $output = Get-Content $env:GITHUB_OUTPUT
	        $output | Should -Contain "result=failure"
	        $output | Should -Contain "error-message=Missing required parameters: issue_number, assignee, repo_name, owner, and token must be provided."
	    }
	}

	Context "Exception Failure Cases" {
		It "unit: Add-IssueAssignee fails with GET exception" {
			Mock Invoke-WebRequest { throw "API Error" }
	
			Add-IssueAssignee -IssueNumber $IssueNumber -Assignee $Assignee -Token $Token -Owner $Owner -RepoName $RepoName
	
			$output = Get-Content $env:GITHUB_OUTPUT
			$output | Should -Contain "result=failure"
	
			$output |
				Where-Object { $_ -match "^error-message=Error: Failed to fetch issue details\. Exception:" } |
				Should -Not -BeNullOrEmpty
		}
		
		It "unit: Add-IssueAssignee fails with POST exception" {
			$script:called = 0
			Mock Invoke-WebRequest {
				$script:called++
				if ($script:called -eq 1) {
					# GET issue details succeeds
					[PSCustomObject]@{ StatusCode = 200; Content = '{"assignees": []}' }
				} else {
					# POST assign throws
					throw "API Error"
				}
			}
	
			Add-IssueAssignee -IssueNumber $IssueNumber -Assignee $Assignee -Token $Token -Owner $Owner -RepoName $RepoName
	
			$output = Get-Content $env:GITHUB_OUTPUT
			$output | Should -Contain "result=failure"
			$output | Where-Object { $_ -match "^error-message=Error: Failed to assign issue to $Assignee\. Exception:" } |
				Should -Not -BeNullOrEmpty
		}
	}
}
