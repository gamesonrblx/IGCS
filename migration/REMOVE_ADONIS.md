# Remove the Adonis API bridge

This is the one intentional communication-layer change. Everything else in `ChatServer.server` stays as it is.

1. Delete `Content/IGCS_AdminBridge` and its child `Server-IGCS_AdonisPlugin` from the IGCS model.
2. In `Initialise`, delete the `bridge` validation line and the line that installs `IGCS_AdminBridge` into `ReplicatedStorage`.
3. Replace the current admin branch in `ChatServer.server` with [`ChatServer.admin-branch.lua`](ChatServer.admin-branch.lua).

The new React client sends `:`, `;`, and `!` input through the hidden normal chat first, then continues to pass the same input to the existing `SendMessage` relay for IGCS display. There is no `IGCS_RunCommand` BindableEvent, no `Process.Command()` call, and no Adonis plugin API.

Visual bubbles for admin lines use the same IGCS `bubbleChatForPlayer` path as global chat. Native TextChat / legacy bubbles are disabled on the client so you do not get two bubble styles.

Keep `IGCS_TriggerChat` and its client listener. It is the existing normal-chat fallback used when legacy chat forwarding is unavailable; it is **not** an Adonis API.

