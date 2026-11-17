#!/usr/bin/env bash
# Kürzt Inter auf die Zeichen, die die App braucht (Latein inkl. erweitert,
# Griechisch, Kyrillisch, Satz-, Währungs- und Pfeilzeichen). Spart rund
# 40 % der Schriftdatei. Aufruf mit der vollständigen Inter-Variable-TTF:
#   pip install fonttools
#   tool/subset-inter.sh pfad/zur/vollen/Inter.ttf
# Fehlende Zeichen (z. B. andere Schriftsysteme) zeigt Flutter weiter über
# die Ersatzschrift des Systems bzw. des Browsers an.
set -euo pipefail
pyftsubset "$1" \
  --unicodes="U+0020-007E,U+00A0-024F,U+02BB-02BC,U+0370-03FF,U+0400-04FF,U+0E3F,U+2000-206F,U+20A0-20BF,U+2100-2122,U+2190-21FF,U+2200-222F,U+2248,U+2260-2265,U+232B,U+25A0-25FF,U+2713" \
  --layout-features='*' \
  --output-file="$(dirname "$0")/../assets/fonts/Inter.ttf"
