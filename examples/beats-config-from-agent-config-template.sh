#!/bin/bash

# Help message
usage() {
  echo "Usage: $0 -t <template_file> -v <variables_file> -c <cel_input_file> -o <output_file>"
  echo
  echo "  -t  Path and name to agent configuration template file (e.g., cel.yml.hbs)"
  echo "  -v  Path and name to YAML file with replacement values for handlebar variables"
  echo "  -c  Path and name to filebeat cel input file to append cel script information"
  echo "  -o  Path and name to output beats configuration file"
  echo "  -m  (Optional) Run a check using mito. --dump option (always | error)"
  echo "  -h  Show help"
  echo
  echo "Example:"
  echo "  $0 -t cel.yml.hbs -v values.yml -c cel_input_partial.yml -o beats-config.yml -m (always|error)"
  exit 1
}

# Parse command-line switches
while getopts "t:v:c:o:m:h" opt; do
  case ${opt} in
    t ) TEMPLATE_FILE="$OPTARG" ;;
    v ) VARIABLES_FILE="$OPTARG" ;;
    c ) CEL_INPUT_FILE="$OPTARG" ;;
    o ) OUTPUT_FILE="$OPTARG" ;;
    m)
        if [[ "$OPTARG" != "always" && "$OPTARG" != "error" ]]; then
          echo "Error: Invalid value for -m. Expected 'always' or 'error'."
          usage
        fi
        MITO_DUMP="$OPTARG"
        ;;
    h ) usage ;;
    \? ) usage ;;
  esac
done

# Validate required args
if [ -z "$TEMPLATE_FILE" ] || [ -z "$VARIABLES_FILE" ] || [ -z "$OUTPUT_FILE" ] || [ -z "$CEL_INPUT_FILE" ] ; then
  echo "Error: Options -t, -v, -c and -o are required."
  usage
fi

# Check for required tools
if ! command -v yq >/dev/null 2>&1; then
  echo "Error: 'yq' is required but not installed. Install it: https://github.com/mikefarah/yq"
  exit 1
fi

if ! command -v mustache >/dev/null 2>&1; then
  echo "Error: 'mustache' is required but not installed. Install with: npm install -g mustache"
  exit 1
fi

if ! command -v perl >/dev/null 2>&1; then
  echo "Error: 'perl' is required but not installed."
  exit 1
fi

if ! command -v mito >/dev/null 2>&1; then
  echo "Error: 'mito' is required but not installed."
  exit 1
fi

# Convert YAML to JSON so mustache can use it
TMP_JSON=$(mktemp)
yq -o=json '.' "$VARIABLES_FILE" > "$TMP_JSON"

# Render template
# replace {{ }} handlebars variables in the template file with the
# definitions in the json variables file.
# mustache encodes urls to hex. Pipe to perl to decode them.
# Pipe to yq to merge the result into the cel input file for use by filebeat
mustache "$TMP_JSON" "$TEMPLATE_FILE" | perl -CSD -pe 's/&#x([0-9a-fA-F]+);/chr(hex($1))/ge' | yq eval-all '
  select(fileIndex == 0) as $patch |
  select(fileIndex == 1) as $base |
  ($base.[] | to_entries | map(select(.value.type == "cel")) | .[0].key) as $i |
  $base.[$i] *= $patch |
  $base
' - $CEL_INPUT_FILE > $OUTPUT_FILE

echo "✅ Beats config written to: $OUTPUT_FILE"

if [[ -n "${MITO_DUMP+x}" ]]; then
  echo "Checking with mito"
  mito -dump $MITO_DUMP -data <(yq eval '(.[] | .state.url = .["resource.url"] | .state) ' -o=json $OUTPUT_FILE) <(yq '.[].program' $OUTPUT_FILE)
fi

# Cleanup
rm "$TMP_JSON"

