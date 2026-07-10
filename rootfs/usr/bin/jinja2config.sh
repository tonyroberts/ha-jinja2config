#!/command/with-contenv bashio
HASS_CONFIG_DIR=$(bashio::config 'config_dir')

if ! type j2 > /dev/null 2>&1; then
  echo "jinjanator must be installed: pip install jinjanator (https://github.com/kpfleming/jinjanator)"
  sleep 1
  exit 1
fi
if ! type prettier > /dev/null 2>&1; then
  echo "Prettier must be installed: apt-get install nodejs npm && npm install -g prettier"
  sleep 1
  exit 1
fi

remove() {
  OUTPUT_FILE="$1${2/.jinja}"
  echo "$1$2 deleted, removing: $OUTPUT_FILE"
   rm -f "$OUTPUT_FILE"
}

compile() {
  echo "$1$2 changed, compiling to: $1${2/.jinja}"
  ERROR_LOG_FILE="$1$2.errors.log"
  OUTPUT_FILE="$1${2/.jinja}"
  TEMP_OUTPUT_FILE="${OUTPUT_FILE}.tmp"

  echo "# DO NOT EDIT: Generated from: $2" > "$TEMP_OUTPUT_FILE"
  # Log any errors to an .errors.log file, delete if successful
  # Use j2 with customize file and no data
  if j2 --customize /etc/jinja2config/j2_customizations.py "$1$2" >> "$TEMP_OUTPUT_FILE" 2> "$ERROR_LOG_FILE"; then
    mv "$TEMP_OUTPUT_FILE" "$OUTPUT_FILE"
    (rm -f "$ERROR_LOG_FILE" || true)
    echo "Formatting $OUTPUT_FILE with Prettier..."
    prettier --write "$OUTPUT_FILE" --log-level warn || true
  else
    (rm -f "$TEMP_OUTPUT_FILE" || true)
    (rm -f "$OUTPUT_FILE" || true)
    echo "Error compiling $1$2!"
    if [ -f "$ERROR_LOG_FILE" ]; then cat "$ERROR_LOG_FILE" >&2; fi
  fi
}

# Recompile every *.yaml.jinja file that (transitively) imports $1.
recompile_dependents() {
  local changed="$1"
  local dependent
  python3 /etc/jinja2config/find_dependents.py "$changed" "$HASS_CONFIG_DIR" | while read -r dependent; do
    [ -z "$dependent" ] && continue
    echo "$changed changed, recompiling dependent: $dependent"
    compile "$(dirname "$dependent")/" "$(basename "$dependent")"
  done
}

echo "Compiling Jinja templates to YAML: $HASS_CONFIG_DIR/**/*.yaml.jinja"
inotifywait -q -m -r -e modify,delete,create,move "$HASS_CONFIG_DIR" | while read DIRECTORY EVENT FILE; do
  # Watch every *.jinja (partials included), but skip generated side-files.
  if [[ "$FILE" != *.jinja ]]; then continue; fi

  case $EVENT in
    MODIFY*|CREATE*|MOVED_TO*)
      # *.yaml.jinja compiles to its own .yaml; plain partials do not.
      if [[ "$FILE" == *.yaml.jinja ]]; then compile "$DIRECTORY" "$FILE"; fi
      recompile_dependents "$DIRECTORY$FILE";;
    DELETE*|MOVED_FROM*)
      if [[ "$FILE" == *.yaml.jinja ]]; then remove "$DIRECTORY" "$FILE"; fi
      recompile_dependents "$DIRECTORY$FILE";;
  esac
  sleep 0.5
done

sleep 1
