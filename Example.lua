-- Alexandria example: a tour of every element, the header, theming and configs.
-- Point `repo` at your own fork if you host the files somewhere else.

local repo = "https://raw.githubusercontent.com/joustingmatch/Alexandria/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

--// Window \\--
local Window = Library:CreateWindow({
	Title = "Alexandria",
	Footer = "alexandria · example", -- centred
	FooterLeft = "discord.gg/example", -- optional corner texts; change later with
	FooterRight = "Build: dev", --         Window:SetFooterLeft / SetFooterRight

	-- Header, right side: a muted name and a filled badge pill
	Username = true, -- true shows the local player's name; a string shows that text
	Badge = "Free", -- change later with Window:SetBadge("Premium"), nil hides it

	NotifySide = "Right",

	-- Optional:
	-- Size = UDim2.fromOffset(580, 640),
	-- Center = true, AutoShow = true, Resizable = true,
	-- ShowToggleButton = true,       -- round menu button (shown on mobile by default)
	-- ToggleButtonIcon = "layout-grid",
	-- MobileButtonsSide = "Right",   -- which edge the round button starts on
	-- DisableSearch = false,         -- brings back the header search box
	-- Animations = { ToggleWindow = false }, -- instant hide instead of the fade
})

-- Tip: create the UI first, then hook logic up with Toggles/Options.X:OnChanged(...)

--// Tabs \\--
-- Icons are Lucide names: https://lucide.dev/
local Tabs = {
	Home = Window:AddTab("Home", "house"),
	Pickers = Window:AddTab("Pickers", "list"),
	Layout = Window:AddTab("Layout", "layout-panel-left"),
	Key = Window:AddKeyTab("Key System"),
	Settings = Window:AddTab("Settings", "settings"),
}

--============================================================================--
--// Home: checkboxes, buttons, sliders, inputs, labels
--============================================================================--

local Combat = Tabs.Home:AddGroupbox({
	Side = "Left",
	Name = "Combat",
	IconName = "swords",
	Description = "Checkboxes, keybinds and color pickers.",
})

-- AddToggle and AddCheckbox both make a checkbox
Combat:AddToggle("AutoParry", {
	Text = "Auto Parry",
	Default = true,
	Tooltip = "Hover text works on almost every element",
})

-- Keybinds and color pickers chain onto checkboxes and labels
Combat:AddCheckbox("SilentAim", {
	Text = "Silent Aim",
	Default = false,
}):AddKeyPicker("SilentAimKey", {
	Default = "Q",
	Mode = "Toggle", -- Always, Toggle, Hold, Press
	SyncToggleState = true, -- pressing Q flips the checkbox
	Text = "Silent Aim",
})

Combat:AddCheckbox("ShowFov", {
	Text = "Show FOV Circle",
	Default = true,
}):AddColorPicker("FovColor", {
	Default = Color3.fromRGB(232, 232, 236),
	Title = "FOV Color",
	Transparency = 0,
})

Combat:AddCheckbox("RiskyFeature", {
	Text = "Risky Feature",
	Risky = true, -- red label
})

Combat:AddCheckbox("LockedFeature", {
	Text = "Locked Feature",
	Disabled = true,
	DisabledTooltip = "Unlocks with the Premium badge",
})

local Movement = Tabs.Home:AddGroupbox({
	Side = "Left",
	Name = "Movement",
	IconName = "footprints",
})

-- Sliders: the fill glides, - / + step by one Rounding unit (hold to repeat),
-- right-click (double tap on mobile) to type a value
Movement:AddSlider("WalkSpeed", {
	Text = "Walk Speed",
	Default = 16,
	Min = 0,
	Max = 100,
	Rounding = 0,
	Suffix = " studs",
})

Movement:AddSlider("JumpPower", {
	Text = "Jump Power",
	Default = 50,
	Min = 0,
	Max = 200,
	Rounding = 0,
	HideMax = false, -- show "50/200" instead of just the value
})

Movement:AddSlider("Smoothing", {
	Text = "Aim Smoothing",
	Default = 0.4,
	Min = 0,
	Max = 1,
	Rounding = 2,
	FormatDisplayValue = function(_, Value)
		if Value == 0 then return "Instant" end
		return string.format("%d%%", Value * 100)
	end,
})

