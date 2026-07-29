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
	displayName: string,
	text: string,
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

local function getPanelSize(): UDim2
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)

	if viewport.X < Ui.MobileBreakpoint then
		return Ui.MobileSize
	end

	return Ui.DesktopSize
end

local function usePanelSize(): UDim2
	local size, setSize = React.useState(getPanelSize())

	React.useEffect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			setSize(getPanelSize())
		end)
		return function()
			connection:Disconnect()
		end
	end, {})

	return size
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

local function ChannelTab(props: { label: string, active: boolean, layoutOrder: number, onActivated: () -> () })
	return React.createElement("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = Theme.PanelStrong,
		BackgroundTransparency = if props.active then Ui.ActiveTabBackgroundTransparency else 1,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
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
	local senderColor = colorToHex(if props.message.scope == "team" then Theme.TeamMessage else Theme.TextPrimary)
	local scopePrefix = if props.message.scope == "whisper" then "<font color=\"#D7A6FF\">[Whisper] </font>" else ""
	local name = escapeRichText(props.message.displayName)
	local text = escapeRichText(props.message.text)
	local richMessage = scopePrefix
		.. "<font color=\"" .. senderColor .. "\"><b>" .. name .. ":</b></font>"
		.. " <font color=\"" .. colorToHex(Theme.TextPrimary) .. "\">" .. text .. "</font>"

	return React.createElement("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
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
	if type(payload) ~= "table" or payload.system == true then
		return nil
	end

	local scope = tostring(payload.scope or "global"):lower()
	if scope ~= "global" and scope ~= "team" and scope ~= "whisper" then
		return nil
	end

	local text = tostring(payload.text or "")
	if text:match("^%s*$") then
		return nil
	end

	return {
		id = tostring(payload.t or os.clock()) .. "-" .. tostring(sequence),
		scope = scope :: Scope,
		displayName = tostring(payload.displayName or payload.fromDisplayName or payload.username or payload.fromUsername or "Player"),
		text = text,
	}
end

local function ChatApp()
	local panelSize = usePanelSize()
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
	end, { messages, activeTab })

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
			Size = panelSize,
			ZIndex = 1,
		}, {
			Corner = addCorner(Ui.PanelCornerRadius),
			Outline = addStroke(Ui.PanelStrokeColor, Ui.PanelStrokeThickness, Ui.PanelStrokeTransparency),
			Tabs = React.createElement("Frame", {
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
				Team = if not Ui.TeamTabRequiresTeam or hasTeam
					then React.createElement(ChannelTab, {
						active = activeTab == "team",
						label = "Team",
						layoutOrder = 2,
						onActivated = function()
							setActiveTab("team")
						end,
					})
					else nil,
			}),
			Messages = React.createElement("ScrollingFrame", {
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.fromOffset(0, 0),
				Position = UDim2.new(0, Ui.PanelPadding, 0, Ui.MessagesTop),
				ScrollBarImageColor3 = Ui.PanelStrokeColor,
				ScrollBarImageTransparency = Ui.PanelStrokeTransparency,
				ScrollBarThickness = 3,
				Size = UDim2.new(1, -Ui.PanelPadding * 2, 1, -Ui.MessagesTop - Ui.ComposerHeight - Ui.ComposerBottom - 4),
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
					Font = Enum.Font.Gotham,
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
						Font = Enum.Font.Gotham,
						Position = UDim2.new(0, 0, 0, -4),
						Size = UDim2.new(1, 0, 0, 18),
						Text = errorText,
						TextColor3 = Theme.Error,
						TextSize = 13,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 5,
					})
					else nil,
			}),
		}),
	})
end

return ChatApp

