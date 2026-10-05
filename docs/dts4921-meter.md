# DTS4921 Energiezähler-Unterstützung (Kinetos OpenEVSE V5)

Diese Dokumentation beschreibt die Integration des dreiphasigen Modbus-RTU-Energiezählers **DTS4921** in die Kinetos OpenEVSE V5 Firmware sowie den Ablauf zum Erstellen (Bauen) dieser Firmware-Version.

---

## 1. Übersicht & Motivation

Standardmäßig nutzt die Kinetos-Firmware das Modbus-Protokoll für Eastron-Zähler (z. B. SDM630 / SDM72D-M). Der Zähler **DTS4921** weicht in wesentlichen Punkten davon ab:
- **Modbus-Funktionscode:** Verwendet `0x03` (*Read Holding Registers*) statt `0x04` (*Read Input Registers*).
- **Datenformat:** 32-Bit-Ganzzahlen (Big-Endian, vorzeichenlos bzw. mit Vorzeichen bei Leistung) statt IEEE-754 32-Bit-Gleitkommazahlen (Floats).
- **Skalierungsfaktoren:** Fest definierte Multiplikatoren (z. B. $0{,}1\,\text{V}$, $0{,}001\,\text{A}$, $0{,}01\,\text{kWh}$).

Die Integration erfolgt sauber und modular über einen separaten Patch in `firmware/patches-dts4921/`, sodass die Upstream-Dateien unangetastet bleiben.

---

## 2. Modbus-Registerübersicht (DTS4921)

Alle Abfragen erfolgen mit Modbus-Funktionscode **`0x03`** (Länge: jeweils 2 Register = 4 Bytes / 32-Bit).

| Messwert | Register (Hex) | Register (Dez) | Datentyp | Auflösung / Skalierung | Einheit |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Spannung L1** | `0x0100` | 256 | `uint32` | $\times 0{,}1$ | V |
| **Spannung L2** | `0x0102` | 258 | `uint32` | $\times 0{,}1$ | V |
| **Spannung L3** | `0x0104` | 260 | `uint32` | $\times 0{,}1$ | V |
| **Strom L1** | `0x0106` | 262 | `uint32` | $\times 0{,}001$ ($1\,\text{mA}$) | A |
| **Strom L2** | `0x0108` | 264 | `uint32` | $\times 0{,}001$ ($1\,\text{mA}$) | A |
| **Strom L3** | `0x010A` | 266 | `uint32` | $\times 0{,}001$ ($1\,\text{mA}$) | A |
| **Wirkleistung L1** | `0x0110` | 272 | `int32` | $\times 0{,}1$ | W |
| **Wirkleistung L2** | `0x0112` | 274 | `int32` | $\times 0{,}1$ | W |
| **Wirkleistung L3** | `0x0114` | 276 | `int32` | $\times 0{,}1$ | W |
| **Gesamtwirkleistung** | `0x010E` | 270 | `int32` | $\times 0{,}1$ | W |
| **Import-Wirkenergie** | `0x0027` | 39 | `uint32` | $\times 0{,}01$ ($10\,\text{Wh}$) | kWh |
| **Gesamtwirkenergie** | `0x001D` | 29 | `uint32` | $\times 0{,}01$ ($10\,\text{Wh}$) | kWh |

---

## 3. Struktur der Änderungen

- **Branch:** `DTS4921_meter`
- **Patch-Datei:** `firmware/patches-dts4921/0001-dts4921-meter.patch`
  - Passt `src/sdm_meter.h` und `src/sdm_meter.cpp` an.
  - Implementiert Bedingung `#ifdef METER_DTS4921` für Registertabelle, Funktionscode und Dekodierungslogik.
- **Build-Skript:** `firmware/build-dts4921.sh`
  - Nutzt ein separates Arbeitsverzeichnis `firmware/.work-dts4921`.
  - Wendet zuerst die Basis-Kinetos-Patches an (`patches-master/`), gefolgt vom DTS4921-Patch (`patches-dts4921/`).
  - Erzeugt die Firmware unter dem Namen `kinetos-v5-v5.2.0-dev-dts4921-<rev>.bin`.

---

## 4. Bauen der Firmware

### Voraussetzungen
- **Bash-Umgebung** (Linux, macOS oder Git Bash unter Windows)
- **Node.js & npm** (für den Build des Web-Interfaces `gui-nightshift`)
- **PlatformIO CLI** (`pio` im Pfad installiert oder via `uv tool run`)
- **Git**

### Build-Befehl ausführen

In der Konsole / Git Bash:

```bash
cd firmware
./build-dts4921.sh
```

### Build-Ergebnis
Nach erfolgreichem Durchlauf liegt die fertige Firmware im Verzeichnis:
```
firmware/out/kinetos-v5-v5.2.0-dev-dts4921-18.bin
```
Zusätzlich wird beim Build die SHA256-Prüfsumme in der Konsole ausgegeben.

---

## 5. Firmware-Update auf der Wallbox
1. Das Webinterface der Wallbox im Browser öffnen.
2. Zur Seite **System / Update** (`/update`) navigieren.
3. Die Binärdatei `kinetos-v5-v5.2.0-dev-dts4921-18.bin` auswählen und flashen.
4. Nach dem Neustart liest die Wallbox die Phasenwerte (Spannung, Strom, Leistung, Zählerstand) direkt vom DTS4921 aus.

---

## 6. Lokales Build-Verzeichnis (.work-dts4921)
Das Verzeichnis `firmware/.work-dts4921/` dient als Cache für Upstream-Quellen, Node-Module und kompilierte Bibliotheken. Es beschleunigt Folge-Builds erheblich.
Falls Plattenplatz freigegeben werden soll oder ein komplett frischer Build gewünscht ist, kann der Ordner jederzeit gelöscht werden:

```powershell
Remove-Item -Recurse -Force firmware\.work-dts4921
```
