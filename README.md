# 📰 openclaw-skill-rss-digest

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![OpenClaw Skill](https://img.shields.io/badge/OpenClaw-Skill-blue)](https://github.com/OpenAgentsInc/openclaw)

RSS digest wrapper around `blogwatcher` CLI for OpenClaw. Scans feeds, formats by category with emojis, deduplicates.

## Quick Start

```bash
git clone https://github.com/manthis/openclaw-skill-rss-digest.git
cd openclaw-skill-rss-digest

export BLOGWATCHER_CMD="blogwatcher"
./scripts/rss-digest.sh --dry-run
```

## ⚡ Performance

Recent optimizations (2026-02-18):

- 🚀 **O(n²) → O(n)** — Replaced nested loops for deduplication with `jq INDEX` for constant-time lookups
- 📉 **Reduced process spawns** — Consolidated multiple `jq` filter passes into a single pipeline
- 🎯 **Complexity improvement** — Deduplication now scales linearly regardless of feed size

These optimizations are especially noticeable with large feed collections (50+ feeds, hundreds of items).

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `BLOGWATCHER_CMD` | `blogwatcher` | CLI path |
| `BLOGWATCHER_CONFIG` | `~/.config/blogwatcher/config.toml` | Config |
| `MAX_ITEMS` | `20` | Max items per digest |

> ⚠️ **Security:** Config paths may contain sensitive feed URLs. Keep them out of version control.

## Features

- 🏷️ Category formatting (🪙 Crypto, 💻 Dev, 🤖 AI, etc.)
- 🔄 Deduplication via state tracking
- 📊 JSON output for automation
- 🧢 Configurable item cap
- 📋 Text and JSON output modes

## Requirements

- [blogwatcher](https://github.com/nichochar/blogwatcher) CLI
- `jq`

## License

MIT
