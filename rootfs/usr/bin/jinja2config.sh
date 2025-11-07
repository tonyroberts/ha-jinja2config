#!/command/with-contenv bashio
HASS_CONFIG_DIR=$(bashio::config 'config_dir')
CUSTOMIZE_FILE="/usr/bin/generate_jinja_customization.py"

if ! type j2 > /dev/null 2>&1; then
  echo "j2cli must be installed: pip install j2cli (https://pypi.org/project/j2cli/)"
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
  echo "# DO NOT EDIT: Generated from: $2" > "$OUTPUT_FILE"
  # Log any errors to an .errors.log file, delete if successful
  if j2 --customize "$CUSTOMIZE_FILE" "$1$2" >> "$OUTPUT_FILE" 2> "$ERROR_LOG_FILE"; then
    (rm -f "$ERROR_LOG_FILE" || true)
    echo "Formatting $OUTPUT_FILE with Prettier..."
    prettier --write "$OUTPUT_FILE" --log-level warn || true
  else
    (rm -f "$OUTPUT_FILE" || true)
    echo "Error compiling $1$2!"
    if [ -f "$ERROR_LOG_FILE" ]; then cat "$ERROR_LOG_FILE" >&2; fi
  fi
}

echo "Compiling Jinja templates to YAML: $HASS_CONFIG_DIR/**/*.yaml.jinja"
inotifywait -q -m -r -e modify,delete,create,move "$HASS_CONFIG_DIR" | while read DIRECTORY EVENT FILE; do
  if [[ "$FILE" != *.yaml.jinja ]]; then continue; fi

  case $EVENT in
    MODIFY*)
      compile "$DIRECTORY" "$FILE";;
    CREATE*)
      compile "$DIRECTORY" "$FILE";;
    MOVED_TO*)
      compile "$DIRECTORY" "$FILE";;
    DELETE*)
      remove "$DIRECTORY" "$FILE";;
    MOVED_FROM*)
      remove "$DIRECTORY" "$FILE";;
  esac
  sleep 0.5
done

sleep 1
