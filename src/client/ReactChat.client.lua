--!strict

-- Replace the imperative CMain LocalScript with this LocalScript. It mounts the
-- React tree into the existing IGCS_Client ScreenGui and leaves all remotes and
-- the ChatServer module untouched.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local ReactRoblox = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("ReactRoblox"))
local IGCSConfiguration = require(ReplicatedStorage:WaitForChild("IGCSConfiguration"))
local Icon = require(ReplicatedStorage:WaitForChild("Icon"))
local ChatApp = require(script.Parent:WaitForChild("ChatApp"))
local CommandAdapter = require(script.Parent:WaitForChild("CommandAdapter"))

local player = Players.LocalPlayer
local gui = script.Parent
assert(gui:IsA("ScreenGui"), "[IGCS] ReactChat.client.lua must be parented to IGCS_Client.")
gui.IgnoreGuiInset = false
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- React owns every descendant of its container. Keep its reconciliation tree
-- inside a dedicated frame so CMain and the module dependencies survive mount.
local mount = gui:FindFirstChild("IGCSReactMount")
if not mount then
	mount = Instance.new("Frame")
	mount.Name = "IGCSReactMount"
	mount.Size = UDim2.fromScale(1, 1)
	mount.BackgroundTransparency = 1
	mount.BorderSizePixel = 0
	mount.Parent = gui
end
assert(mount:IsA("Frame"), "[IGCS] IGCSReactMount must be a Frame.")

-- Hide the visual shell of native chat, not its transport. CMain's normal-chat
-- forwarding still reaches the default channel for systems that observe it.
for _, configurationName in { "ChatWindowConfiguration", "ChatInputBarConfiguration", "ChannelTabsConfiguration" } do
	local configuration = TextChatService:FindFirstChild(configurationName)
	if configuration then
		pcall(function()
			(configuration :: any).Enabled = false
		end)
	end
end

-- Keep the v1.4 normal-chat fallback alive. It is transport compatibility,
-- not the deleted IGCS_RunCommand/Adonis API.
local remotes = ReplicatedStorage:WaitForChild("IGCS_Remotes")
local triggerChat = remotes:FindFirstChild("IGCS_TriggerChat")
if triggerChat and triggerChat:IsA("RemoteEvent") then
	triggerChat.OnClientEvent:Connect(CommandAdapter.forwardToNormalHiddenChat)
end

local oldFrame = gui:FindFirstChild("OuterFrame")
if oldFrame then
	oldFrame:Destroy()
end

-- Keep the existing TopbarPlus dependency and singleton chat toggle. The icon
-- lives beyond a GUI respawn, so locate the current player GUI on every click.
local ICON_NAME = "IGCS_ChatIcon"
local icon = Icon.getIcon(ICON_NAME)
if not icon then
	icon = IGCSConfiguration.CreateIcon()
	icon:setName(ICON_NAME)
end

-- Bind the physical TopbarPlus button. This avoids relying on oneClick's
-- deferred deselected signal and works consistently with the hidden ScreenGui.
local clickRegion = icon:getInstance("ClickRegion")
assert(clickRegion and clickRegion:IsA("GuiButton"), "[IGCS] TopbarPlus click region is missing.")
local lastToggleAt = -math.huge
local function toggleChat()
	if os.clock() - lastToggleAt < 0.15 then
		return
	end
	lastToggleAt = os.clock()
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	local currentGui = playerGui and playerGui:FindFirstChild("IGCS_Client")
	if currentGui and currentGui:IsA("ScreenGui") then
		currentGui.Enabled = not currentGui.Enabled
	end
end
icon:bindEvent("deselected", toggleChat)
clickRegion.Activated:Connect(toggleChat)
clickRegion.MouseButton1Click:Connect(toggleChat)

gui.Enabled = false

-- ReactRoblox schedules the initial render. Configure the persistent topbar
-- toggle first so it remains available while the root is mounting.
local root = ReactRoblox.createRoot(mount)
root:render(React.createElement(ChatApp))

