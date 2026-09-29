$ErrorActionPreference = "Stop"
$root = "c:\Users\icwry\Desktop\1"
$port = 8000
$prefix = "http://localhost:$port/"

Add-Type -AssemblyName System.Web

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($prefix)
$listener.Start()
Write-Host "服务器已启动: $prefix" -ForegroundColor Green
Write-Host "根目录: $root"
Write-Host "按 Ctrl+C 停止..."

try {
    while ($listener.IsListening) {
        $ctx = $listener.GetContext()
        $req = $ctx.Request
        $res = $ctx.Response

        $rel = $req.Url.AbsolutePath
        if ($rel -eq "/" -or $rel -eq "") { $rel = "/index.html" }

        # 解码 URL 并防止目录穿越
        $rel = [System.Web.HttpUtility]::UrlDecode($rel)
        $full = Join-Path $root ( $rel -replace "^/","" )
        $full = [System.IO.Path]::GetFullPath($full)
        $rootFull = [System.IO.Path]::GetFullPath($root)
        if (-not $full.StartsWith($rootFull)) {
            $res.StatusCode = 403
            $res.Close()
            continue
        }

        if (Test-Path $full -PathType Leaf) {
            $bytes = [System.IO.File]::ReadAllBytes($full)
            $ext = [System.IO.Path]::GetExtension($full).ToLower()
            $mime = switch ($ext) {
                ".html" { "text/html; charset=utf-8" }
                ".css"  { "text/css; charset=utf-8" }
                ".js"   { "application/javascript; charset=utf-8" }
                ".png"  { "image/png" }
                ".jpg"  { "image/jpeg" }
                ".jpeg" { "image/jpeg" }
                ".gif"  { "image/gif" }
                ".webp" { "image/webp" }
                ".svg"  { "image/svg+xml" }
                ".ico"  { "image/x-icon" }
                ".json" { "application/json; charset=utf-8" }
                default { "application/octet-stream" }
            }
            $res.ContentType = $mime
            $res.ContentLength64 = $bytes.Length
            $res.OutputStream.Write($bytes, 0, $bytes.Length)
            Write-Host "200 $rel" -ForegroundColor Cyan
        } else {
            $res.StatusCode = 404
            $msg = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found: $rel")
            $res.OutputStream.Write($msg, 0, $msg.Length)
            Write-Host "404 $rel" -ForegroundColor Red
        }
        $res.Close()
    }
}
finally {
    $listener.Stop()
    Write-Host "服务器已停止"
}
