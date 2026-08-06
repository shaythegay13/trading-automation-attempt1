param(
    [string]$Root = (Split-Path -Parent $MyInvocation.MyCommand.Path),
    [int]$Port = 8765
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path -LiteralPath $Root).Path
$LogFile = Join-Path $Root 'server.log'
$Prefix = "http://127.0.0.1:$Port/"

function Write-ServerLog {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
}

function Set-CommonHeaders {
    param([System.Net.HttpListenerResponse]$Response)
    try { $Response.Headers['Cache-Control'] = 'no-store' } catch { }
    try { $Response.Headers['Access-Control-Allow-Origin'] = '*' } catch { }
}

function Send-TextResponse {
    param(
        [System.Net.HttpListenerContext]$Context,
        [int]$StatusCode,
        [string]$StatusText,
        [string]$Body,
        [string]$ContentType = 'text/plain; charset=utf-8'
    )
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
    $response = $Context.Response
    $response.StatusCode = $StatusCode
    $response.StatusDescription = $StatusText
    $response.ContentType = $ContentType
    $response.ContentLength64 = $bytes.Length
    Set-CommonHeaders $response
    if ($Context.Request.HttpMethod -ne 'HEAD') {
        $response.OutputStream.Write($bytes, 0, $bytes.Length)
    }
}

$mimeTypes = @{
    '.html' = 'text/html; charset=utf-8'
    '.htm' = 'text/html; charset=utf-8'
    '.js' = 'application/javascript; charset=utf-8'
    '.css' = 'text/css; charset=utf-8'
    '.json' = 'application/json; charset=utf-8'
    '.jsonl' = 'application/x-ndjson; charset=utf-8'
    '.txt' = 'text/plain; charset=utf-8'
}

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add($Prefix)
try {
    $listener.Start()
} catch {
    Write-ServerLog ('Server not started. ' + $_.Exception.Message)
    Start-Sleep -Seconds 20
    exit 1
}

Write-ServerLog "Serving $Root at ${Prefix}dashboard.html"

while ($listener.IsListening) {
    $context = $listener.GetContext()
    try {
        $method = $context.Request.HttpMethod
        if ($method -ne 'GET' -and $method -ne 'HEAD') {
            Send-TextResponse $context 405 'Method Not Allowed' 'Method not allowed.'
            continue
        }

        $requestPath = [System.Uri]::UnescapeDataString($context.Request.Url.AbsolutePath)
        if ([string]::IsNullOrWhiteSpace($requestPath) -or $requestPath -eq '/') {
            $requestPath = '/dashboard.html'
        }

        $relativePath = $requestPath.TrimStart('/').Replace('/', [System.IO.Path]::DirectorySeparatorChar)
        if ($relativePath -match '(^|[\\/])\.\.([\\/]|$)') {
            Send-TextResponse $context 403 'Forbidden' 'Forbidden.'
            continue
        }

        $rootFull = [System.IO.Path]::GetFullPath($Root)
        $separator = [string][System.IO.Path]::DirectorySeparatorChar
        $rootPrefix = $rootFull
        if (!$rootPrefix.EndsWith($separator)) {
            $rootPrefix += $separator
        }
        $filePath = [System.IO.Path]::GetFullPath((Join-Path $rootFull $relativePath))
        if (!$filePath.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            Send-TextResponse $context 403 'Forbidden' 'Forbidden.'
            continue
        }

        if (!(Test-Path -LiteralPath $filePath -PathType Leaf)) {
            Send-TextResponse $context 404 'Not Found' 'Not found.'
            continue
        }

        $fileInfo = Get-Item -LiteralPath $filePath
        $fileLength = [int64]$fileInfo.Length
        $rangeHeader = $context.Request.Headers['Range']
        $start = [int64]0
        $end = [int64]($fileLength - 1)
        if ($fileLength -eq 0) {
            $end = [int64]-1
        }
        $statusCode = 200
        $statusText = 'OK'
        if ($rangeHeader -match '^bytes=(\d+)-(\d*)$') {
            $start = [int64]$matches[1]
            if ($matches[2] -ne '') {
                $end = [int64]$matches[2]
            }
            if ($fileLength -eq 0 -or $start -ge $fileLength) {
                $response = $context.Response
                $response.StatusCode = 416
                $response.StatusDescription = 'Range Not Satisfiable'
                $response.ContentLength64 = 0
                $response.Headers['Accept-Ranges'] = 'bytes'
                $response.Headers['Content-Range'] = "bytes */$fileLength"
                Set-CommonHeaders $response
                continue
            }
            if ($end -ge $fileLength) {
                $end = $fileLength - 1
            }
            if ($end -lt $start) {
                $end = $start
            }
            $statusCode = 206
            $statusText = 'Partial Content'
        }
        $contentLength = [int64]0
        if ($fileLength -gt 0) {
            $contentLength = [int64]($end - $start + 1)
        }
        $ext = [System.IO.Path]::GetExtension($filePath).ToLowerInvariant()
        $contentType = $mimeTypes[$ext]
        if ([string]::IsNullOrWhiteSpace($contentType)) {
            $contentType = 'application/octet-stream'
        }

        $response = $context.Response
        $response.StatusCode = $statusCode
        $response.StatusDescription = $statusText
        $response.ContentType = $contentType
        $response.ContentLength64 = $contentLength
        $response.Headers['Accept-Ranges'] = 'bytes'
        if ($statusCode -eq 206) {
            $response.Headers['Content-Range'] = "bytes $start-$end/$fileLength"
        }
        Set-CommonHeaders $response
        if ($method -ne 'HEAD' -and $contentLength -gt 0) {
            $fileStream = [System.IO.File]::OpenRead($filePath)
            try {
                $fileStream.Seek($start, [System.IO.SeekOrigin]::Begin) | Out-Null
                $bufferSize = [int][Math]::Min(65536, $contentLength)
                $buffer = New-Object byte[] $bufferSize
                $remaining = [int64]$contentLength
                while ($remaining -gt 0) {
                    $readSize = [int][Math]::Min($buffer.Length, $remaining)
                    $read = $fileStream.Read($buffer, 0, $readSize)
                    if ($read -le 0) {
                        break
                    }
                    $response.OutputStream.Write($buffer, 0, $read)
                    $remaining -= $read
                }
            } finally {
                $fileStream.Close()
            }
        }
    } catch {
        Write-ServerLog ('Request failed. ' + $_.Exception.Message)
        try {
            Send-TextResponse $context 500 'Internal Server Error' 'Internal server error.'
        } catch {
        }
    } finally {
        try {
            $context.Response.OutputStream.Close()
        } catch {
        }
    }
}
