# Baut einen SIGNIERTEN MSIX-Installer (zusätzlich zur portablen .exe).
#
# Voraussetzungen:
#  - env.json im Projektwurzelverzeichnis (Supabase-Werte)
#  - Code-Signing-Zertifikat unter windows\certs\mm.pfx  (einmalig erzeugen, s. u.)
#  - Visual Studio "Desktopentwicklung mit C++" + Windows-Entwicklermodus
#
# Zertifikat einmalig erzeugen (PowerShell) - <DEIN-PASSWORT> selbst waehlen,
# NICHT ins Skript eintragen (siehe unten, wie der Build das Passwort findet):
#   $c = New-SelfSignedCertificate -Subject "CN=Money Manager" -Type CodeSigningCert `
#        -CertStoreLocation Cert:\CurrentUser\My -KeyExportPolicy Exportable `
#        -KeyUsage DigitalSignature -NotAfter (Get-Date).AddYears(5)
#   $pw = ConvertTo-SecureString "<DEIN-PASSWORT>" -Force -AsPlainText
#   New-Item -ItemType Directory -Force windows\certs | Out-Null
#   Export-PfxCertificate -Cert $c -FilePath windows\certs\mm.pfx -Password $pw
#   Export-Certificate   -Cert $c -FilePath windows\certs\mm.cer
#   Remove-Item ("Cert:\CurrentUser\My\" + $c.Thumbprint)
#   "<DEIN-PASSWORT>" | Set-Content windows\certs\mm.pass -NoNewline
#   (windows\certs\ ist komplett gitignored - Passwort landet nie im Repo.)
#
# Hinweis: msix:create packt/signiert seit Paketversion 3.17 selbst (ueber die
# gebuendelten MSIX-Toolkit-Tools) direkt mit --certificate-path/-password.
# Der AppxManifest.xml-Zwischenschritt im alten "build/windows/runner/Release"
# Pfad (ohne "x64") existiert bei aktuellen Flutter-Versionen nicht mehr -
# deshalb hier direkt signieren statt manuell nachzupacken.

param([string]$CertPassword)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$flutter = "C:\dev\flutter\bin\flutter.bat"  # ggf. anpassen oder 'flutter' wenn im PATH
$dart = "C:\dev\flutter\bin\dart.bat"

if (-not $CertPassword) {
  $passFile = "$root\windows\certs\mm.pass"
  if (Test-Path $passFile) {
    $CertPassword = (Get-Content $passFile -Raw).Trim()
  } else {
    $secure = Read-Host "Zertifikat-Passwort (windows\certs\mm.pfx)" -AsSecureString
    $CertPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
      [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
  }
}

Write-Host "1/2  Windows-Release bauen (mit Supabase-Konfig) ..."
& $flutter build windows --release --dart-define-from-file="$root\env.json"

Write-Host "2/2  MSIX packen + signieren (mit windows\certs\mm.pfx) ..."
& $dart run msix:create `
  --build-windows false `
  --certificate-path "$root\windows\certs\mm.pfx" `
  --certificate-password $CertPassword `
  --install-certificate false `
  --output-path "$root\build\windows\msix" `
  --output-name MoneyManager

$msix = "$root\build\windows\msix\MoneyManager.msix"
if (-not (Test-Path $msix)) { throw "MoneyManager.msix wurde nicht erzeugt." }
Write-Host "Fertig: $msix"
Write-Host "Zum Installieren muss windows\certs\mm.cer einmalig als vertrauenswuerdig importiert werden (Cert:\LocalMachine\Root), sonst lehnt Windows die Installation ab (Publisher nicht vertrauenswuerdig)."
