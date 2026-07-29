# Product

<!-- impeccable:product-schema 1 -->

## Platform

Roblox

## Users

Roblox experience developers integrate IGCS as a source-controlled chat frontend. Players use it in-game to read and send global or team messages without seeing Roblox's built-in chat window.

## Product Purpose

IGCS provides a polished, declarative in-game chat interface while retaining Roblox's native text-chat transport. Success means players get a clear Global/Team chat experience and developers can ship, audit, and customize the system as code.

## Positioning

IGCS is a React-Lua frontend over its existing remotes and chat module, not a second chat network. The established relay, Roblox filtering path, bubble-chat behavior, and admin compatibility stay intact.

## Operating Context

The existing server module continues to own global, team, whisper, bubble-chat, filtering, and admin compatibility. The client consumes its existing `BroadcastMessage` and `WhisperMessage` events, hides the stock chat window, and mounts the visible chat surface with React-Lua.

## Capabilities and Constraints

- Global and team messages continue through the current `IGCS_Remotes` flow; the Team tab emits the existing `/t` command.
- The visible UI omits system payloads, including native summary or age notices. It does not add age-check or policy-routing logic.
- The existing Roblox filtering, legacy compatibility, bubble chat, emote, whisper, and admin paths remain unchanged.
- Source is Rojo/Wally based and the presentation depends on React-Lua.

## Brand Commitments

The supplied reference image is binding: a compact, dark graphite, low-profile chat panel with softly rounded controls and no ornamental game HUD treatment.

## Evidence on Hand

- `IGCS_V1.4.a.rbxmx` supplied by the user: imperative chat UI, custom remotes, manual filtering, and an Adonis bridge.
- The attached chat screenshot: the requested visual reference.

## Product Principles

- Native chat is the transport; React-Lua is the presentation.
- Render only content the player needs to converse.
- Team chat is a server-authoritative channel, never a cosmetic client filter.
- Keep customization in readable source files, not binary model internals.

