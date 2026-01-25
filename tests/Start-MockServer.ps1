param(
    [int]$Port = 3000
)

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
$listener.Start()

Write-Host "Mock server listening on http://127.0.0.1:$Port..." -ForegroundColor Green

function GetJsonBody($request) {
    $reader = New-Object System.IO.StreamReader($request.InputStream)
    $body = $reader.ReadToEnd()
    $reader.Close()
    if ($body) {
        try { return $body | ConvertFrom-Json } catch { return $null }
    } else {
        return $null
    }
}

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        $path = $request.Url.LocalPath
        $method = $request.HttpMethod
        
        Write-Host "Mock intercepted: $method $path" -ForegroundColor Cyan

        $responseJson = $null
        $statusCode = 200
        $headers = $request.Headers

        # HealthCheck endpoint: GET /HealthCheck
        if ($method -eq "GET" -and $path -eq "/HealthCheck") {
            $statusCode = 200
            $responseJson = @{ status = "ok" } | ConvertTo-Json
        }
        # GET /repos/:owner/:repo/issues/:issue_number
        elseif (
            $method -eq "GET" -and 
            $path -match '^/repos/([^/]+)/([^/]+)/issues/([^/]+)$'
        ) {
            $owner = $Matches[1]
            $repo = $Matches[2]
            $issueNumber = $Matches[3]
            Write-Host "Request headers: $($headers | Out-String)"

            # Authorization header
            $authHeader = $headers["Authorization"]
            if (-not $authHeader -or -not $authHeader.StartsWith("Bearer ")) {
                $statusCode = 401
                $responseJson = @{ message = "Unauthorized: Missing or invalid Bearer token" } | ConvertTo-Json
            }
            elseif ($owner -eq "test-owner" -and $repo -eq "test-repo" -and $issueNumber -eq "1") {
                $statusCode = 200
                $responseJson = @{ assignees = @() } | ConvertTo-Json
            }
            elseif ($owner -eq "test-owner" -and $repo -eq "test-repo" -and $issueNumber -eq "2") {
                $statusCode = 200
                $responseJson = @{ assignees = @(@{ login = 'test-user' }) } | ConvertTo-Json
            }
            else {
                $statusCode = 404
                $responseJson = @{ message = "Issue not found" } | ConvertTo-Json
            }
        }
        # POST /repos/:owner/:repo/issues/:issue_number/assignees
        elseif (
            $method -eq "POST" -and 
            $path -match '^/repos/([^/]+)/([^/]+)/issues/([^/]+)/assignees$'
        ) {
            $owner = $Matches[1]
            $repo = $Matches[2]
            $issueNumber = $Matches[3]
            $bodyObj = GetJsonBody $request
            Write-Host "Request headers: $($headers | Out-String)"
            Write-Host "Request body: $(if ($bodyObj) { $bodyObj | ConvertTo-Json -Compress } else { '[null]' })"

            $authHeader = $headers["Authorization"]
            if (-not $authHeader -or -not $authHeader.StartsWith("Bearer ")) {
                $statusCode = 401
                $responseJson = @{ message = "Unauthorized: Missing or invalid Bearer token" } | ConvertTo-Json
            }
            elseif (
                $bodyObj -and
                $bodyObj.assignees -and
                $bodyObj.assignees.Count -gt 0 -and
                $owner -eq "test-owner" -and
                $repo -eq "test-repo" -and
                $issueNumber -eq "1"
            ) {
                $statusCode = 201
                $responseJson = @{ assignees = @(@{ login = $bodyObj.assignees[0] }) } | ConvertTo-Json
            }
            else {
                $statusCode = 403
                $responseJson = @{ message = "Forbidden" } | ConvertTo-Json
            }
        }
        else {
            $statusCode = 404
            $responseJson = @{ message = "Not Found" } | ConvertTo-Json
        }
        
        # Send response
        $response.StatusCode = $statusCode
        $response.ContentType = "application/json"
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseJson)
        $response.ContentLength64 = $buffer.Length
        $response.OutputStream.Write($buffer, 0, $buffer.Length)
        $response.Close()
    }
}
finally {
    $listener.Stop()
    $listener.Close()
    Write-Host "Mock server stopped." -ForegroundColor Yellow
}