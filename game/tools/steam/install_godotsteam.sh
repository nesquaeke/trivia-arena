#!/usr/bin/env bash
# GodotSteam GDExtension'ı game/addons/godotsteam altına kurar.
# Kullanım: bash game/tools/steam/install_godotsteam.sh [sürüm]
# Sürümü https://github.com/GodotSteam/GodotSteam/releases adresinden seç
# (Godot 4.x için "gdextension" paketi).
set -euo pipefail
VER="${1:-v4.16}"
HERE="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"
URL="https://github.com/GodotSteam/GodotSteam/releases/download/${VER}-gde/godotsteam-${VER#v}-gdextension-plugin-4.4.zip"
echo "İndiriliyor: $URL"
curl -fL "$URL" -o "$TMP/gs.zip" || { echo "İndirilemedi. Sürüm adını releases sayfasından kontrol et ya da Asset Library'den 'GodotSteam GDExtension' kur."; exit 1; }
unzip -q "$TMP/gs.zip" -d "$TMP/x"
mkdir -p "$HERE/addons"
cp -r "$TMP"/x/addons/godotsteam "$HERE/addons/"
echo "Kuruldu: $HERE/addons/godotsteam"
echo "Godot'yu yeniden aç; SteamService otomatik algılar."
