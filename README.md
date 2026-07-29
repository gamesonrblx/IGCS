> [!warning]
> This project may fall within a grey area of the Roblox Terms of Use / Community Standards depending on how you configure and deploy it. Use at your own risk and with caution.
> You are responsible for:
> - Ensuring all chat is properly filtered and moderated
> - Complying with all applicable Roblox policies and safety requirements
> - Handling any user data responsibly (collect as little as possible)
>
> If you are unsure whether your use-case is allowed, review Roblox policy docs and consider getting guidance before publishing.

# IGCS — In-Game Chat System

Open-source and free to use, modify, and redistribute in any form (commercial or non-commercial).  
No credits required.

**v2** keeps the same server chat logic from v1.4 and replaces the visible UI with React-Lua. Global, team, whisper, filtering, bubble chat, and rate limits still run on the existing server module.

## Why this exists

- Lightweight, customizable chat UI with Global / Team tabs and whisper support
- Transparent, auditable flow: filtering on the server, presentation on the client
- Developers control styling and layout without depending on Roblox’s default chat window
- Code-first UI (React-Lua) so you can review and version the interface like any other source file

## Quick start (drop-in model)

The easiest path is the built model in this repo:

1. Download **[`dist/IGCS-v2.rbxmx`](dist/IGCS-v2.rbxmx)** (or grab the **IGCS-v2-rbxmx** artifact from GitHub Actions).
2. In Roblox Studio, import the file into your place (Workspace is fine).
3. Keep this layout:

```text
IGCS
├── Content
│   ├── ChatServer.server      (ModuleScript)  — server chat logic
│   ├── Icon                   (ModuleScript)  — TopbarPlus icon
│   └── IGCS_Client            (ScreenGui)     — React-Lua chat UI
├── Initialise                 (Script)        — installs modules + remotes
└── IGCSConfig                 (ModuleScript)  — shared settings
```

4. Make sure `Initialise` runs on the server. It installs:
   - `Icon` + config into `ReplicatedStorage`
   - `IGCS_Client` into `StarterGui` (so every player gets the UI)
   - remotes into `ReplicatedStorage` (`IGCS_Remotes`)

5. Playtest: click the **IGCS** topbar icon, type a message, send.

That’s it for most games. You do not need Rojo or Wally just to use the built model.

## Chat scopes and commands

| What | How |
|------|-----|
| Global | Type normally (All tab) |
| Team | Team tab, or `/t message` / `/team message` |
| Whisper / PM | `/w player message` or `/pm player message` |
| Emotes | `/e`, `/emote`, and the usual short names |

Notes:

- The **Team** tab only appears after the player has joined a team.
- System lines (join/leave summaries, age notices, etc.) are not shown in the IGCS panel.
- Roblox text filtering still runs on the server — do not strip it out.

## What changed in v2

- Visible chat is React-Lua (`src/client/`) instead of the old imperative `OuterFrame` / `CMain` tree.
- **All** and **Team** tabs in a compact top-left panel (scale size on PC, with a 400×270 minimum).
- Colors, size, position, and strokes are configurable in shared config (`IGCSConfiguration` / `IGCSConfig`).
- Adonis admin bridge is gone. Input starting with `:`, `;`, or `!` goes through **hidden normal Roblox chat** first, then the existing IGCS relay for display — so tools that watch default chat still work.
- TopbarPlus **Icon** is still required (same as v1.4).

## Customize the look

Edit the chat UI settings in shared config (in source: `src/shared/IGCSConfiguration.lua`; in the model: `IGCSConfig`).

Useful knobs:

- Panel position and desktop/mobile size
- Desktop minimum size (`400 × 270` by default)
- Background transparency, stroke colors, accent color
- Whether Team tab requires being on a team

Rebuild the model after source edits (see below), or tweak `IGCSConfig` inside Studio if you are iterating on a place file.

## Build from source (optional)

Use this if you are changing the React UI or packaging a new release.

**Requirements:** [Wally](https://github.com/UpliftGames/wally), Python 3.11+

```sh
wally install
python tools/build_rbxmx.py
```

Output: `dist/IGCS-v2.rbxmx`

Smoke-test the builder without pulling packages:

```sh
python tools/build_rbxmx.py --skip-packages dist/IGCS-source-smoke.rbxmx
```

GitHub Actions builds on pushes and pull requests to `main` and uploads the **IGCS-v2-rbxmx** artifact (model + SHA-256).

Local Rojo path for UI work only: `default.project.json` (does not replace the full Workspace model hierarchy).

## Migrating from v1.4

1. Keep `Content/ChatServer.server` and the normal global / team / whisper paths.
2. Apply the small Adonis removal steps in [`migration/REMOVE_ADONIS.md`](migration/REMOVE_ADONIS.md).
3. Under `Content/IGCS_Client`, use the React client modules instead of `OuterFrame` + `CMain`.
4. Or simply replace the whole model with `dist/IGCS-v2.rbxmx`.

The React client hides the stock chat window and input bar. It does **not** disable the default chat transport.

## Safety and privacy

- This system uses Roblox text filtering on the server; do not remove filtering.
- Prefer moderation, reporting, and careful data handling over “age gate” UI theater.
- Collect as little data as possible. You own compliance for your experience.

## License

MIT — see [`LICENSE`](LICENSE).
