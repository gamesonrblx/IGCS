--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local settings = require(ReplicatedStorage:WaitForChild("IGCSConfiguration")).ChatUI

return {
	Panel = settings.PanelBackgroundColor,
	PanelStrong = settings.PanelBackgroundColor,
	Field = settings.FieldBackgroundColor,
	Outline = settings.PanelStrokeColor,
	TextPrimary = settings.TextPrimary,
	TextSecondary = settings.TextSecondary,
	TeamMessage = settings.TeamMessageText,
	TeamAccent = settings.AccentColor,
	TeamAccentMuted = settings.AccentColor,
	Error = settings.ErrorText,
}

