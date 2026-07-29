--!strict

--[[

  _____ _____  _____  _____ 
 |_   _/ ____|/ ____|/ ____|
   | || |  __| |    | (___  
   | || | |_ | |     \___ \ 
  _| || |__| | |____ ____) |
 |_____\_____|\_____|_____/ 
                            
 IGCS — In-Game Chat System
 Shared config + helper constructors for IGCS.
 Change ChatUI values here to restyle the React chat without editing ChatApp.
 
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local IGCSConfiguration = {}

-- ====== GENERAL CONFIG ======
IGCSConfiguration.IconImage = "http://www.roblox.com/asset/?id=6035173838"
IGCSConfiguration.IconLabel = ""
IGCSConfiguration.IconName = "IGCS"
IGCSConfiguration.IconFont = Enum.Font.BuilderSansBold

IGCSConfiguration.PlaceholderText = "Type Your Message here..."
IGCSConfiguration.MaxMessageLength = 200

IGCSConfiguration.RemotesFolderName = "IGCS_Remotes"
IGCSConfiguration.SendRemoteName = "SendMessage"
IGCSConfiguration.BroadcastRemoteName = "BroadcastMessage"

-- ====== CHAT UI SETTINGS ======
-- Backgrounds intentionally stay pure black. Color belongs to UIStroke states.
IGCSConfiguration.ChatUI = {
	Position = UDim2.fromOffset(10, 8),
	DesktopSize = UDim2.fromScale(0.30, 0.25),
	DesktopMinimumSize = Vector2.new(400, 270),
	MobileSize = UDim2.new(1, -20, 0.36, 0),
	MobileBreakpoint = 750,
	MobileHorizontalMargin = 10,
	TeamTabRequiresTeam = true,

	-- Name colors: default is Roblox's classic player name color (from username).
	-- When true, that color is replaced by the sender's TeamColor when they are on a team.
	OverridePlayerColorWithTeam = false,
	-- When true, prefix the display name with [TeamName] (or [Team]) colored by team color.
	-- Independent from OverridePlayerColorWithTeam.
	ShowTeamLabel = false,
	-- When true, system payloads render with SystemMessageFont (join notices, etc.).
	ShowSystemMessages = false,

	PanelBackgroundColor = Color3.fromRGB(0, 0, 0),
	PanelBackgroundTransparency = 0.28,
	PanelCornerRadius = 8,
	PanelStrokeColor = Color3.fromRGB(205, 215, 220),
	PanelStrokeTransparency = 0.5,
	PanelStrokeThickness = 1,

	FieldBackgroundColor = Color3.fromRGB(0, 0, 0),
	FieldBackgroundTransparency = 0.62,
	FieldCornerRadius = 6,
	FieldStrokeColor = Color3.fromRGB(205, 215, 220),
	FieldStrokeTransparency = 0.38,
	FieldStrokeThickness = 1,

	AccentColor = Color3.fromRGB(56, 157, 255),
	AccentStrokeThickness = 2,
	ActiveTabBackgroundTransparency = 0.62,
	TabCornerRadius = 6,
	TabSize = Vector2.new(100, 28),
	TabGap = 8,

	TextPrimary = Color3.fromRGB(248, 248, 248),
	TextSecondary = Color3.fromRGB(190, 201, 204),
	TeamMessageText = Color3.fromRGB(116, 185, 255),
	ErrorText = Color3.fromRGB(255, 168, 168),
	WhisperLabelColor = Color3.fromRGB(215, 166, 255),

	-- Fonts (Enum.Font). Mixed line parts use rich-text face= attributes.
	PlayerNameFont = Enum.Font.GothamBold,
	TeamLabelFont = Enum.Font.GothamBold,
	MessageFont = Enum.Font.Gotham,
	SystemMessageFont = Enum.Font.Gotham,
	TabFont = Enum.Font.GothamBold,
	-- Composer input uses MessageFont unless you set InputFont.
	InputFont = Enum.Font.Gotham,

	PanelPadding = 12,
	TabsTop = 10,
	MessagesTop = 60,
	ComposerHeight = 46,
	ComposerBottom = 12,
	MessageTextSize = 16,
	InputTextSize = 16,
	TabTextSize = 16,
	SystemMessageTextSize = 14,
}
-- =================================

function IGCSConfiguration.CreateIcon()
	local Icon = require(ReplicatedStorage:WaitForChild("Icon"))

	local icon = Icon.new()
		:setImage(IGCSConfiguration.IconImage)
		:setLabel(IGCSConfiguration.IconLabel)
		:setName(IGCSConfiguration.IconName)
		:setTextFont(IGCSConfiguration.IconFont)
		:oneClick()

	return icon
end

function IGCSConfiguration.GetRemotes()
	local folder = ReplicatedStorage:WaitForChild(IGCSConfiguration.RemotesFolderName)
	local sendRE = folder:WaitForChild(IGCSConfiguration.SendRemoteName)
	local broadcastRE = folder:WaitForChild(IGCSConfiguration.BroadcastRemoteName)
	return folder, sendRE, broadcastRE
end

return IGCSConfiguration
