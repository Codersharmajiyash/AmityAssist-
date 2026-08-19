param(
    [Parameter(Mandatory = $true)] [string] $Container,
    [Parameter(Mandatory = $true)] [string] $BackupFile,
    [string] $Database = "uniassist",
    [string] $Username = "uniassist",
    [switch] $Force
)

$ErrorActionPreference = "Stop"
if (-not $Force) {
    throw "Restore can overwrite database data. Re-run with -Force only after verifying the backup file and target container."
}
if (-not (Test-Path -LiteralPath $BackupFile -PathType Leaf)) {
    throw "Backup file does not exist: $BackupFile"
}

Get-Content -LiteralPath $BackupFile -AsByteStream | docker exec -i $Container pg_restore -U $Username -d $Database --clean --if-exists
Write-Host "Restore completed for $Database in $Container"
