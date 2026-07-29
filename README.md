# IGCS - In-Game Chat System

IGCS v2 keeps the proven v1.4 communication module and replaces only the visible chat with React-Lua.

## What changed

- The static `OuterFrame` tree and imperative `CMain` UI are replaced with the React-Lua chat surface in `src/client/`.
- **Global** shows the current global and whisper payloads; **Team** renders the current `scope = "team"` payloads.
- Sending from Team emits `/t <message>` to the existing `SendMessage` remote. Filtering, permission checks, bubble chat, whispers, and rate limiting remain in the current server module.
- The React client ignores `payload.system == true`, so joined/left, summary, and age/safety notice lines never appear in the IGCS panel.
- The existing TopbarPlus `Icon` dependency remains. React recreates the `IGCS_ChatIcon` singleton through `IGCSConfiguration.CreateIcon()` and uses it to open and close the chat.
- The Adonis `IGCS_RunCommand` bridge is removed. Admin-prefixed input first enters hidden normal Roblox chat, then follows the existing IGCS relay for display.

## Architecture

```text
ReactChat.client.lua + ChatApp.lua      React-Lua presentation only
CommandAdapter.lua                     : ; ! -> hidden normal Roblox chat
             |                         (no Adonis API bridge)
             v
existing IGCS_Remotes.SendMessage -> existing ChatServer.server
                                    filtering / scopes / bubbles / remotes
```

## Install React-Lua

This source tree uses Wally aliases so the client can require `ReplicatedStorage.Packages.React` and `ReactRoblox`.

```sh
wally install
```

`default.project.json` is available for local source sync. The full importable model is produced by the builder below; it preserves the existing v1.4 hierarchy rather than replacing it. Do not move `IGCS_Remotes` or modify the ordinary message handlers.

## Build the importable RBXMX

The tracked [`template/IGCS_V1.4.a.rbxmx`](template/IGCS_V1.4.a.rbxmx) is the current full model baseline. The Python builder preserves its established communication hierarchy, injects the React-Lua client and Wally packages, removes the Adonis bridge, and writes an importable model.

```sh
wally install
python tools/build_rbxmx.py
```

The result is `dist/IGCS-v2.rbxmx`. Use `python tools/build_rbxmx.py --skip-packages dist/IGCS-source-smoke.rbxmx` to validate the XML patching path without downloading packages.

GitHub Actions runs this exact build on pull requests and `v1.4.0` pushes, then uploads `IGCS-v2.rbxmx` and a SHA-256 checksum as the **IGCS-v2-rbxmx** artifact.

## Update the existing IGCS model

1. Keep `Content/ChatServer.server` and its normal global/team/whisper code.
2. Apply the small Adonis-only change in [`migration/REMOVE_ADONIS.md`](migration/REMOVE_ADONIS.md).
3. Under `Content/IGCS_Client`, remove `OuterFrame` and replace `CMain` with `ReactChat.client.lua`; add its sibling `ChatApp`, `CommandAdapter`, and `Theme` modules.
4. Ensure the Wally `Packages` folder is in `ReplicatedStorage` before running the model.

The React client hides Roblox's native chat window, input bar, and channel tabs; it does **not** disable the default chat transport. This preserves the normal-chat path that existing admin tools and chat observers use.

The builder also removes the old server-side `StarterGui:SetCoreGuiEnabled()` calls. They are invalid from a server script; visual hiding now happens only in the React LocalScript.

## Validation checklist

- Global input still reaches all players through the current filtered server route.
- Team-tab input arrives through the same `/t` parser and is visible only in Team.
- `:`, `;`, and `!` no longer call `IGCS_RunCommand`, `Process.Command()`, or `IGCS_AdminBridge`.
- System payloads do not render in the React panel.
- `/e`, `/emote`, `/w`, `/pm`, and `/whisper` continue to use their existing paths.

## Migration scope

The supplied `IGCS_V1.4.a.rbxmx` is the behavioral source of truth. The old binary `IGCS_v1.4.0.rbxm` remains in this repository for backward compatibility; the new source tree is the maintainable v2 implementation.

