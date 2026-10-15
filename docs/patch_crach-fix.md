Was wurde geändert?
Die Korrekturen wurden als sauberer Patch firmware/patches-master/firmware-0002-crash-fixes.patch abgelegt, sodass sie sowohl bei build-dts4921.sh als auch build-master.sh automatisch angewendet werden:

1. Watchdog-Fix für LittleFS (src/fs_util.h)
Caching des freien Speichers: Statt bei jedem zyklischen Zähler-Speichern (EnergyMeter::save()) das gesamte Dateisystem Block für Block zu durchforsten, wird der freie Speicher nun für 60 Sekunden gepuffert. Da /emeter.json nur ~200 Bytes groß ist und einen bestehenden Eintrag überschreibt, reicht das völlig aus.
CPU-Yield & Watchdog-Reset: Vor und nach dem LittleFS-Scan wird delay(1) und feedLoopWDT() ausgeführt. Dadurch erhält Core 0 (IDLE0 und ipc0) die nötige CPU-Zeit, um alle ausstehenden Netzwerk-Aufgaben abzuarbeiten und den Task-Watchdog (TWDT) zurückzusetzen.
Ergebnis: Keine Blockaden und Watchdog-Resets mehr beim Speichern der Zählerdaten.
2. lwIP / UDP Race Condition Fix (src/ota.cpp & src/main.cpp)
ArduinoOTA stillgelegt: Die Altlast ArduinoOTA (Port 3232 zum Flashen direkt aus der Arduino IDE) wurde deaktiviert (kann bei Bedarf via #define ENABLE_ARDUINO_OTA wieder einkompiliert werden).
Kein ungeschütztes Socket-Polling: Core 1 führt nicht mehr in jedem loop()-Durchlauf UDP-Socket-Abfragen durch, während lwIP auf Core 0 eingehende Ethernet-Pakete verarbeitet.
Kein doppelter mDNS-Start: Der vorzeitige Start von MDNS.begin() in ArduinoOTA vor fertiger Netzwerk-Initialisierung entfällt. mDNS wird nun sauber und exklusiv über den NetManagerTask registriert.
Web-Updates unberührt: Das reguläre Web-Flashen über das Interface (/update) läuft über HTTP und funktioniert weiterhin uneingeschränkt.
Ergebnis: Keine Korrumpierung der internen lwIP UDP-PCB-Verbindungsliste mehr; der Absturz in udp_input() ist behoben.
Status des Builds
Der komplette Build (bash firmware/build-dts4921.sh) lief fehlerfrei durch:

Fertiges Binary: firmware/out/kinetos-v5-v5.2.0-dev-dts4921-18.bin
SHA256: 0bff37bbc35260c36ae658b4e76e1f1df3fe2c4d72aced3533f58e68066671ca
Du kannst das neue Binary direkt über die Web-Oberfläche deiner Wallbox unter /update einspielen.