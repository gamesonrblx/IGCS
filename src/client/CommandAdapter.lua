--!strict

-- This is the client-only compatibility seam from the old CMain. It preserves
-- emote handling and routes admin-prefixed input to the hidden normal Roblox
-- chat, while the existing IGCS server continues to receive the same input.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local CommandAdapter = {}
local player = Players.LocalPlayer

local ADMIN_PREFIXES = { ":", ";", "!" }
local DEFAULT_EMOTES = {
	wave = "rbxassetid://507770239",
	point = "rbxassetid://507770453",
	dance = "rbxassetid://507771019",
	dance2 = "rbxassetid://507776043",
	dance3 = "rbxassetid://507777268",
	laugh = "rbxassetid://507770818",
	cheer = "rbxassetid://507770677",
}

local currentEmoteTrack: AnimationTrack? = nil
local emoteMovementConnection: RBXScriptConnection? = nil

local function isAdminCommand(text: string): boolean
	return table.find(ADMIN_PREFIXES, text:sub(1, 1)) ~= nil
end

local function stopCurrentEmote()
	if currentEmoteTrack then
		currentEmoteTrack:Stop()
		currentEmoteTrack = nil
	end
	if emoteMovementConnection then
		emoteMovementConnection:Disconnect()
		emoteMovementConnection = nil
	end
end

local function playEmote(name: string): boolean
	local character = player.Character
	if not character then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return false
	end

	stopCurrentEmote()
	local lowerName = name:lower()
	local track: AnimationTrack? = nil

	local animate = character:FindFirstChild("Animate")
	local emoteValue = animate and animate:FindFirstChild(lowerName)
	local animation = emoteValue and emoteValue:FindFirstChildOfClass("Animation")
	if animation then
		track = animator:LoadAnimation(animation)
	end

	if not track then
		local didPlay, result = pcall(function()
			return humanoid:PlayEmote(name)
		end)
		if didPlay and result then
			emoteMovementConnection = humanoid.Running:Connect(function(speed)
				if speed > 0.5 then
					stopCurrentEmote()
				end
			end)
			return true
		end
	end

	if not track and DEFAULT_EMOTES[lowerName] then
		local fallback = Instance.new("Animation")
		fallback.AnimationId = DEFAULT_EMOTES[lowerName]
		track = animator:LoadAnimation(fallback)
		fallback:Destroy()
	end

	if not track then
		return false
	end

	currentEmoteTrack = track
	track:Play()
	emoteMovementConnection = humanoid.Running:Connect(function(speed)
		if speed > 0.5 then
			stopCurrentEmote()
		end
	end)
	track.Stopped:Once(function()
		if currentEmoteTrack == track then
			currentEmoteTrack = nil
		end
	end)
	return true
end

-- Local-only bubble (client call). Used for team chat so non-teammates never
-- see the bubble; server Chat:Chat would replicate to everyone.
function CommandAdapter.showLocalBubble(speakerUserId: number?, text: string)
	if type(speakerUserId) ~= "number" or type(text) ~= "string" or text:match("^%s*$") then
		return
	end

	local speaker = Players:GetPlayerByUserId(speakerUserId)
	if not speaker then
		return
	end

	local character = speaker.Character
	if not character then
		return
	end

	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end

	-- Prefer TextChat DisplayBubble (client → this client only). Fallback Chat:Chat.
	local shown = pcall(function()
		(TextChatService :: any):DisplayBubble(head, text)
	end)
	if not shown then
		pcall(function()
			game:GetService("Chat"):Chat(head, text, Enum.ChatColor.White)
		end)
	end
end

function CommandAdapter.forwardToNormalHiddenChat(message: string)
	-- Transport only: fire default chat so admin systems still see the message.
	-- Visual bubbles are owned by IGCS (server bubbleChatForPlayer). ReactChat
	-- disables TextChat BubbleChatConfiguration and legacy BubbleChatEnabled.
	local legacyEvents = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
	local sayRequest = legacyEvents and legacyEvents:FindFirstChild("SayMessageRequest")
	if sayRequest and sayRequest:IsA("RemoteEvent") then
		sayRequest:FireServer(message, "All")
		return
	end

	local general = TextChatService:FindFirstChild("RBXGeneral")
	if not general then
		local channels = TextChatService:FindFirstChild("TextChannels")
		general = channels and channels:FindFirstChild("RBXGeneral")
	end
	if general and general:IsA("TextChannel") then
		-- Eligibility or an unavailable channel must not prevent the original
		-- IGCS relay from rendering the command in its own chat surface.
		pcall(function()
			general:SendAsync(message)
		end)
	end
end

-- Returns true only when a command was fully handled on the client and must
-- not be passed to the pre-existing IGCS SendMessage RemoteEvent.
function CommandAdapter.shouldSkipExistingRelay(text: string): boolean
	local trimmed = text:match("^%s*(.-)%s*$") or ""
	local lower = trimmed:lower()
	local emote = lower:match("^/e%s+(.+)$") or lower:match("^/emote%s+(.+)$")
	if emote then
		if not playEmote(emote) then
			CommandAdapter.forwardToNormalHiddenChat(trimmed)
		end
		return true
	end

	if isAdminCommand(trimmed) then
		-- No IGCS_RunCommand or Adonis API: the normal chat event is the bridge.
		CommandAdapter.forwardToNormalHiddenChat(trimmed)
	end

	return false
end

return CommandAdapter