Movement:AddSlider("Compact", {
	Text = "Compact",
	Default = 3,
	Min = 1,
	Max = 10,
	Rounding = 0,
	Compact = true, -- single row, text inside the track
})

local Actions = Tabs.Home:AddGroupbox({
	Side = "Right",
	Name = "Actions",
	IconName = "mouse-pointer-click",
})

-- Buttons chain with :AddButton to sit side by side
Actions:AddButton("Teleport", function()
	Library:Notify("Teleported!", 3)
end):AddButton({
	Text = "Server Hop",
	DoubleClick = true, -- asks "Are you sure?" first
	Func = function()
		Library:Notify("Hopping servers...", 3)
	end,
})

Actions:AddButton({
	Text = "Reset Character",
	Risky = true,
	Func = function()
		print("Reset")
	end,
})

Actions:AddDivider()

Actions:AddInput("Webhook", {
	Text = "Webhook URL",
	Placeholder = "https://discord.com/api/webhooks/...",
	ClearTextOnFocus = false,
	Finished = true, -- callback only on Enter
})

Actions:AddInput("TargetFps", {
	Text = "Target FPS",
	Default = "60",
	Numeric = true,
	ClearTextOnFocus = false,
})

local Info = Tabs.Home:AddGroupbox({
	Side = "Right",
	Name = "Labels",
	IconName = "type",
})

Info:AddLabel("A plain label")
Info:AddLabel("Wrapped labels keep going onto the next line when the text is too long for one.", true)
Info:AddLabel("StatusLabel", {
	Text = "Status: idle",
	DoesWrap = false,
})
Info:AddDivider("Section")
Info:AddLabel("Keybind"):AddKeyPicker("PanicKey", {
	Default = "End",
	Mode = "Press",
	Text = "Panic",
	Callback = function()
		Library.Labels.StatusLabel:SetText("Status: panic pressed")
	end,
})

--============================================================================--
--// Pickers: dropdowns, list box, color pickers
--============================================================================--

local Dropdowns = Tabs.Pickers:AddGroupbox({
	Side = "Left",
	Name = "Dropdowns",
	IconName = "chevrons-up-down",
})

Dropdowns:AddDropdown("Hitpart", {
	Text = "Hit Part",
	Values = { "Head", "Torso", "Left Arm", "Right Arm", "Legs" },
	Default = "Head",
})

-- Searchable: the search box is focused as soon as the list opens
Dropdowns:AddDropdown("Weapon", {
	Text = "Weapon (searchable)",
	Values = {
		"Katana", "Spear", "Longsword", "Dagger", "Bow", "Crossbow",
		"Scythe", "Halberd", "Mace", "Rapier", "Greatsword", "Flail",
	},
	Default = 1,
	Searchable = true,
	MaxVisibleDropdownItems = 6,
})

Dropdowns:AddDropdown("Esp", {
	Text = "ESP Options (multi)",
	Values = { "Boxes", "Names", "Health", "Distance", "Tracers" },
	Multi = true,
	Default = { "Boxes", "Names" },
})

-- Dictionary values: keys are stored in .Value, labels are what you see
Dropdowns:AddDropdown("Region", {
	Text = "Region",
	Values = { us = "North America", eu = "Europe", asia = "Asia" },
	Default = "eu",
	DisabledValues = { "asia" },
})

Dropdowns:AddDropdown("Target", {
	Text = "Target Player",
	SpecialType = "Player",
	ExcludeLocalPlayer = true,
})

local Lists = Tabs.Pickers:AddGroupbox({
	Side = "Right",
	Name = "List Box",
	IconName = "list-checks",
	Description = "An always-open list; click a row to select it.",
})

Lists:AddListBox("Waypoint", {
	Text = "Waypoints",
	Values = { "Spawn", "Shop", "Boss Arena", "Secret Cave", "Docks", "Village", "Summit" },
	Height = 130,
	Placeholder = "No waypoints yet",
})

