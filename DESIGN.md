---
name: IGCS
description: A compact, translucent black Roblox chat overlay.
colors:
  panel: "#000000"
  field: "#000000"
  outline: "#CDD7DC"
  text-primary: "#F3F6F7"
  text-secondary: "#BEC9CC"
  channel-accent: "#389DFF"
  error: "#FFA8A8"
typography:
  body:
    fontFamily: "Gotham, Arial, sans-serif"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.35
  channel:
    fontFamily: "Gotham, Arial, sans-serif"
    fontSize: "18px"
    fontWeight: 700
    lineHeight: 1
rounded:
  panel: "8px"
  field: "6px"
  tab: "6px"
spacing:
  tight: "8px"
  control: "14px"
  panel: "18px"
components:
  chat-panel:
    backgroundColor: "{colors.panel}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.panel}"
    padding: "14px 18px"
  chat-input:
    backgroundColor: "{colors.field}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.field}"
    padding: "0 18px"
---

# Design System: IGCS

## Overview

**Creative North Star: "The Game Channel"**

IGCS is a compact conversation layer inside the game world, not a second HUD. A pure-black panel sits in the safe top-left area, lets the world show through, and gives chat enough contrast to stay legible while moving through a game.

**Key Characteristics:**

- A compact black overlay whose colour comes from precise UIStroke states, not filled surfaces.
- Text channel tabs: "All" and "Team". The selected tab receives the single bright-blue outline.
- Player messages lead; summary, age-gating, and generic system lines are absent.
- A flat rectangular composer stays at the panel base. Its legacy arrow asset appears only when there is text to send.

## Colors

The palette is restrained: pure-black surfaces under low transparency, cool-gray UIStroke boundaries, and one blue state signal.

- **Black surface:** the panel protects readability but does not sever the player from the game world.
- **Black field:** the composer belongs to the same uncoloured material family.
- **Channel blue:** identifies only the selected channel, focused context, and the send action.
- **Fog text:** supports placeholder copy and inactive tabs without dimming player messages.

## Typography

Gotham is clear at gameplay distance. Sender names use weight and a colon; message content remains plain and readable. Channel labels are bold text, never icons, so their meaning is immediate.

## Layout

The panel anchors below Roblox's native top inset; IgnoreGuiInset remains disabled. Desktop defaults to UDim2.fromScale(0.30, 0.25), matching Roblox's responsive chat proportions; narrow screens use the configurable MobileSize. All visual dimensions, transparency, text, and stroke roles are exposed in IGCSConfiguration.ChatUI.

"All" always remains at the upper edge. "Team" appears only after the player has joined a Roblox Team, then disappears immediately if they leave. Messages scroll between the tabs and composer, and the composer remains fixed to the lower edge. The panel has no header shelf, left action button, or duplicate shadow.

## Elevation & Shapes

Depth comes from transparency and a faint border, not a floating shadow. Corners are subtle: 8px for the panel and 6px for tabs and composer. The only selected state is the bright-blue tab stroke.

## Components

### Channel Tabs

- **Style:** Text-first controls with "All" and "Team" labels.
- **State:** The active channel uses a crisp blue two-pixel outline and a slightly denser teal fill. Inactive tabs remain transparent.

### Chat Messages

- **Style:** Player message payloads only, with weighted sender names and normal-weight content.
- **Scope:** Team senders use a light-blue identity; whisper labels stay violet.

### Composer

- **Style:** Flat dark field, subtle outline, comfortable 18px text.
- **Action:** Enter sends. The existing rbxassetid://6035067832 arrow remains available as a low-key mouse send affordance after text is entered.

## Do's and Don'ts

### Do:

- Keep the game visible through the panel.
- Treat channels as text tabs, not a navigation icon shelf.
- Preserve the existing IGCS relay and Roblox filtering path.

### Don't:

- Don't show native summary, age, or safety notice lines in the IGCS message list.
- Don't add a left action button, pill-heavy card treatment, decorative glow, or a duplicate offset panel.
- Don't replace the existing communication or command-routing architecture.

