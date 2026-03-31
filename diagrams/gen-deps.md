# gen-deps — Dependency Tab Generator

Generates `tab-dependencies.html` from `roadmap-deps.json`.
**Never edit the HTML by hand** — edit the JSON, run the generator.

---

## Quick start

```bash
# Regenerate from JSON
python3 diagrams/gen-deps.py

# Sync issue statuses from GitHub, then regenerate
python3 diagrams/gen-deps.py --github-sync

# Build + deploy to Cloudflare
make diagrams deploy          # runs gen-deps.py automatically
```

---

## Files

| File | Location | Purpose |
|------|----------|---------|
| `roadmap-deps.json` | `~/.agent/lyra/visuals/deps/` | Single source of truth |
| `gen-deps.py` | `diagrams/` | Generator script |
| `tab-dependencies.html` | `~/.agent/lyra/visuals/tabs/lyra-status/` | Generated output |

---

## JSON schema

### `_meta`

```json
{
  "_meta": {
    "updated": "2026-03-31",
    "total_tracked": 57,
    "source": "Roxabi/lyra GitHub",
    "done_visible_days": 7
  }
}
```

`done_visible_days` — closed issues older than this are status `done_old` and hidden from diagrams.

---

### `phases`

```json
{
  "phases": [
    { "id": "ph1",  "name": "Intelligence",  "color": "#a855f7" },
    { "id": "ph3a", "name": "Memory",        "color": "#a855f7", "note": "blocked" }
  ]
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `id` | ✓ | Unique ID — used in `issues[].phase`. Convention: `ph0`…`ph5`, `ph3a`/`ph3b`/`ph3c` for sub-phases |
| `name` | ✓ | Display name |
| `color` | ✓ | Hex color for phase header border |
| `note` | | Small badge appended to the header (e.g. `"mostly done"`) |

---

### `domains`

Color palette for issue domains. Used to style nodes in Mermaid diagrams.

```json
{
  "domains": {
    "nats":     { "fill": "#e85d04", "text": "#fff", "stroke": "#c2410c" },
    "voice":    { "fill": "#06b6d4", "text": "#fff", "stroke": "#0891b2" },
    "memory":   { "fill": "#a855f7", "text": "#fff", "stroke": "#7e22ce" },
    "autonomy": { "fill": "#f59e0b", "text": "#fff", "stroke": "#d97706" },
    "brand":    { "fill": "#ec4899", "text": "#fff", "stroke": "#be185d" },
    "security": { "fill": "#ef4444", "text": "#fff", "stroke": "#b91c1c" }
  }
}
```

---

### `issues`

The core of the data model. Each issue is a node in the dependency graph.

```json
{
  "issues": [
    {
      "id":             "477",
      "phase":          "ph1",
      "label":          "#477 Tool registry + MCP",
      "status":         "open",
      "domain":         "memory",
      "closed_days_ago": null,
      "blocked_by":     [],
      "blocks":         ["478", "mcp-client"]
    }
  ]
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `id` | ✓ | Unique string. Use the GitHub issue number for real issues, a slug for virtual ones (`"vault-graph"`, `"mcp-client"`) |
| `phase` | ✓ | Phase ID this issue belongs to |
| `label` | ✓ | Display text in Mermaid nodes and cards |
| `status` | ✓ | See status values below |
| `domain` | | Key from `domains` — controls node color |
| `closed_days_ago` | | Set by `--github-sync`. Informational only |
| `blocked_by` | | List of issue IDs that must complete before this one. **Drives all dep arrows** |
| `blocks` | | Inverse of `blocked_by` — what this issue unlocks. Can be set instead of or alongside `blocked_by` |

#### Status values

| Value | Appearance | When to use |
|-------|-----------|-------------|
| `open` | Domain color (solid) | Normal open issue |
| `done_recent` | Dark gray, dashed border | Closed within `done_visible_days` |
| `done_old` | **Hidden** from diagram | Closed > `done_visible_days` ago |
| `deferred` | Amber, dashed border | Explicitly postponed (e.g. Slice C ADR-021) |
| `external` | Red, solid | External dep from another repo/project |
| `virtual` | Dark purple, dashed | Concept with no GitHub issue yet |

#### Cross-phase deps — how they work

The generator inspects every issue's `blocked_by` and `blocks` lists:

- If a blocker is in a **different phase** → rendered as an **incoming ghost node** (`← PhX #N label`) at the top of the current phase diagram
- If a blocked issue is in a **different phase** → rendered as an **outgoing ghost node** (`→ PhX #N label`) at the bottom

Ghost nodes use the indigo dashed style and are auto-generated — no HTML to write.

The **incoming dep banner** (text above the phase header) is also auto-derived from cross-phase `blocked_by` relationships.

---

### `chains`

Progress cards shown in the "Progress by Chain" section.

```json
{
  "chains": [
    {
      "id":         "nats",
      "label":      "NATS Chain",
      "color":      "#e85d04",
      "issues":     ["447", "448", "455", "456", "457", "458", "459"],
      "next_note":  "#458 Rewire Adapters — <em>deferred</em>"
    }
  ]
}
```

| Field | Description |
|-------|-------------|
| `id` | Unique chain ID |
| `label` | Card header |
| `color` | Accent color |
| `issues` | Issue IDs in this chain — drives done/open counts and unlock detection |
| `next_note` | HTML string shown as "Next: …" footer |
| `blocked_note` | Shown as "← waiting on: …" with ghost badges. Use `+` to separate items |
| `complete` | `true` → renders a green ✓ complete card |
| `complete_note` | Text for the complete card body |
| `note` | Secondary note below the complete card |
| `done_recent` | List of strings shown as recently closed items (for Ops-style cards) |

**Unlock rows** are auto-generated: if any issue in `issues` has a `blocks` entry pointing to an issue outside this chain, a `↳ when X done: PhY #N …` row appears automatically.

---

### `critical_paths`

Badge chains shown in the "Critical Paths" section.

```json
{
  "critical_paths": [
    {
      "label": "NATS (longest chain)",
      "steps": [
        { "id": "455", "status": "done" },
        { "id": "458", "status": "deferred", "label": "#458 Adapters" },
        { "label": "#460/#461/#462", "status": "planned" }
      ]
    }
  ]
}
```

Step `status` values: `done`, `planned`, `deferred`, `north-star`.
`label` overrides the issue label when set. `id` looks up the issue automatically.

---

## What the generator handles automatically

You never touch the HTML. The generator derives everything from `roadmap-deps.json`:

| Derived output | Source |
|----------------|--------|
| Cross-phase ghost nodes (incoming + outgoing) | `blocked_by` / `blocks` across phases |
| Incoming dep banners (text above phase header) | Cross-phase `blocked_by` relationships |
| Done styling (`done_recent` vs `done_old`) | `status` + `closed_days_ago` vs `done_visible_days` |
| Deferred styling (amber, dashed) | `"status": "deferred"` |
| Virtual nodes (dark purple, dashed, "No issue yet") | `"status": "virtual"` |
| Progress cards with unlock rows | `blocks` pointing to issues outside the chain |
| Legend, footer counts | Aggregated from all issues |

---

## Common operations

### Mark an issue as done

```json
{ "id": "477", ..., "status": "done_recent", "closed_days_ago": 0 }
```

Or just run `--github-sync` and it's automatic.

### Add a new issue

```json
{
  "id": "482",
  "phase": "ph3a",
  "label": "#482 My new issue",
  "status": "open",
  "domain": "memory",
  "blocked_by": ["166"],
  "blocks": []
}
```

The generator will automatically:
- Place it in the Phase 3a Mermaid diagram
- Draw an arrow from `#166 Memory L1-L3` to it
- Add `#166` as an incoming ghost node if #166 is in a different phase (it's not here, so direct arrow)

### Add a virtual issue (no GitHub number yet)

```json
{
  "id": "my-concept",
  "phase": "ph3a",
  "label": "My concept",
  "status": "virtual",
  "domain": "memory",
  "blocked_by": ["166"]
}
```

Renders with dark purple dashed border and a "No issue yet" legend entry.

### Defer an issue

```json
{ "id": "458", ..., "status": "deferred" }
```

### Add a new phase

```json
{ "id": "ph3d", "name": "Data Pipelines", "color": "#84cc16" }
```

Then set `"phase": "ph3d"` on relevant issues. The generator picks up the new phase in insertion order.

---

## GitHub sync

```bash
python3 diagrams/gen-deps.py --github-sync
```

Calls `gh issue list --state all` in `~/projects/lyra`, compares close dates against `done_visible_days`, and updates `status` + `closed_days_ago` in the JSON in-place. Then run the generator normally.

Automate it:
```bash
python3 diagrams/gen-deps.py --github-sync && make diagrams deploy
```
