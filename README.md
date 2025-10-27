# DDR Wirtschaftssimulation für DarkRP

Dieses Repository enthält ein modulares Lua-System, das eine umfangreiche Staatswirtschaft für ein DDR-RP-Szenario in Garry's Mod (DarkRP) simuliert. Das System berechnet in festen Spielperioden zentrale Kennzahlen wie Staatskasse, Schuldenstand, Inflation, BIP und Arbeitslosigkeit und bietet dem Finanzminister ein GUI zur Verwaltung von Steuern, Budgets, Krediten und staatlichen Shops.

## Module

- `lua/autorun/ddr_economy_init.lua` – Initialisiert das Wirtschaftssystem auf Server und Client.
- `lua/ddr_economy/shared/config.lua` – Konfiguration von Teams, Ministerien (inkl. dynamischer Mitarbeiterzählung), Basiswerten und Shop-Angeboten.
- `lua/ddr_economy/server/state.lua` – Persistenter Staatszustand, Speicherung und Netztwerk-Synchronisation.
- `lua/ddr_economy/server/calculations.lua` – Periodische Wirtschaftsberechnungen auf Basis protokollierter DarkRP-Aktivitäten.
- `lua/ddr_economy/server/metrics.lua` – Echtzeit-Hooks für Gehaltszahlungen, Käufe, Bußgelder, Geldumlauf u.v.m.
- `lua/ddr_economy/server/taxes.lua` – Verwaltung von Steuersätzen, Budgets, Krediten und Shoppreisen.
- `lua/ddr_economy/server/commands.lua` – Chat-/Konsolenbefehle sowie GUI-Aktionsempfänger.
- `lua/ddr_economy/client/gui.lua` – Derma-GUI für den Finanzminister mit Übersicht, Steuern, Budgets, Schulden, Historie und staatlichem Shop.

## Installation

1. Lege den Inhalt dieses Repositories im `garrysmod/addons`-Verzeichnis deines Servers ab.
2. Passe die Einträge in `lua/ddr_economy/shared/config.lua` an dein DarkRP-Setup an (Teams, Ministerien, Standardbudgets, Shops).
3. Starte den Server neu. Das System beginnt automatisch mit den periodischen Berechnungen.
4. Finanzminister (oder Super-Admins) öffnen die Verwaltung per Chatbefehl `/minfin_menu`, Konsolenbefehl `drecon_menu` oder der Client-Konsole `drecon_open_gui`.

## Features

- Echtzeitaggregation aller relevanten Kennzahlen ausschließlich aus DarkRP-Hooks (Gehälter, Käufe, Bußgelder, Geldmenge, Arrests, Lockdowns usw.).
- Periodische BIP-/Inflationsberechnung auf Basis von Konsum, Investitionen und staatlichen Ausgaben, inklusive Geldmengen- und Sicherheitsfaktoren.
- Ministeriumsbudgets mit Live-Mitarbeiterzählung, Budgetverbrauch, Überziehungen und automatischer Verschuldung bei Unterfinanzierung.
- Steuerverwaltung (Einkommen, Unternehmen, Umsatz) mit unmittelbarer Auswirkung auf reale Transaktionen und transparenten Quellenangaben.
- Kreditaufnahme, Schuldentilgung, Budgettransfers und Projektausgaben, jeweils mit Auswirkungen auf Schuldenquote und Staatskasse.
- Staatlicher Shop mit Inflationsfaktor, Schuldenrestriktionen und konfigurierbaren Items pro Ministerium.
- Umfangreiche GUI mit Karten, Tabellen, Graphen und Quellenbox für die letzten Perioden (inkl. Geldmengenänderung, Sicherheitslage, BIP-Historie).
- Persistente Speicherung aller Staatsdaten inklusive Verlauf und rekonstruierbaren Kennzahlen je Periode.

## Lizenz

Dieses Projekt steht unter der MIT-Lizenz. Weitere Details siehe `LICENSE` (falls vorhanden) oder ergänze eigene Lizenzinformationen.
