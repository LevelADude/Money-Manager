Feste Datenbank-Verbindung dieses Repos
=======================================

Die Datei `connection.json` in diesem Ordner bindet diese App-Instanz fest an
eine Supabase-Datenbank. Ist sie vorhanden und gueltig, verbindet sich jedes
Geraet automatisch mit dieser Datenbank - ohne dass beim Start nach URL +
Schluessel gefragt wird.

Format von connection.json:

    {
      "url": "https://DEIN-PROJEKT.supabase.co",
      "anonKey": "DEIN-ANON-ODER-PUBLISHABLE-KEY"
    }

URL und anon/publishable-Key sind oeffentliche Client-Werte (sie stecken
ohnehin im fertigen Web-Build). Der Zugriff auf Daten ist durch RLS und die
E-Mail-Whitelist geschuetzt, nicht durch Geheimhaltung dieser Werte.

Von dieser Datenbank trennen (z. B. als neuer Nutzer / nach einem Fork)
---------------------------------------------------------------------------
Loesche NUR die Datei `connection.json` (diesen README.txt / den Ordner
behalten - sonst schlaegt der Build fehl). Beim naechsten Start zeigt die App
dann wieder das Onboarding: neue eigene Datenbank anlegen oder eine bestehende
verbinden.

Pro Geraet laesst sich die Verbindung ausserdem jederzeit ueber
"Datenbank-Verbindung aendern" (Login bzw. Profil) ueberschreiben oder auf
diese Standard-Verbindung zuruecksetzen.
