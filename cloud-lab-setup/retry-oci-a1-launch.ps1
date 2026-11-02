<#
.SYNOPSIS
    Retries launching an Oracle Cloud Always Free Ampere A1 instance until capacity frees up.

.DESCRIPTION
    Free-tier A1 capacity is frequently exhausted ("Out of host capacity") in busy regions.
    This script cycles through every availability domain, waits between rounds, backs off
    when Oracle rate-limits the account (HTTP 429), and alerts on success.

    All account-specific values (OCIDs, ADs, key paths) live in lab-config.local.json,
    which is git-ignored. Copy lab-config.example.json to lab-config.local.json and fill it in.

.NOTES
    Requires the OCI CLI, configured with an API key (oci setup config).
    Run: powershell -ExecutionPolicy Bypass -File .\retry-oci-a1-launch.ps1
#>

$configPath = Join-Path $PSScriptRoot "lab-config.local.json"
if (-not (Test-Path $configPath)) {
    Write-Host "Missing $configPath - copy lab-config.example.json and fill in your values." -ForegroundColor Red
    exit 1
}
$cfg = Get-Content $configPath -Raw | ConvertFrom-Json

# Temp files for CLI JSON arguments (kept outside the repo)
$workDir = Join-Path $env:USERPROFILE ".oci"
New-Item -ItemType Directory -Force -Path $workDir | Out-Null

$metadataPath = Join-Path $workDir "metadata.json"
@{ ssh_authorized_keys = (Get-Content $cfg.sshPublicKeyPath -Raw).Trim() } |
    ConvertTo-Json | Set-Content -Path $metadataPath -Encoding ascii

$shapeConfigPath = Join-Path $workDir "shapeconfig.json"
@{ ocpus = $cfg.ocpus; memoryInGBs = $cfg.memoryInGBs } |
    ConvertTo-Json | Set-Content -Path $shapeConfigPath -Encoding ascii

$successLog = Join-Path $workDir "launch-success.txt"

# Timing
$roundWait = 300   # seconds between full rounds
$adPause   = 30    # seconds between availability domains
$backoff   = 600   # seconds after a 429; doubles on repeat, max 1 hour

$attempt  = 0
$launched = $false
$stop     = $false

while (-not $launched -and -not $stop) {
    foreach ($ad in $cfg.availabilityDomains) {
        $attempt++
        Write-Host "[$('{0:HH:mm:ss}' -f (Get-Date))] Attempt $attempt - trying $ad..."

        $result = oci compute instance launch `
            --availability-domain $ad `
            --compartment-id $cfg.compartmentId `
            --shape "VM.Standard.A1.Flex" `
            --shape-config file://$shapeConfigPath `
            --image-id $cfg.imageId `
            --subnet-id $cfg.subnetId `
            --assign-public-ip true `
            --display-name $cfg.displayName `
            --metadata file://$metadataPath 2>&1 | Out-String

        if ($LASTEXITCODE -eq 0) {
            Write-Host "SUCCESS! Instance created in $ad" -ForegroundColor Green
            Write-Host $result
            $result | Out-File $successLog
            1..5 | ForEach-Object { [console]::beep(1000, 400); Start-Sleep -Milliseconds 200 }
            Add-Type -AssemblyName PresentationFramework
            [System.Windows.MessageBox]::Show("Oracle instance created in $ad!", $cfg.displayName) | Out-Null
            $launched = $true
            break
        }
        elseif ($result -match "Out of host capacity") {
            Write-Host "  -> Out of capacity in $ad" -ForegroundColor Yellow
            $backoff = 600
            Start-Sleep -Seconds $adPause
        }
        elseif ($result -match "TooManyRequests" -or $result -match '"status": 429') {
            Write-Host "  -> Rate limited by Oracle. Waiting $([int]($backoff / 60)) minutes..." -ForegroundColor Magenta
            Start-Sleep -Seconds $backoff
            $backoff = [Math]::Min($backoff * 2, 3600)
        }
        elseif ($result -match "InternalError" -or $result -match '"status": 5\d\d') {
            Write-Host "  -> Oracle server error, retrying after a pause..." -ForegroundColor Magenta
            Start-Sleep -Seconds 120
        }
        else {
            Write-Host "  -> Unexpected error, stopping:" -ForegroundColor Red
            Write-Host $result
            $stop = $true
            break
        }
    }

    if (-not $launched -and -not $stop) {
        Write-Host "Round done. Waiting $([int]($roundWait / 60)) minutes..."
        Start-Sleep -Seconds $roundWait
    }
}
