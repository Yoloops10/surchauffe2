#!/usr/bin/env bash
# Exporte build/Surchauffe.apk (debug, signé avec le keystore debug).
# Prérequis : voir README.md (JDK 17, Android SDK, export templates 4.4.1).
# Variables optionnelles : GODOT (binaire), ANDROID_HOME (SDK).
set -euo pipefail

cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"
KEYSTORE="${DEBUG_KEYSTORE:-$HOME/.android/debug.keystore}"

command -v "$GODOT" >/dev/null || { echo "Godot introuvable : export GODOT=/chemin/vers/godot"; exit 1; }
command -v java >/dev/null || { echo "JDK 17 introuvable (java absent du PATH)"; exit 1; }
command -v keytool >/dev/null || { echo "keytool introuvable (JDK incomplet)"; exit 1; }
[ -d "$SDK/platform-tools" ] || { echo "Android SDK introuvable dans $SDK (définir ANDROID_HOME)"; exit 1; }

# Keystore debug : créé s'il n'existe pas.
if [ ! -f "$KEYSTORE" ]; then
  mkdir -p "$(dirname "$KEYSTORE")"
  keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android \
    -keystore "$KEYSTORE" -storepass android -dname "CN=Android Debug,O=Android,C=US" \
    -validity 9999 -deststoretype pkcs12
fi

# Chemins de l'éditeur Godot (SDK, JDK, keystore) — fichier de réglages 4.x
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$KEYSTORE"
export GODOT_ANDROID_KEYSTORE_DEBUG_USER="androiddebugkey"
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="android"

SETTINGS="${XDG_CONFIG_HOME:-$HOME/.config}/godot/editor_settings-4.4.tres"
if [ ! -f "$SETTINGS" ]; then
  mkdir -p "$(dirname "$SETTINGS")"
  printf '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n' > "$SETTINGS"
fi
JAVA_HOME_GUESS="${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")}"
for kv in "export/android/android_sdk_path=\"$SDK\"" \
          "export/android/java_sdk_path=\"$JAVA_HOME_GUESS\"" \
          "export/android/debug_keystore=\"$KEYSTORE\"" \
          "export/android/debug_keystore_user=\"androiddebugkey\"" \
          "export/android/debug_keystore_pass=\"android\""; do
  key="${kv%%=*}"
  sed -i "/^$(printf '%s' "$key" | sed 's/[\/&]/\\&/g')=/d" "$SETTINGS"
  echo "$kv" >> "$SETTINGS"
done

mkdir -p build
"$GODOT" --headless --import
"$GODOT" --headless --export-debug "Android" build/Surchauffe.apk
echo "OK : build/Surchauffe.apk"
