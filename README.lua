--[[

  _____ _____  _____  _____ 
 |_   _/ ____|/ ____|/ ____|
   | || |  __| |    | (___  
   | || | |_ | |     \___ \ 
  _| || |__| | |____ ____) |
 |_____\_____|\_____|_____/ 
                            
                                                                         
IGCS — In-Game Chat System
Open-source and free to use, modify, and redistribute in any form (commercial or non-commercial).
No credits required.

Why this exists
- To provide a lightweight, customizable chat UI with optional bubble chat and basic scopes (Global / Team / Whisper).
- To keep chat logic transparent and auditable: filtering happens on the server, UI runs on the client.
- To let developers control the experience (styling, commands, moderation hooks) without relying on default chat UI.

How to use (quick start)
1) Place the IGCS folder in Workspace with this structure:
   - IGCS
     - Content
       - ChatServer.server      (ModuleScript)
       - Icon                  (ModuleScript)
       - IGCS_Client           (ScreenGui)
     - Initialise              (Script)
     - IGCSConfig              (ModuleScript)

2) Ensure Initialise runs on the server. It installs:
   - Icon + IGCSConfig into ReplicatedStorage
   - IGCS_Client into StarterGui (so all players receive the UI)
   - RemoteEvents into ReplicatedStorage (IGCS_Remotes)

3) Make sure the client UI listens for:
   - BroadcastMessage (global/system)
   - WhisperMessage (team/whisper/system-to-player)

Chat scopes / commands (default)
- Global:        type normally
- Team chat:     /t message   or /team message
- Whisper/PM:    /w player message   or /pm player message

Notes on safety and privacy
- This system uses Roblox text filtering on the server; do not remove filtering.
- Safety should be addressed through moderation, reporting, and careful data handling.
- “Age verification” alone does not guarantee child safety, and can increase the risk of targeted abuse and data exposure if implemented poorly.
  Build with minimal data collection and strong security practices.
]]
