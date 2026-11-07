--// Steal a Balut — Keyless Script by Allain \\--
-- Loaded by the `wasd` loader when it detects Steal a Balut. Starter skeleton: UI, config and
-- anti-AFK are wired up; game-specific automation goes in the Automation tab.

--// Single-Instance Guard \\--
local env = (getgenv and getgenv()) or shared
if env.__AllainBalutLoading then
	return
end
env.__AllainBalutLoading = true

if env.__AllainBalutLibrary then
	pcall(function()
		env.__AllainBalutLibrary:Unload()
	end)
	env.__AllainBalutLibrary = nil
end

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local cloneref = (cloneref or clonereference or function(instance)
	return instance
end)

local Players = cloneref(game:GetService("Players"))
local VirtualUser = cloneref(game:GetService("VirtualUser"))

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()

--// Load Alexandria Library & SaveManager \\--
local repo = "https://raw.githubusercontent.com/Allain-afk/allain-automation-release/main/"
local okLib, Library = pcall(function()
	return loadstring(game:HttpGet(repo .. "Library.lua"))()
end)
if not okLib or not Library then
	env.__AllainBalutLoading = false
	warn("[Steal a Balut] Failed to load Alexandria Library.")
	return
end
env.__AllainBalutLibrary = Library
env.__AllainBalutLoading = false

local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options

--// Window & Tabs \\--
local Window = Library:CreateWindow({
	Title = "Steal a Balut Keyless - by Allain",
	Footer = "Allain-afk · Steal a Balut",
	FooterRight = "v0.1",
	Username = true,
	Size = UDim2.fromOffset(720, 560),
	Center = true,
	AutoShow = true,
})

local Tabs = {
	Automation = Window:AddTab("Automation", "zap"),
	Config = Window:AddTab("Config", "folder-cog"),
}

--// Automation \\--
local AutomationBox = Tabs.Automation:AddGroupbox({
	Side = "Left",
	Name = "Automation",
	IconName = "zap",
	Description = "Steal a Balut features are in progress.",
})

AutomationBox:AddLabel({ Text = "Automation features coming soon.", DoesWrap = true })

--// Anti-AFK (Idled kick prevention) \\--
local antiAfkEnabled = true
local MiscBox = Tabs.Automation:AddGroupbox({
	Side = "Right",
	Name = "AFK",
	IconName = "bell",
})

MiscBox:AddCheckbox("BalutAntiAfk", {
	Text = "Anti-AFK",
	Default = true,
	Tooltip = "Prevents the 20-minute idle kick",
	Callback = function(value)
		antiAfkEnabled = value
	end,
})

local idledConnection = player.Idled:Connect(function()
	if not antiAfkEnabled or Library.Unloaded then
		return
	end
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end)
end)

--// Config \\--
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
SaveManager:SetFolder("AllainAutomation/steal-a-balut")

local ConfigBox = Tabs.Config:AddGroupbox({
	Side = "Left",
	Name = "Menu",
	IconName = "settings",
})

ConfigBox:AddLabel("Menu Keybind"):AddKeyPicker("MenuKeybind", {
	Default = "RightShift",
	NoUI = true,
	Text = "Menu keybind",
})
Library.ToggleKeybind = Options.MenuKeybind

ConfigBox:AddButton({
	Text = "Unload Script",
	Risky = true,
	Func = function()
		Library:Unload()
	end,
})

SaveManager:BuildConfigSection(Tabs.Config)
SaveManager:LoadAutoloadConfig()

Library:OnUnload(function()
	if env.__AllainBalutLibrary == Library then
		env.__AllainBalutLibrary = nil
	end
	env.__AllainBalutLoading = false
	antiAfkEnabled = false
	if idledConnection then
		idledConnection:Disconnect()
	end
end)
