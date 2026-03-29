param(
  [Parameter(Mandatory = $true)]
  [string]$P12Path,

  [Parameter(Mandatory = $true)]
  [string]$MobileProvisionPath,

  [string]$OutputDir = ".\\out"
)

$ErrorActionPreference = "Stop"

if (!(Test-Path -LiteralPath $P12Path)) {
  throw "No existe el archivo P12: $P12Path"
}

if (!(Test-Path -LiteralPath $MobileProvisionPath)) {
  throw "No existe el provisioning profile: $MobileProvisionPath"
}

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$p12Bytes = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $P12Path))
$profileBytes = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $MobileProvisionPath))

$p12Base64 = [Convert]::ToBase64String($p12Bytes)
$profileBase64 = [Convert]::ToBase64String($profileBytes)

$p12Out = Join-Path $OutputDir "IOS_CERTIFICATE_P12_BASE64.txt"
$profileOut = Join-Path $OutputDir "IOS_PROVISIONING_PROFILE_BASE64.txt"

[IO.File]::WriteAllText($p12Out, $p12Base64)
[IO.File]::WriteAllText($profileOut, $profileBase64)

Write-Host "Generado:"
Write-Host " - $p12Out"
Write-Host " - $profileOut"
Write-Host ""
Write-Host "Usa esos valores para los Secrets de GitHub Actions."