Lists:AddButton("Go To Waypoint", function()
	local Waypoint = Options.Waypoint.Value
	Library:Notify(Waypoint and ("Going to " .. Waypoint) or "Pick a waypoint first", 3)
end)

local Colors = Tabs.Pickers:AddGroupbox({
	Side = "Right",
	Name = "Colors",
	IconName = "palette",
})

Colors:AddLabel("Enemy Color"):AddColorPicker("EnemyColor", {
	Default = Color3.fromRGB(255, 80, 80),
})
Colors:AddLabel("Team Color"):AddColorPicker("TeamColor", {
	Default = Color3.fromRGB(80, 200, 255),
	Transparency = 0.25, -- adds a transparency slider
})

--============================================================================--
--// Layout: tabbox, scrolling and collapsed groupboxes, notifications, dialogs
--============================================================================--

local Feedback = Tabs.Layout:AddGroupbox({
	Side = "Left",
	Name = "Notifications & Dialogs",
	IconName = "bell",
})

Feedback:AddButton("Notify", function()
	Library:Notify({
		Title = "Config saved",
		Description = "Your settings were written to disk.",
		Time = 4,
	})
end):AddButton("Progress", function()
	local Steps = 5
	local Note = Library:Notify({
		Title = "Downloading assets",
		Description = "Step 0 of " .. Steps,
		Steps = Steps,
		Persist = true,
	})

	task.spawn(function()
		for Step = 1, Steps do
			task.wait(0.6)
			Note:ChangeStep(Step)
			Note:ChangeDescription("Step " .. Step .. " of " .. Steps)
		end
		task.wait(0.8)
		Note:Destroy()
	end)
end)

Feedback:AddButton("Open Dialog", function()
	Window:AddDialog("ExampleDialog", {
		Title = "Delete config?",
		Description = "This removes the config file permanently. You can't undo this.",
		FooterButtons = {
			Cancel = {
				Title = "Cancel",
				Variant = "Secondary",
				Order = 1,
				Callback = function(Dialog)
					Dialog:Dismiss()
				end,
			},
			Delete = {
				Title = "Delete",
				Variant = "Destructive",
				Order = 2,
				Callback = function(Dialog)
					Dialog:Dismiss()
					Library:Notify("Deleted", 2)
				end,
			},
		},
	})
end)

-- MaxHeight caps the box; anything past it scrolls inside
local Scrolling = Tabs.Layout:AddGroupbox({
	Side = "Left",
	Name = "Scrolling Groupbox",
	IconName = "scroll-text",
	MaxHeight = 140,
})

for Index, Name in { "No Fog", "No Blur", "No Shadows", "Full Bright", "No Particles", "No Sun Damage", "No Fall Damage", "No Stun" } do
	Scrolling:AddCheckbox("Removal" .. Index, { Text = Name })
end

local Collapsed = Tabs.Layout:AddGroupbox({
	Side = "Left",
	Name = "Collapsed Groupbox",
	IconName = "eye-off",
	Collapsed = true, -- click the arrow to expand
})
Collapsed:AddLabel("Hidden until you expand me.", true)

-- Tabboxes hold several pages in one box
local Tabbox = Tabs.Layout:AddTabbox({ Side = "Right" })

local Aimbot = Tabbox:AddTab("Aimbot")
Aimbot:AddCheckbox("AimbotEnabled", { Text = "Enabled" })
Aimbot:AddSlider("AimbotFov", { Text = "FOV", Default = 120, Min = 10, Max = 360, Rounding = 0 })

local Visuals = Tabbox:AddTab("Visuals")
Visuals:AddCheckbox("Chams", { Text = "Chams" })
Visuals:AddCheckbox("Tracers", { Text = "Tracers" })

local Header = Tabs.Layout:AddGroupbox({
	Side = "Right",
	Name = "Header",
	IconName = "panel-top",
})

Header:AddDropdown("BadgeText", {
	Text = "Badge",
	Values = { "Free", "Premium", "Beta", "None" },
	Default = "Free",
	Callback = function(Value)
		Window:SetBadge(if Value == "None" then nil else Value)
	end,
})

Header:AddInput("TitleText", {
	Text = "Title",
	Default = "Alexandria",
	ClearTextOnFocus = false,
	Callback = function(Value)
		Window:ChangeTitle(Value)
	end,
})

