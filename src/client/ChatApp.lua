--!strict

-- THESIS: A translucent in-game conversation overlay replaces a separate chat card.
-- OWN-WORLD: Pure-black surfaces, quiet cool-gray outlines, and one crisp blue selection signal.
-- STORY: Players scan player chat, switch All or Team, and reply without leaving the game world.
-- FIRST VIEWPORT: A safe-area top-left overlay places channel text tabs above the log and a flat composer below.
-- FORM: A native game chat panel with subtle corners, a clear reading order, and no decorative control shelf.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local IGCSConfiguration = require(ReplicatedStorage:WaitForChild("IGCSConfiguration"))
local Theme = require(script.Parent.Theme)
local CommandAdapter = require(script.Parent.CommandAdapter)

local localPlayer = Players.LocalPlayer
local Ui = IGCSConfiguration.ChatUI

type Scope = "global" | "team" | "whisper"
type Tab = "global" | "team"
type ChatMessage = {
	id: string,
	scope: Scope,
	userId: number?,
	username: string,
	displayName: string,
	text: string,
	isSystem: boolean?,
}

-- Classic Roblox chat name colors (same palette/algorithm as legacy chat).
local NAME_COLORS = {
	BrickColor.new("Bright red").Color,
	BrickColor.new("Bright blue").Color,
	BrickColor.new("Earth green").Color,
	BrickColor.new("Bright violet").Color,
	BrickColor.new("Bright orange").Color,
	BrickColor.new("Bright yellow").Color,
	BrickColor.new("Light reddish violet").Color,
	BrickColor.new("Brick yellow").Color,
}

local function escapeRichText(text: string): string
	return text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
end

local function addCorner(radius: number)
	return React.createElement("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function addStroke(color: Color3, thickness: number, transparency: number)
	return React.createElement("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = color,
		Thickness = thickness,
		Transparency = transparency,
	})
end

type PanelLayout = {
	size: UDim2,
	minimum: Vector2,
}

local function getPanelLayout(): PanelLayout
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)

	if viewport.X < Ui.MobileBreakpoint then
		return {
			size = Ui.MobileSize,
			minimum = Vector2.zero,
		}
	end

	return {
		size = Ui.DesktopSize,
		minimum = Ui.DesktopMinimumSize,
	}
end

local function usePanelLayout(): PanelLayout
	local layout, setLayout = React.useState(getPanelLayout())

	React.useEffect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			setLayout(getPanelLayout())
		end)
		return function()
			connection:Disconnect()
		end
	end, {})

	return layout
end

local function useHasTeam(): boolean
	local hasTeam, setHasTeam = React.useState(localPlayer.Team ~= nil)

	React.useEffect(function()
		local connection = localPlayer:GetPropertyChangedSignal("Team"):Connect(function()
			setHasTeam(localPlayer.Team ~= nil)
		end)
		return function()
			connection:Disconnect()
		end
	end, {})

	return hasTeam
end

local function colorToHex(color: Color3): string
	return string.format("#%02X%02X%02X", math.round(color.R * 255), math.round(color.G * 255), math.round(color.B * 255))
end

local function resolveFont(font: Enum.Font?, fallback: Enum.Font): Enum.Font
	return if font ~= nil then font else fallback
end

-- Rich text face= uses the Enum.Font name (e.g. "Gotham", "GothamBold").
local function wrapRichFont(font: Enum.Font, color: Color3, content: string, bold: boolean?): string
	local inner = if bold then "<b>" .. content .. "</b>" else content
	return string.format('<font face="%s" color="%s">%s</font>', font.Name, colorToHex(color), inner)
end

local function getNameValue(pName: string): number
	local value = 0
	local length = #pName
	for index = 1, length do
		local cValue = string.byte(pName, index)
		local reverseIndex = length - index + 1
		if length % 2 == 1 then
			reverseIndex = reverseIndex - 1
		end
		if reverseIndex % 4 >= 2 then
			cValue = -cValue
		end
		value += cValue
	end
	return value
end

