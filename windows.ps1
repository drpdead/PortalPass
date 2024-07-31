# Windows PowerShell Script

# Requires admin privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Run as Administrator!"
    Break
}

$LogFile = "$env:TEMP\escCaptivePortal.log"
$null > $LogFile

function Log-Message {
    param([string]$message)
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $message" | Out-File -Append -FilePath $LogFile
}

function Log-Error {
    param([string]$message)
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - ERROR: $message" | Out-File -Append -FilePath $LogFile
    Write-Error "ERROR: $message"
}

$interface = Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select-Object -First 1
$localIP = $interface | Get-NetIPAddress -AddressFamily IPv4 | Select-Object -ExpandProperty IPAddress
$gateway = $interface | Get-NetRoute -DestinationPrefix 0.0.0.0/0 | Select-Object -ExpandProperty NextHop
$subnet = $interface | Get-NetIPAddress -AddressFamily IPv4 | Select-Object -ExpandProperty PrefixLength
$macAddress = $interface.MacAddress

Log-Message "Exploring network on interface $($interface.Name)"

function Test-Connectivity {
    $pingTest = Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet
    $webTest = Invoke-WebRequest -Uri "http://www.google.com" -UseBasicParsing -TimeoutSec 5
    $dnsTest = Resolve-DnsName -Name "www.google.com" -ErrorAction SilentlyContinue

    if ($pingTest -and $webTest.StatusCode -eq 200 -and $dnsTest) {
        Log-Message "Network connectivity verified."
        return $true
    } else {
        Log-Error "Network connectivity check failed."
        return $false
    }
}

function Set-RandomMAC {
    $mac = [BitConverter]::ToString([byte[]](1..6 | ForEach-Object {Get-Random -Minimum 0 -Maximum 255})).Replace("-", ":")
    $interface | Set-NetAdapter -MacAddress $mac
    Log-Message "MAC address changed to $mac"
}

Log-Message "Starting captive portal circumvention attempts..."

$attempts = 0
$maxAttempts = 10

while ($attempts -lt $maxAttempts) {
    $attempts++
    Log-Message "Attempt $attempts of $maxAttempts"

    Set-RandomMAC
    Start-Sleep -Seconds 2

    ipconfig /release
    Start-Sleep -Seconds 2
    ipconfig /renew
    Start-Sleep -Seconds 5

    if (Test-Connectivity) {
        Log-Message "Success! Captive Portal circumvented."
        break
    }
}

if ($attempts -ge $maxAttempts) {
    Log-Error "Unable to circumvent Captive Portal after $maxAttempts attempts."
}

Log-Message "Restoring original MAC address: $macAddress"
$interface | Set-NetAdapter -MacAddress $macAddress

Write-Host "Log file available at: $LogFile"
