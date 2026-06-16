# Startet die App auf einem verbundenen Android-Geraet / Emulator.
# Voraussetzung: env.json existiert + ein Android-Geraet ist via "flutter devices" sichtbar.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path "$root\env.json")) {
  Write-Error "env.json fehlt. Kopiere env.example.json -> env.json und trage deine Supabase-Werte ein."
}
& flutter run -d android --dart-define-from-file="$root\env.json"
