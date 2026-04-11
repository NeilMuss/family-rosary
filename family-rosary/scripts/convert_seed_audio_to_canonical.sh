#!/bin/zsh
set -euo pipefail

# Batch-convert prayer speech assets to the app's canonical managed format:
# AAC in .m4a, 24 kHz, mono, 48 kbps. This is tuned for spoken voice.
#
# Usage:
#   ./scripts/convert_seed_audio_to_canonical.sh /path/to/input_dir /path/to/output_dir

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 INPUT_DIR OUTPUT_DIR" >&2
  exit 1
fi

input_dir="$1"
output_dir="$2"

if [[ ! -d "$input_dir" ]]; then
  echo "Input directory does not exist: $input_dir" >&2
  exit 1
fi

mkdir -p "$output_dir"

if ! command -v afconvert >/dev/null 2>&1; then
  echo "afconvert is required but was not found on PATH." >&2
  exit 1
fi

find "$input_dir" -type f | sort | while IFS= read -r source_path; do
  source_name="$(basename "$source_path")"
  source_stem="${source_name%.*}"
  output_path="$output_dir/$source_stem.m4a"

  echo "Converting $source_name -> $(basename "$output_path")"
  afconvert \
    -f m4af \
    -d aac \
    -b 48000 \
    -c 1 \
    -r 24000 \
    "$source_path" \
    "$output_path"
done

echo "Canonical audio written to $output_dir"