local function getRobloxNameColor(username: string): Color3
	if username == "" then
		return NAME_COLORS[1]
	end
	return NAME_COLORS[(getNameValue(username) % #NAME_COLORS) + 1]
end

local function resolvePlayer(message: ChatMessage): Player?
	if message.userId then
		local byId = Players:GetPlayerByUserId(message.userId)
		if byId then
			return byId
		end
	end
	if message.username ~= "" then
		local byName = Players:FindFirstChild(message.username)
		if byName and byName:IsA("Player") then
			return byName
		end
	end
	return nil
end

local function getPlayerNameColor(message: ChatMessage): Color3
	local player = resolvePlayer(message)
	if Ui.OverridePlayerColorWithTeam and player and player.Team ~= nil then
		return player.TeamColor.Color
	end
	local username = if player then player.Name else message.username
	if username == "" then
		username = message.displayName
	end
	return getRobloxNameColor(username)
end

local function getTeamLabelParts(message: ChatMessage): (string?, Color3?)
	if not Ui.ShowTeamLabel then
		return nil, nil
	end

	local player = resolvePlayer(message)
	if player and player.Team then
		return player.Team.Name, player.TeamColor.Color
	end

	-- Team-scope lines still get a generic label if the sender left the game.
	if message.scope == "team" then
		return "Team", Theme.TeamMessage
	end

	return nil, nil
end

local function ChannelTab(props: { label: string, active: boolean, layoutOrder: number, onActivated: () -> () })
	local tabFont = resolveFont((Ui :: any).TabFont, Enum.Font.GothamBold)
	return React.createElement("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = Theme.PanelStrong,
		BackgroundTransparency = if props.active then Ui.ActiveTabBackgroundTransparency else 1,
		BorderSizePixel = 0,
		Font = tabFont,
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromOffset(Ui.TabSize.X, Ui.TabSize.Y),
		Text = props.label,
		TextColor3 = if props.active then Theme.TextPrimary else Theme.TextSecondary,
		TextSize = Ui.TabTextSize,
		ZIndex = 3,
		[React.Event.Activated] = props.onActivated,
	}, {
		Corner = addCorner(Ui.TabCornerRadius),
		Outline = if props.active then addStroke(Theme.TeamAccent, Ui.AccentStrokeThickness, 0) else nil,
	})
end

local function ChatLine(props: { message: ChatMessage, order: number })
	local playerFont = resolveFont((Ui :: any).PlayerNameFont, Enum.Font.GothamBold)
	local teamFont = resolveFont((Ui :: any).TeamLabelFont, Enum.Font.GothamBold)
	local messageFont = resolveFont((Ui :: any).MessageFont, Enum.Font.Gotham)
	local systemFont = resolveFont((Ui :: any).SystemMessageFont, Enum.Font.Gotham)
	local name = escapeRichText(props.message.displayName)
	local text = escapeRichText(props.message.text)

	-- System lines: whole body uses SystemMessageFont (no player name color).
	if props.message.isSystem then
		local systemColor = Theme.TextSecondary
		local richSystem = wrapRichFont(systemFont, systemColor, text)
		return React.createElement("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Font = systemFont,
			LayoutOrder = props.order,
			RichText = true,
			Size = UDim2.new(1, -4, 0, 0),
			Text = richSystem,
			TextColor3 = systemColor,
			TextSize = (Ui :: any).SystemMessageTextSize or Ui.MessageTextSize,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
	end

	local prefixes = ""
	if props.message.scope == "whisper" then
		local whisperLabelColor = (Ui :: any).WhisperLabelColor or Color3.fromRGB(215, 166, 255)
		prefixes ..= wrapRichFont(teamFont, whisperLabelColor, "[Whisper] ")
	end

	local teamLabel, teamColor = getTeamLabelParts(props.message)
	if teamLabel and teamColor then
		prefixes ..= wrapRichFont(teamFont, teamColor, "[" .. escapeRichText(teamLabel) .. "] ")
	end

	-- Name / team label / message body each get their own configured font + color.
	local richMessage = prefixes
		.. wrapRichFont(playerFont, getPlayerNameColor(props.message), name, true)
		.. wrapRichFont(messageFont, Theme.TextPrimary, ": " .. text)

	return React.createElement("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = messageFont,
		LayoutOrder = props.order,
		RichText = true,
		Size = UDim2.new(1, -4, 0, 0),
		Text = richMessage,
		TextColor3 = Theme.TextPrimary,
		TextSize = Ui.MessageTextSize,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
end

local function normalizePayload(payload: any, sequence: number): ChatMessage?
	if type(payload) ~= "table" then
		return nil
	end

	local text = tostring(payload.text or "")
	if text:match("^%s*$") then
		return nil
	end

	-- System messages stay off by default; enable with ChatUI.ShowSystemMessages.
	if payload.system == true then
		if (Ui :: any).ShowSystemMessages ~= true then
			return nil
		end
		return {
			id = tostring(payload.t or os.clock()) .. "-" .. tostring(sequence),
			scope = "global" :: Scope,
			userId = nil,
			username = "",
			displayName = "",
			text = text,
			isSystem = true,
		}
	end

	local scope = tostring(payload.scope or "global"):lower()
	if scope ~= "global" and scope ~= "team" and scope ~= "whisper" then
		return nil
	end

	local userId: number? = nil
	local rawUserId = payload.userId or payload.fromUserId
	if type(rawUserId) == "number" then
		userId = rawUserId
	elseif type(rawUserId) == "string" then
		local parsed = tonumber(rawUserId)
		if parsed then
			userId = parsed
		end
	end

	return {
		id = tostring(payload.t or os.clock()) .. "-" .. tostring(sequence),
		scope = scope :: Scope,
		userId = userId,
		username = tostring(payload.username or payload.fromUsername or ""),
		displayName = tostring(payload.displayName or payload.fromDisplayName or payload.username or payload.fromUsername or "Player"),
		text = text,
		isSystem = false,
	}
end

local function ChatApp()
	local panelLayout = usePanelLayout()
	local hasTeam = useHasTeam()
	local activeTab, setActiveTab = React.useState("global" :: Tab)
	local draft, setDraft = React.useState("")
	local messages, setMessages = React.useState({} :: { ChatMessage })
	local errorText, setErrorText = React.useState(nil :: string?)
	local inputRef = React.useRef(nil :: TextBox?)
	local messagesRef = React.useRef(nil :: ScrollingFrame?)
	local sequenceRef = React.useRef(0)

	local remotes = ReplicatedStorage:WaitForChild("IGCS_Remotes")
	local sendMessage = remotes:WaitForChild("SendMessage") :: RemoteEvent
	local broadcastMessage = remotes:WaitForChild("BroadcastMessage") :: RemoteEvent
	local whisperMessage = remotes:WaitForChild("WhisperMessage") :: RemoteEvent

	-- Second channel today is Team. When a Whisper tab exists later, include it here.
	local showTeamTab = not Ui.TeamTabRequiresTeam or hasTeam
	local showTabBar = showTeamTab
	local messagesTop = if showTabBar then Ui.MessagesTop else Ui.PanelPadding

	React.useEffect(function()
		if Ui.TeamTabRequiresTeam and not hasTeam and activeTab == "team" then
			setActiveTab("global")
		end
	end, { hasTeam, activeTab })

	React.useEffect(function()
		local function receive(payload: any)
			sequenceRef.current += 1
			local message = normalizePayload(payload, sequenceRef.current)
			if not message then
				return
			end
			setMessages(function(previous: { ChatMessage })
				local nextMessages = table.clone(previous)
				table.insert(nextMessages, message)
				if #nextMessages > 100 then
					table.remove(nextMessages, 1)
				end
				return nextMessages
			end)
		end

		local globalConnection = broadcastMessage.OnClientEvent:Connect(receive)
		local scopedConnection = whisperMessage.OnClientEvent:Connect(receive)
		return function()
			globalConnection:Disconnect()
			scopedConnection:Disconnect()
		end
	end, { broadcastMessage, whisperMessage })

	React.useEffect(function()
		local connection = UserInputService.InputBegan:Connect(function(input, wasProcessed)
			if wasProcessed or input.KeyCode ~= Enum.KeyCode.Slash then
				return
			end
			local inputBox = inputRef.current
			if inputBox and not inputBox:IsFocused() then
				inputBox:CaptureFocus()
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, {})

	React.useEffect(function()
		local scrollingFrame = messagesRef.current
		if scrollingFrame then
			task.defer(function()
				if scrollingFrame.Parent then
					local y = math.max(0, scrollingFrame.AbsoluteCanvasSize.Y - scrollingFrame.AbsoluteSize.Y)
					scrollingFrame.CanvasPosition = Vector2.new(0, y)
				end
			end)
		end
	end, { messages, activeTab, showTabBar })

	local function sendCurrent()
		local text = draft:gsub("\r", ""):gsub("\n", "")
		if text:match("^%s*$") then
			return
		end
		if activeTab == "team" and localPlayer.Team == nil then
			setErrorText("Join a team before using Team chat.")
			return
		end

		setDraft("")
		setErrorText(nil)
		local payload = if activeTab == "team" then "/t " .. text else text
		if not CommandAdapter.shouldSkipExistingRelay(payload) then
			sendMessage:FireServer(payload)
		end
	end

	local visibleMessages = {}
	for _, message in ipairs(messages) do
		if (activeTab == "team" and message.scope == "team") or (activeTab == "global" and message.scope ~= "team") then
			table.insert(visibleMessages, message)
		end
	end

	local messageChildren: { [string]: any } = {
		Layout = React.createElement("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, message in ipairs(visibleMessages) do
		messageChildren[message.id .. "-" .. index] = React.createElement(ChatLine, { message = message, order = index })
	end

	local hasDraft = not draft:match("^%s*$")
	local sendColor = if hasDraft then Theme.TeamAccent else Theme.TextSecondary

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Name = "IGCSReactRoot",
		Size = UDim2.fromScale(1, 1),
	}, {
		Panel = React.createElement("Frame", {
			BackgroundColor3 = Theme.Panel,
			BackgroundTransparency = Ui.PanelBackgroundTransparency,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Position = Ui.Position,
			Size = panelLayout.size,
			ZIndex = 1,
		}, {
			Corner = addCorner(Ui.PanelCornerRadius),
			Outline = addStroke(Ui.PanelStrokeColor, Ui.PanelStrokeThickness, Ui.PanelStrokeTransparency),
			MinimumSize = React.createElement("UISizeConstraint", {
				MinSize = panelLayout.minimum,
			}),
			Tabs = if showTabBar
				then React.createElement("Frame", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(Ui.PanelPadding, Ui.TabsTop),
					Size = UDim2.new(1, -Ui.PanelPadding * 2, 0, Ui.TabSize.Y),
					ZIndex = 2,
				}, {
					Layout = React.createElement("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
						Padding = UDim.new(0, Ui.TabGap),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					All = React.createElement(ChannelTab, {
						active = activeTab == "global",
						label = "All",
						layoutOrder = 1,
						onActivated = function()
							setActiveTab("global")
						end,
					}),
					Team = React.createElement(ChannelTab, {
						active = activeTab == "team",
						label = "Team",
						layoutOrder = 2,
						onActivated = function()
							setActiveTab("team")
						end,
					}),
				})
				else nil,
			Messages = React.createElement("ScrollingFrame", {
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.fromOffset(0, 0),
				Position = UDim2.new(0, Ui.PanelPadding, 0, messagesTop),
				ScrollBarImageColor3 = Ui.PanelStrokeColor,
				ScrollBarImageTransparency = Ui.PanelStrokeTransparency,
				ScrollBarThickness = 3,
				Size = UDim2.new(1, -Ui.PanelPadding * 2, 1, -messagesTop - Ui.ComposerHeight - Ui.ComposerBottom - 4),
				ZIndex = 2,
				ref = messagesRef,
			}, messageChildren),
			Composer = React.createElement("Frame", {
				AnchorPoint = Vector2.new(0, 1),
				BackgroundTransparency = 1,
				Position = UDim2.new(0, Ui.PanelPadding, 1, -Ui.ComposerBottom),
				Size = UDim2.new(1, -Ui.PanelPadding * 2, 0, Ui.ComposerHeight),
				ZIndex = 3,
			}, {
				Input = React.createElement("TextBox", {
					BackgroundColor3 = Theme.Field,
					BackgroundTransparency = Ui.FieldBackgroundTransparency,
					BorderSizePixel = 0,
					ClearTextOnFocus = false,
					Font = resolveFont((Ui :: any).InputFont or (Ui :: any).MessageFont, Enum.Font.Gotham),
					PlaceholderColor3 = Theme.TextSecondary,
					PlaceholderText = if activeTab == "team" then "Message your team" else "To chat click here or press / key",
					Position = UDim2.fromOffset(0, 0),
					Size = UDim2.new(1, 0, 0, Ui.ComposerHeight),
					Text = draft,
					TextColor3 = Theme.TextPrimary,
					TextSize = Ui.InputTextSize,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					ZIndex = 3,
					ref = inputRef,
					[React.Change.Text] = function(textBox: TextBox)
						setDraft(textBox.Text)
					end,
					[React.Event.FocusLost] = function(enterPressed: boolean)
						if enterPressed then
							sendCurrent()
						end
					end,
				}, {
					Corner = addCorner(Ui.FieldCornerRadius),
					Outline = addStroke(Ui.FieldStrokeColor, Ui.FieldStrokeThickness, Ui.FieldStrokeTransparency),
					Padding = React.createElement("UIPadding", {
						PaddingLeft = UDim.new(0, 18),
						PaddingRight = UDim.new(0, 60),
					}),
				}),
				Send = if hasDraft
					then React.createElement("TextButton", {
						AnchorPoint = Vector2.new(1, 0.5),
						AutoButtonColor = false,
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Position = UDim2.new(1, -7, 0.5, 0),
						Size = UDim2.fromOffset(Ui.ComposerHeight, Ui.ComposerHeight),
						Text = "",
						ZIndex = 4,
						[React.Event.Activated] = sendCurrent,
					}, {
						Icon = React.createElement("ImageLabel", {
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							Image = "rbxassetid://6035067832",
							ImageColor3 = sendColor,
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.fromOffset(19, 19),
							ZIndex = 5,
						}),
					})
					else nil,
				Error = if errorText
					then React.createElement("TextLabel", {
						AnchorPoint = Vector2.new(0, 1),
						BackgroundTransparency = 1,
						Font = resolveFont((Ui :: any).SystemMessageFont, Enum.Font.Gotham),
						Position = UDim2.new(0, 0, 0, -4),
						Size = UDim2.new(1, 0, 0, 18),
						Text = errorText,
						TextColor3 = Theme.Error,
						TextSize = (Ui :: any).SystemMessageTextSize or 13,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 5,
					})
					else nil,
			}),
		}),
	})
end

return ChatApp