--============================================================================--
--// Key System
--============================================================================--

Tabs.Key:AddKeyBox({
	Title = "Alexandria",
	Subtitle = "Feature tour",
	Text = "Enter your key to continue. (Hint: Alexandria)",
	Placeholder = "your key...",
	ExpectedKey = "Alexandria", -- or Validate = function(Key) return Ok, Message end
	GetKey = "https://example.com/getkey", -- string copies the link, function runs
	Premium = function()
		Library:Notify({ Title = "Premium", Description = "Not for sale.", Time = 3 })
	end,
	Footer = "your key is saved on this device after it checks out.",
	SaveKey = "Alexandria/key.txt",
	Callback = function(Success, Key)
		if Success then
			Library:Notify({ Title = "Key accepted", Description = "Welcome in.", Time = 3 })
		end
	end,
})

--============================================================================--
--// Settings: menu, theming, configs
--============================================================================--

local MenuGroup = Tabs.Settings:AddGroupbox({
	Side = "Left",
	Name = "Menu",
	IconName = "wrench",
})

MenuGroup:AddCheckbox("KeybindMenuOpen", {
	Text = "Open Keybind Menu",
	Default = Library.KeybindFrame.Visible,
	Callback = function(Value)
		Library.KeybindFrame.Visible = Value
	end,
})
MenuGroup:AddCheckbox("KeybindMenuVisibilityControl", {
	Text = "Keybind Menu Visibility",
	Default = false,
	Callback = function(Value)
		Library.KeybindMenu:SetVisibilityControl(Value)
	end,
})
MenuGroup:AddCheckbox("ShowToggleButton", {
	Text = "Toggle Button",
	Default = Library.IsMobile,
	Callback = function(Value)
		Library:SetToggleButtonVisible(Value)
	end,
})
MenuGroup:AddCheckbox("AlwaysOnTop", {
	Text = "Always On Top",
	Default = false,
	Callback = function(Value)
		Window:SetAlwaysOnTop(Value)
	end,
})
MenuGroup:AddDropdown("NotificationSide", {
	Text = "Notification Side",
	Values = { "Left", "Right" },
	Default = "Right",
	Callback = function(Value)
		Library:SetNotifySide(Value)
	end,
})
MenuGroup:AddDropdown("DPIDropdown", {
	Text = "DPI Scale",
	Values = { "50%", "75%", "100%", "125%", "150%", "175%", "200%" },
	Default = "100%",
	Callback = function(Value)
		Library:SetDPIScale(tonumber((Value:gsub("%%", ""))))
	end,
})
MenuGroup:AddSlider("UICornerSlider", {
	Text = "Corner Radius",
	Default = Library.CornerRadius,
	Min = 0,
	Max = 20,
	Rounding = 0,
	Callback = function(Value)
		Window:SetCornerRadius(Value)
	end,
})

MenuGroup:AddDivider()
MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
	Default = "RightShift",
	NoUI = true,
	Text = "Menu keybind",
})
MenuGroup:AddButton("Unload", function()
	Library:Unload()
end)

Library.ToggleKeybind = Options.MenuKeybind

-- Managers
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings() -- configs shouldn't carry theme colors
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })

-- Themes live in a shared folder, configs per game (and per place if you want)
ThemeManager:SetFolder("Alexandria")
SaveManager:SetFolder("Alexandria/example-game")

SaveManager:BuildConfigSection(Tabs.Settings) -- right side
ThemeManager:ApplyToTab(Tabs.Settings) -- left side, under Menu

SaveManager:LoadAutoloadConfig()

--// Logic \\--
-- Hook behaviour up after the UI exists
Toggles.AutoParry:OnChanged(function(Value)
	Library.Labels.StatusLabel:SetText("Status: auto parry " .. (Value and "on" or "off"))
end)

Options.WalkSpeed:OnChanged(function(Value)
	local Humanoid = Library.LocalPlayer.Character and Library.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	if Humanoid then
		Humanoid.WalkSpeed = Value
	end
end)

Library:OnUnload(function()
	print("Alexandria unloaded")
end)
