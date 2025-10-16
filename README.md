# DDR Wirtschaftssimulation für DarkRP

Dieses Repository enthält ein modulares Lua-System, das eine umfangreiche Staatswirtschaft für ein DDR-RP-Szenario in Garry's Mod (DarkRP) simuliert. Das System berechnet in festen Spielperioden zentrale Kennzahlen wie Staatskasse, Schuldenstand, Inflation, BIP und Arbeitslosigkeit und bietet dem Finanzminister ein GUI zur Verwaltung von Steuern, Budgets, Krediten und staatlichen Shops.

## Module

- `lua/autorun/ddr_economy_init.lua` – Initialisiert das Wirtschaftssystem auf Server und Client.
- `lua/ddr_economy/shared/config.lua` – Konfiguration von Teams, Ministerien (inkl. dynamischer Mitarbeiterzählung), Basiswerten und Shop-Angeboten.
- `lua/ddr_economy/server/state.lua` – Persistenter Staatszustand, Speicherung und Netztwerk-Synchronisation.
- `lua/ddr_economy/server/calculations.lua` – Periodische Wirtschaftsberechnungen (BIP, Inflation, Defizit usw.).
- `lua/ddr_economy/server/taxes.lua` – Verwaltung von Steuersätzen, Budgets, Krediten und Shoppreisen.
- `lua/ddr_economy/server/commands.lua` – Chat-/Konsolenbefehle sowie GUI-Aktionsempfänger.
- `lua/ddr_economy/client/gui.lua` – Derma-GUI für den Finanzminister mit Übersicht, Steuern, Budgets, Schulden, Historie und staatlichem Shop.

## Installation

1. Lege den Inhalt dieses Repositories im `garrysmod/addons`-Verzeichnis deines Servers ab.
2. Passe die Einträge in `lua/ddr_economy/shared/config.lua` an dein DarkRP-Setup an (Teams, Ministerien, Standardbudgets, Shops).
3. Starte den Server neu. Das System beginnt automatisch mit den periodischen Berechnungen.
4. Finanzminister (oder Super-Admins) öffnen die Verwaltung per Chatbefehl `/minfin_menu`, Konsolenbefehl `drecon_menu` oder der Client-Konsole `drecon_open_gui`.

## Features

- Realistische, aber performante Berechnungen von Inflation, BIP, Arbeitslosenquote und Defizit.
- Ministeriumsbudgets inklusive Effizienz, Korruption und deren Auswirkungen auf die Wirtschaft.
- Automatische Ermittlung der tatsächlichen Mitarbeiterzahlen pro Ministerium anhand der aktuellen Spielerjobs.
- Steuerverwaltung (Einkommen-, Unternehmens- und Umsatzsteuer) direkt über das GUI.
- Kreditaufnahme, Schuldentilgung und Budgettransfers zwischen Ministerien.
- Staatlicher Shop mit automatischer Preissteigerung und Schulden-bedingten Sperren für Luxusgüter.
- Persistente Speicherung aller Staatsdaten inklusive Verlauf der letzten Perioden.

## Lizenz

Dieses Projekt steht unter der MIT-Lizenz. Weitere Details siehe `LICENSE` (falls vorhanden) oder ergänze eigene Lizenzinformationen.
