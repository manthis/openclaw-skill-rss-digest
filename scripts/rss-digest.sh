#!/usr/bin/env bash
# rss-digest.sh — RSS digest wrapper around blogwatcher CLI for OpenClaw
#
# Performance notes:
# - Seen-URL filtering done in single jq call (was O(n²) grep-in-loop)
# - Category grouping done in jq instead of shell loop
set -euo pipefail

BLOGWATCHER_CMD="${BLOGWATCHER_CMD:-blogwatcher}"
BLOGWATCHER_CONFIG="${BLOGWATCHER_CONFIG:-$HOME/.config/blogwatcher/config.toml}"
LOG_FILE="${RSS_DIGEST_LOG:-$HOME/logs/rss-digest.log}"
STATE_FILE="${RSS_DIGEST_STATE:-$HOME/.openclaw-rss-digest-state.json}"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-text}"
DRY_RUN="${DRY_RUN:-false}"
MAX_ITEMS="${MAX_ITEMS:-20}"

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

log "Running blogwatcher scan..."
SCAN_OUTPUT=$("$BLOGWATCHER_CMD" scan --config "$BLOGWATCHER_CONFIG" --json 2>/dev/null) || {
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

# Parse items
ITEMS="[]"
if echo "$SCAN_OUTPUT" | jq empty 2>/dev/null; then
  ITEMS="$SCAN_OUTPUT"
else
  ITEMS=$(echo "$SCAN_OUTPUT" | jq -R -s '[split("\n")[] | select(length > 0) | {title:., category:"other", url:"", source:""}]')
fi

# Load seen URLs
SEEN_URLS="[]"
if [[ -f "$STATE_FILE" ]]; then
  SEEN_URLS=$(jq -r '.seen_urls // []' "$STATE_FILE" 2>/dev/null || echo "[]")
fi

# Filter new items + cap in single jq call (was O(n²) grep loop)
NEW_ITEMS=$(jq -n \
  --argjson items "$ITEMS" \
  --argjson seen "$SEEN_URLS" \
  --argjson max "$MAX_ITEMS" '
  ($seen | map(select(length > 0)) | INDEX(.; .)) as $seen_set |
  [$items[] | 
    (.url // .link // ("item_" + (. | tojson | length | tostring))) as $url |
    select($seen_set[$url] == null)
  ] | .[0:$max]
')

NEW_COUNT=$(echo "$NEW_ITEMS" | jq 'length')

# Update state
if [[ "$DRY_RUN" != "true" && "$NEW_COUNT" -gt 0 ]]; then
  jq -n \
    --argjson seen "$SEEN_URLS" \
    --argjson new_items "$NEW_ITEMS" '
    {seen_urls: (
      [$seen[], ($new_items[] | .url // .link // empty)] |
      map(select(length > 0)) |
      .[-500:]
    )}
  ' > "$STATE_FILE"
fi

# Output
if [[ "$OUTPUT_FORMAT" == "json" ]]; then
  jq -n --argjson items "$NEW_ITEMS" --argjson count "$NEW_COUNT" \
    '{status:"ok", new_items:$count, items:$items}'
else
  if [[ "$NEW_COUNT" -eq 0 ]]; then
    echo "✅ RSS Digest: No new items"
  else
    echo "📰 RSS Digest: $NEW_COUNT new item(s)"
    echo ""
    # Category emoji mapping + grouping in single jq call
    echo "$NEW_ITEMS" | jq -r '
      def cat_emoji:
        {"crypto":"🪙","dev":"💻","ai":"🤖","security":"🔒","tech":"⚙️",
         "news":"📰","finance":"💰","design":"🎨"}[.] // "📎";
      group_by(.category // "other") | .[] |
      (.[0].category // "other") as $cat |
      "\($cat | cat_emoji) \($cat | .[0:1] | ascii_upcase)\($cat[1:])",
      (.[] | "  • \(.title // "Untitled")\(if .url and .url != "" then " — \(.url)" else "" end)"),
      ""
    '
  fi
fi

log "Digest complete: $NEW_COUNT new items"
