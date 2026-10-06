param(
    [switch]$StopAfter
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$composeFile = Join-Path $repositoryRoot 'server/layer/deploy/compose.nats.smoke.yml'
$certificateDirectory = Join-Path $env:TEMP 'decolumax-nats-smoke-certs'
New-Item -ItemType Directory -Path $certificateDirectory -Force | Out-Null

$env:NATS_SMOKE_CERT_DIR = $certificateDirectory
$env:NATS_SMOKE_USER = 'sync_smoke'
$env:NATS_SMOKE_PASSWORD = 'local_smoke_only_change-me'

$openssl = Get-Command openssl -ErrorAction SilentlyContinue
if (-not $openssl) {
    $gitOpenSsl = 'C:\Program Files\Git\usr\bin\openssl.exe'
    if (Test-Path -LiteralPath $gitOpenSsl) {
        $opensslPath = $gitOpenSsl
    } else {
        throw 'Install OpenSSL or Git for Windows to create the local TLS certificate.'
    }
} else {
    $opensslPath = $openssl.Source
}

& $opensslPath req -x509 -newkey rsa:2048 -nodes -keyout (Join-Path $certificateDirectory 'server-key.pem') -out (Join-Path $certificateDirectory 'server-cert.pem') -days 365 -subj '/CN=localhost' -addext 'subjectAltName=DNS:localhost,IP:127.0.0.1'
if ($LASTEXITCODE -ne 0) { throw 'Could not create the local TLS certificate.' }

& docker compose -f $composeFile up -d
if ($LASTEXITCODE -ne 0) { throw 'Could not start the local NATS JetStream service.' }

$ready = $false
for ($attempt = 0; $attempt -lt 30; $attempt++) {
    try {
        $null = Invoke-RestMethod -Uri 'http://127.0.0.1:8222/varz' -TimeoutSec 2
        $ready = $true
        break
    } catch {
        Start-Sleep -Seconds 1
    }
}
if (-not $ready) { throw 'NATS did not become ready on its local monitoring port.' }

try {
    $env:NATS_SMOKE_URL = 'tls://localhost:4222'
    $env:NATS_SMOKE_CA_CERT = Join-Path $certificateDirectory 'server-cert.pem'
    Push-Location (Join-Path $repositoryRoot 'apps/client')
    try {
        & dart run tool/nats_mailbox_smoke.dart
        if ($LASTEXITCODE -ne 0) { throw 'The Flutter NATS mailbox smoke test failed.' }
    }
    finally {
        Pop-Location
    }
}
finally {
    if ($StopAfter) {
        & docker compose -f $composeFile down
        if ($LASTEXITCODE -ne 0) { throw 'The NATS smoke service did not stop cleanly.' }
    }
    Remove-Item Env:NATS_SMOKE_URL -ErrorAction SilentlyContinue
    Remove-Item Env:NATS_SMOKE_CA_CERT -ErrorAction SilentlyContinue
    Remove-Item Env:NATS_SMOKE_USER -ErrorAction SilentlyContinue
    Remove-Item Env:NATS_SMOKE_PASSWORD -ErrorAction SilentlyContinue
    Remove-Item Env:NATS_SMOKE_CERT_DIR -ErrorAction SilentlyContinue
}
