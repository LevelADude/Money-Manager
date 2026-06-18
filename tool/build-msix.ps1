# Baut einen SIGNIERTEN MSIX-Installer (zusätzlich zur portablen .exe).
#
# Voraussetzungen:
#  - env.json im Projektwurzelverzeichnis (Supabase-Werte)
#  - Code-Signing-Zertifikat unter windows\certs\mm.pfx  (einmalig erzeugen, s. u.)
#  - Visual Studio "Desktopentwicklung mit C++" + Windows-Entwicklermodus
#
# Zertifikat einmalig erzeugen (PowerShell):
#   $c = New-SelfSignedCertificate -Subject "CN=Money Manager" -Type CodeSigningCert `
#        -CertStoreLocation Cert:\CurrentUser\My -KeyExportPolicy Exportable `
#        -KeyUsage DigitalSignature -NotAfter (Get-Date).AddYears(5)
#   $pw = ConvertTo-SecureString "MoneyMgr!2026" -Force -AsPlainText
#   New-Item -ItemType Directory -Force windows\certs | Out-Null
#   Export-PfxCertificate -Cert $c -FilePath windows\certs\mm.pfx -Password $pw
#   Export-Certificate   -Cert $c -FilePath windows\certs\mm.cer
#   Remove-Item ("Cert:\CurrentUser\My\" + $c.Thumbprint)
#
# Hinweis: Das mit dem msix-Paket gebündelte makeappx.exe wirft auf manchen
# Systemen einen "Side-by-Side"-Fehler; daher packen/signieren wir mit den
# Tools aus dem Windows SDK.

param([string]$CertPassword = "MoneyMgr!2026")
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$flutter = "F:\flutter\bin\flutter.bat"  # ggf. anpassen oder 'flutter' wenn im PATH
$dart = "F:\flutter\bin\dart.bat"

Write-Host "1/3  Windows-Release bauen (mit Supabase-Konfig) ..."
& $flutter build windows --release --dart-define-from-file="$root\env.json"

Write-Host "2/3  MSIX-Manifest + Assets erzeugen ..."
# Erzeugt AppxManifest.xml + Logos im Release-Ordner. Das eingebaute Packen
# schlägt auf manchen Systemen fehl (Side-by-Side) -> wir fangen den Fehler ab
# und packen anschließend selbst mit den Windows-SDK-Tools (Schritt 3).
try {
  $ErrorActionPreference = "Continue"
  & $dart run msix:create --build-windows false --output-path "$root\build\windows\msix" --output-name MoneyManager
} catch {
  Write-Host "   (eingebautes Packen uebersprungen: $($_.Exception.Message))"
} finally {
  $ErrorActionPreference = "Stop"
}
if (-not (Test-Path "$root\build\windows\x64\runner\Release\AppxManifest.xml")) {
  throw "AppxManifest.xml wurde nicht erzeugt - msix:create ist komplett fehlgeschlagen."
}

# Publisher im Manifest exakt an das Signatur-Zertifikat angleichen, sonst
# scheitert signtool mit 0x8007000b (Publisher-Mismatch).
$cer = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2("$root\windows\certs\mm.cer")
$manifestPath = "$root\build\windows\x64\runner\Release\AppxManifest.xml"
[xml]$mx = Get-Content $manifestPath
$mx.Package.Identity.Publisher = $cer.Subject
$mx.Save($manifestPath)
Write-Host "     Manifest-Publisher = $($cer.Subject)"

Write-Host "3/3  Mit Windows-SDK packen + signieren ..."
$make = Get-ChildItem "C:\Program Files (x86)\Windows Kits\10\bin" -Recurse -Filter makeappx.exe -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -match '\\x64\\' } | Select-Object -Last 1
$sign = Get-ChildItem "C:\Program Files (x86)\Windows Kits\10\bin" -Recurse -Filter signtool.exe -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -match '\\x64\\' } | Select-Object -Last 1
if (-not $make -or -not $sign) { throw "makeappx/signtool nicht gefunden (Windows SDK fehlt?)" }

$rel = "$root\build\windows\x64\runner\Release"
$out = "$root\build\windows\msix"
New-Item -ItemType Directory -Force -Path $out | Out-Null
$msix = "$out\MoneyManager.msix"

& $make.FullName pack /o /d $rel /p $msix
& $sign.FullName sign /fd SHA256 /f "$root\windows\certs\mm.pfx" /p $CertPassword $msix

Write-Host "Fertig: $msix"
