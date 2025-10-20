#!/usr/bin/env bash
# Normalize NFL team logos into helmet-style circular chips with contrasting backgrounds
# Requires ImageMagick (convert, identify) and curl
# Usage: ./normalize_logos.sh <output_dir>

set -euo pipefail

OUT_DIR=${1:-"./assets/normalized_logos"}
mkdir -p "$OUT_DIR"

# List of example team abbreviations - expand as needed
TEAMS=(
  ari atl bal buf car chi cin cle dal den det gb hou ind jax kc
  lac la mia min ne no nyg nyj phi pit sf sea tb ten was
)

# helper: compute average brightness using ImageMagick's -format "%[mean]"
function brightness() {
  local file=$1
  # mean is 0..QuantumRange; normalize to 0..1
  local mean=$(convert "$file" -colorspace Gray -format "%[fx:mean]" info:)
  echo "$mean"
}

for team in "${TEAMS[@]}"; do
  echo "Processing: $team"
  url="https://sleepercdn.com/images/team_logos/nfl/${team}.png"
  tmp="/tmp/${team}_logo.png"
  curl -sSf -o "$tmp" "$url" || { echo "Failed to download $url"; continue; }

  # Ensure transparency handled; resize to a standard size
  convert "$tmp" -resize 80x80 -background none -gravity center \
    -extent 80x80 "/tmp/${team}_resized.png"

  mean=$(brightness "/tmp/${team}_resized.png")
  # If mean is low (dark), use white bg, else dark bg
  bg="white"
  if (( $(echo "$mean < 0.5" | bc -l) )); then
    bg="white"
  else
    bg="#222222"
  fi

  out="$OUT_DIR/${team}_helmet.png"
  # Create circular helmet background
  convert -size 80x80 xc:none -fill "$bg" -draw "circle 40,40 40,4" \
    -blur 0x0 -shadow 0x0+0+0 "/tmp/${team}_bg.png"

  # Composite the logo centered over the background
  convert "/tmp/${team}_bg.png" "/tmp/${team}_resized.png" -gravity center -composite "$out"

  # Add a thin contrasting stroke
  convert "$out" -alpha set -bordercolor "rgba(0,0,0,0.2)" -border 1 "$out"

  echo "Wrote $out (mean=$mean, bg=$bg)"
done

echo "Done. Normalized logos in $OUT_DIR"