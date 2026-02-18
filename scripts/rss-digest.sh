#!/usr/bin/env bash
# rss-digest.sh — RSS digest wrapper around blogwatcher CLI for OpenClaw
set -euo pipefail

# --- Config via env ---
BLOGWATCHER_CMD="${BLOGWATCHER_CMD:-blogwatcher}"
BLOGWATCHER_CONFIG="${BLOGWATCHER_CONFIG:-$HOME/.config/blogwatcher/config.toml}"
LOG_FILE="${RSS_DIGEST_LOG:-$HOME/logs/rss-digest.log}"
STATE_FILE="${RSS_DIGEST_STATE:-$HOME/.openclaw-rss-digest-state.json}"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-text}"
DRY_RUN="${DRY_RUN:-false}"
MAX_ITEMS="${MAX_ITEMS:-20}"

# Category emojis
declare -A CATEGORY_EMOJI=(
  ["crypto"]="🪙"
  ["dev"]="💻"
  ["ai"]="🤖"
  ["security"]="🔒"
  ["tech"]="⚙️"
  ["news"]="📰"
  ["finance"]="💰"
  ["design"]="🎨"
  ["other"]="📎"
)

mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$STATE_FILE")"

log() { echo "[$(date -Iseconds)] $*" >> "$LOG_FILE"; }

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --json) OUTPUT_FORMAT=json ;;
    --help|-h)
      echo "Usage: rss-digest.sh [--dry-run] [--json]"
      echo "  Env: BLOGWATCHER_CMD, BLOGWATCHER_CONFIG, MAX_ITEMS"
      exit 0 ;;
  esac
done

# Check blogwatcher
if ! command -v "$BLOGWATCHER_CMD" &>/dev/null; then
  MSG="blogwatcher CLI not found at: $BLOGWATCHER_CMD"
  log "ERROR: $MSG"
  if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    jq -n --arg e "$MSG" '{status:"error",error:$e}'
  else
    echo "❌ $MSG"
  fi
  exit 1
fi

# Run blogwatcher scan
log "Running blogwatcher scan..."
SCAN_OUTPUT=$("$BLOGWATCHER_CMD" scan --config "$BLOGWATCHER_CONFIG" --json 2>/dev/null) || {
  # Fallback: try without --json flag
  SCAN_OUTPUT=$("$BLOGWATCHER_CMD" scan --config "$BLOGWATCHER_CONFIG" 2>/dev/null) || {
    MSG="blogwatcher scan failed"
    log "ERROR: $MSG"
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
      jq -n --arg e "$MSG" '{status:"error",error:$e}'
    else
      echo "❌ $MSG"
    fi
    exit 1
  }
}

# Try to parse as JSON
ITEMS="[]"
if echo "$SCAN_OUTPUT" | jq empty 2>/dev/null; then
  ITEMS="$SCAN_OUTPUT"
else
  # Parse text output: each line as an item
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    ITEMS=$(echo "$ITEMS" | jq --arg l "$line" '. + [{title:$l, category:"other", url:"", source:""}]')
  done <<< "$SCAN_OUTPUT"
fi

# Load state to filter already-seen items
if [[ -f "$STATE_FILE" ]]; then
  PREV_STATE=$(cat "$STATE_FILE")
  SEEN_URLS=$(echo "$PREV_STATE" | jq -r '.seen_urls // [] | .[]' 2>/dev/null || echo "")
else
  SEEN_URLS=""
fi

# Filter new items
NEW_ITEMS="[]"
SEEN_SET=$(echo "$SEEN_URLS" | sort -u)

ITEM_COUNT=$(echo "$ITEMS" | jq 'length')
for i in $(seq 0 $((ITEM_COUNT - 1))); do
  URL=$(echo "$ITEMS" | jq -r ".[$i].url // .[$i].link // \"item_$i\"")
  if ! echo "$SEEN_SET" | grep -qF "$URL" 2>/dev/null; then
    ITEM=$(echo "$ITEMS" | jq ".[$i]")
    NEW_ITEMS=$(echo "$NEW_ITEMS" | jq --argjson item "$ITEM" '. + [$item]')
  fi
done

# Cap items
NEW_ITEMS=$(echo "$NEW_ITEMS" | jq ".[0:$MAX_ITEMS]")
NEW_COUNT=$(echo "$NEW_ITEMS" | jq 'length')

# Update state
if [[ "$DRY_RUN" != "true" && "$NEW_COUNT" -gt 0 ]]; then
  NEW_URLS=$(echo "$NEW_ITEMS" | jq -r '.[].url // .[].link // empty')
  ALL_URLS=$(printf "%s\n%s" "$SEEN_URLS" "$NEW_URLS" | tail -500)
  jq -n --arg urls "$ALL_URLS" '{seen_urls: ($urls | split("\n") | map(select(length > 0)))}' > "$STATE_FILE"
fi

# Format output
if [[ "$OUTPUT_FORMAT" == "json" ]]; then
  jq -n \
    --argjson items "$NEW_ITEMS" \
    --argjson count "$NEW_COUNT" \
    '{status:"ok", new_items:$count, items:$items}'
else
  if [[ "$NEW_COUNT" -eq 0 ]]; then
    echo "✅ RSS Digest: No new items"
  else
    echo "📰 RSS Digest: $NEW_COUNT new item(s)"
    echo ""

    # Group by category
    CATEGORIES=$(echo "$NEW_ITEMS" | jq -r '.[].category // "other"' | sort -u)
    for cat in $CATEGORIES; do
      EMOJI="${CATEGORY_EMOJI[$cat]:-📎}"
      echo "$EMOJI ${cat^}"
      echo "$NEW_ITEMS" | jq -r --arg c "$cat" '
        .[] | select((.category // "other") == $c) |
        "  • \(.title // "Untitled")\(if .url then " — \(.url)" else "" end)"
      '
      echo ""
    done
  fi
fi

log "Digest complete: $NEW_COUNT new items"
