[English](README.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [Bahasa Indonesia](README.id.md) | **Français** | [繁體中文](README.zh-TW.md)

# Font Bridge for OBS

Un script qui permet à OBS de charger naturellement les polices qu'il ne pouvait pas afficher.

<img src="docs/images/en/font_dock.png" alt="Dock Font Bridge" width="272">

- Les polices activées dans un gestionnaire de polices sont chargées automatiquement (sans redémarrer OBS)
- Interface : English / 日本語 / 한국어 / Bahasa Indonesia / Français / 繁體中文 (autres langues d'OBS → English)

## Installation
1. Placez tout le dossier `Font_Bridge_for_OBS` dans `%APPDATA%\obs-studio\plugin_config\` (collez ce chemin dans la barre d'adresse de l'Explorateur pour l'ouvrir).
2. OBS → **Outils → Scripts → +** → sélectionnez `obs_font_bridge.lua`.
3. **Sources → + → Texte (Bridge)**.

## Mode débogage
Cochez **Mode débogage** dans les réglages du script : un petit bonus s'y cache.

## Désinstallation
Retirez le script dans **Outils → Scripts** (sélection, puis **−**), fermez OBS, puis lancez `Safe_Uninstaller.bat`. Il indique le rôle de chaque fichier, vous laisse choisir quoi supprimer, sauvegarde vos réglages, explique le passage à un autre PC et envoie le tout à la Corbeille.

Nécessite OBS 28+ (obs-websocket v5 intégré) sous Windows.

Auteur : ChromeBread feat. BlackDream ・ Licence : GPL-2.0

Ce script tiers n'est pas officiel. Il n'est ni affilié au projet OBS ni approuvé par celui-ci.

## Mises à jour

Ce logiciel ne vérifie pas les mises à jour et ne se met pas à jour tout seul, et aucune fonction de mise à jour automatique connectée à Internet n'est prévue. Pour mettre à jour, suivez le lien du développeur et téléchargez vous-même la nouvelle version sur le site de distribution : [Releases](../../releases)
