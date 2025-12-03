#!/bin/bash

# Help message
usage() {
  echo "Usage: $0 -t <template_file> -v <variables_file> -c <cel_input_file> -o <output_file>"
  echo "  -e  Path and name of example to run  (default is current directory)"
  echo "  -t  Path and name to agent configuration template file (default <example-name>/cel.yml.hbs)"
  echo "  -v  Path and name to YAML file with replacement values for handlebar variables (default <example-name>/variables.yml)"
  echo "  -c  Path and name to filebeat cel input file to append cel script information (default <example-name>/../scripts/filebeat-cel-input-base.yml)"
  echo "  -o  Path and name to output beats configuration file (default <example-name>/filebeat/inputs.d/test.yml)"
  echo "  -m  (Optional) Run a check using mito option (always | error)"
  echo "  -h  Show help"
  echo
  echo "Run from the directory where the example is to use defaults"
  echo "Use default values"
  echo "  $0"
  echo "Run example from a different directory but use defaults"
  echo "  $0 -e ./example_name"
  echo  "To run from another directory or to use other file paths relative to example directory "
  echo "  $0 -e ./example_name -t cel_mod_2.yml.hbs -v other_variables.yml -c ../scripts/filebeat-cel-input-base.yml -o filebeat/inputs.d/new-cel-inputs-name.yml -m (always|error)"
  exit 1
}

# Default values
RUN_LOCATION="$(pwd)"
EXAMPLE_DIR="$(pwd)"
TEMPLATE_FILE="cel.yml.hbs"
VARIABLES_FILE="variables.yml"
CEL_INPUT_FILE="../../scripts/filebeat-cel-input-base.yml"
OUTPUT_FILE="./filebeat/inputs.d/test.yml"
# Parse command-line switches
while getopts "e:t:v:c:o:m:h" opt; do
  case ${opt} in
    e ) EXAMPLE_DIR="$OPTARG" ;;
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

# Check for required tools
if ! command -v yq >/dev/null 2>&1; then
  echo "Error: 'yq' is required but not installed. Install it: https://github.com/mikefarah/yq"
  exit 1
fi

if ! command -v handlebars >/dev/null 2>&1; then
  echo "Error: 'handlebars' is required but not installed. Install with: npm install -g handlebars"
  exit 1
fi

if ! command -v mito >/dev/null 2>&1; then
  echo "Error: 'mito' is required but not installed. Install with 'go install github.com/elastic/mito/cmd/mito@<version>'"
  exit 1
fi

SCRIPT_LOC=$(dirname -- "$0")

# generate the directory for the generated filebeat configuration file
mkdir -p $(dirname $EXAMPLE_DIR/$OUTPUT_FILE)

# Convert YAML to JSON so handlebars can use it
TMP_JSON=$(mktemp)
yq -o=json '.' "$EXAMPLE_DIR/$VARIABLES_FILE" > "$TMP_JSON"

# Render template
# replace {{ }} handlebars variables in the template file with the
# definitions in the json variables file. Then add the input
# data to the filebeat input file skeleton and write out the filebeat input file
node ${SCRIPT_LOC}/render.js "$TMP_JSON" "$EXAMPLE_DIR/$TEMPLATE_FILE" | yq eval-all '
  select(fileIndex == 0) as $patch |
  select(fileIndex == 1) as $base |
  ($base.[] | to_entries | map(select(.value.type == "cel")) | .[0].key) as $i |
  $base.[$i] *= $patch |
  $base
' - $EXAMPLE_DIR/$CEL_INPUT_FILE > $EXAMPLE_DIR/$OUTPUT_FILE

echo "✅ Beats config written to: $EXAMPLE_DIR/$OUTPUT_FILE"

if [[ -n "${MITO_DUMP+x}" ]]; then
  echo "Checking with mito"
  mito -dump $MITO_DUMP -data <(yq eval '(.[] | .state.url = .["resource.url"] | .state) ' -o=json $OUTPUT_FILE) <(yq '.[].program' $EXAMPLE_DIR/$OUTPUT_FILE)
fi

# Cleanup
rm "$TMP_JSON"
