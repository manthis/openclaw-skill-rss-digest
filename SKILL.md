# openclaw-skill-rss-digest

RSS digest wrapper around `blogwatcher` CLI. Scans feeds, formats by category, delivers via OpenClaw.

## Usage

```bash
scripts/rss-digest.sh [--dry-run] [--json]
```

## Configuration (env vars)

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `BLOGWATCHER_CMD` | | `blogwatcher` | Path to blogwatcher CLI |
| `BLOGWATCHER_CONFIG` | | `~/.config/blogwatcher/config.toml` | Config file |
| `MAX_ITEMS` | | `20` | Max items per digest |
| `RSS_DIGEST_STATE` | | `~/.openclaw-rss-digest-state.json` | State file |
| `RSS_DIGEST_LOG` | | `~/logs/rss-digest.log` | Log file |

## Categories

Items are formatted with category emojis:
- 🪙 Crypto
- 💻 Dev
- 🤖 AI
- 🔒 Security
- ⚙️ Tech
- 📰 News
- 💰 Finance
- 🎨 Design

## Dependencies

- `blogwatcher` CLI
- `jq`

## OpenClaw Integration

```yaml
cron:
  - name: "RSS Digest"
    schedule: "0 8,18 * * *"
    command: "scripts/rss-digest.sh --json"
```
