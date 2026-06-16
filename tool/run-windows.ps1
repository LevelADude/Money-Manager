# Startet die App als Windows-Desktop-App.
# Voraussetzung: env.json existiert (aus env.example.json kopieren und ausfuellen).
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path "$root\env.json")) {
  Write-Error "env.json fehlt. Kopiere env.example.json -> env.json und trage deine Supabase-Werte ein."
}
& flutter run -d windows --dart-define-from-file="$root\env.json"
