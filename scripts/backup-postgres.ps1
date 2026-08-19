param(
    [Parameter(Mandatory = $true)] [string] $Container,
    [string] $Database = "uniassist",
    [string] $Username = "uniassist",
    [string] $OutputDirectory = "backups"
)

$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$destination = Join-Path $OutputDirectory "uniassist-$timestamp.dump"

docker exec $Container pg_dump -U $Username -Fc $Database > $destination
if ((Get-Item $destination).Length -eq 0) {
    Remove-Item -LiteralPath $destination
    throw "Backup failed: the output file was empty."
}
Write-Host "Backup written to $destination"
