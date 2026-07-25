Feste Datenbank-Verbindung dieses Repos (optional)
==================================================

Die Datei `connection.json` in diesem Ordner KANN diese App-Instanz fest an
eine Supabase-Datenbank binden. Ist sie mit gueltigen Werten gefuellt, verbindet
sich jedes Geraet automatisch mit dieser Datenbank - ohne dass beim Start nach
URL + Schluessel gefragt wird.

WICHTIG: Im Original-Repo ist `connection.json` bewusst nur ein PLATZHALTER
(Werte "DEIN-PROJEKT..."). Dadurch startet ein frischer Fork LEER und zeigt das
Onboarding, statt sich still mit einer fremden Datenbank zu verbinden. Der
Platzhalter wird beim Start ignoriert (siehe DbConnectionFile.parse).

Format von connection.json:

    {
      "url": "https://DEIN-PROJEKT.supabase.co",
      "anonKey": "DEIN-ANON-ODER-PUBLISHABLE-KEY"
    }

URL und anon/publishable-Key sind oeffentliche Client-Werte (sie stecken
ohnehin im fertigen Web-Build). Der Zugriff auf Daten ist durch RLS und die
E-Mail-Whitelist geschuetzt, nicht durch Geheimhaltung dieser Werte.

Eigene Datenbank binden
-----------------------
Bevorzugt ueber dart-define (die Werte landen NICHT in dieser committeten
Datei, sondern nur im jeweiligen Build):
  * lokal: `env.json` (aus `env.example.json` kopieren) via
    `--dart-define-from-file=env.json` (siehe `tool/run-*.ps1`),
  * Web-Deploy (GitHub Pages): die Repo-Secrets `SUPABASE_URL` +
    `SUPABASE_ANON_KEY` (der Deploy-Workflow bettet sie zusaetzlich in die
    connection.json des Builds ein, damit "Von Web-Version uebernehmen" wirkt).

Alternativ (Fortgeschritten): die Platzhalter-Werte hier direkt durch deine
eigenen ersetzen und committen. Achtung - eine committete `connection.json` mit
echten Werten wird von jedem Fork geerbt.

Diesen README.txt / den Ordner NICHT loeschen (der Ordner-Eintrag im
pubspec haelt den Build am Leben; eine fehlende connection.json ist ok und
fuehrt einfach ins Onboarding).
