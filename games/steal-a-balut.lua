--// Steal a Balut — Keyless Script by Allain \\--
-- Loaded by the `wasd` loader when it detects Steal a Balut.
-- Movement is normal walking only (Humanoid:Move at the character's own WalkSpeed): no teleports,
-- no WalkSpeed changes. Eggs are broken with the in-game Auto Swing (or by clicking with the Asarol),
-- pets are stolen by holding E on their StealPrompt, the same way a player does it.

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
local HttpService = cloneref(game:GetService("HttpService"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local RunService = cloneref(game:GetService("RunService"))
local CoreGui = cloneref(game:GetService("CoreGui"))
local VirtualInputManager = pcall(function()
	return game:GetService("VirtualInputManager")
end) and cloneref(game:GetService("VirtualInputManager")) or nil

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
local Toggles = Library.Toggles

--// Window & Tabs \\--
local Window = Library:CreateWindow({
	Title = "Steal a Balut Keyless - by Allain",
	Footer = "Allain-afk · Steal a Balut",
	FooterRight = "v0.2",
	Username = true,
	Size = UDim2.fromOffset(820, 640),
	Center = true,
	AutoShow = true,
})

local Tabs = {
	Automation = Window:AddTab("Automation", "zap"),
	Visuals = Window:AddTab("Visuals", "eye"),
	Scan = Window:AddTab("Alerts & Scan", "bell"),
	Config = Window:AddTab("Config", "folder-cog"),
}

--============================================================================--
--// Shared helpers
--============================================================================--
-- Module tables instead of top-level locals: the executor compiles at -O0 and caps a function at 200 live locals.
local Util = {
	SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp" },
	RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Divine", "Secret" },
	RARITY_COLORS = {
		Common = Color3.fromRGB(205, 205, 205),
		Uncommon = Color3.fromRGB(90, 220, 90),
		Rare = Color3.fromRGB(70, 150, 255),
		Epic = Color3.fromRGB(180, 90, 255),
		Legendary = Color3.fromRGB(255, 190, 40),
		Mythic = Color3.fromRGB(255, 70, 70),
		Divine = Color3.fromRGB(255, 240, 150),
		Secret = Color3.fromRGB(40, 255, 230),
	},
	ZONES = { "Zone 1", "Zone 2", "Zone 3", "Zone 4", "Zone 5", "Zone 6", "Zone 7", "Zone 8", "Zone 9" },
}
Util.RARITY_RANK = {}
for i, r in ipairs(Util.RARITIES) do
	Util.RARITY_RANK[r] = i
end

function Util.formatNumber(n)
	n = tonumber(n) or 0
	local sign = n < 0 and "-" or ""
	n = math.abs(n)
	local i = 0
	while n >= 1000 and i < #Util.SUFFIXES do
		n /= 1000
		i += 1
	end
	local s = string.format("%.2f", n):gsub("(%..-)0+$", "%1"):gsub("%.$", "")
	return sign .. s .. (Util.SUFFIXES[i] or "")
end

-- "500M" / "2.5B" / "1,000" -> number (0 when unreadable)
function Util.parseNumber(str)
	if typeof(str) == "number" then
		return str
	end
	str = tostring(str or ""):gsub("[%s,%$]", "")
	local num, suffix = str:match("^([%d%.]+)(%a*)")
	num = tonumber(num)
	if not num then
		return 0
	end
	if suffix ~= "" then
		for i, s in ipairs(Util.SUFFIXES) do
			if s:lower() == suffix:lower() then
				return num * 1000 ^ i
			end
		end
	end
	return num
end

function Util.flat(fromPos, toPos)
	return Vector3.new(toPos.X - fromPos.X, 0, toPos.Z - fromPos.Z)
end

function Util.serverNow()
	local ok, t = pcall(function()
		return workspace:GetServerTimeNow()
	end)
	return ok and t or os.time()
end

-- Multi-dropdown value ({name = true}); an empty selection means "any"
function Util.selected(value, selection)
	if typeof(selection) ~= "table" or next(selection) == nil then
		return true
	end
	return selection[value] == true
end

function Util.hasSelection(selection)
	if typeof(selection) ~= "table" then
		return false
	end
	for _, on in pairs(selection) do
		if on then
			return true
		end
	end
	return false
end

function Util.sendKey(keyCode, isDown)
	if VirtualInputManager then
		pcall(function()
			VirtualInputManager:SendKeyEvent(isDown, keyCode, false, game)
		end)
	end
end

-- Presses an in-game GUI button the way Break and Steal does (signal first, real click as fallback)
function Util.clickGui(btn)
	local fired = false
	if typeof(firesignal) == "function" then
		fired = pcall(function()
			firesignal(btn.Activated)
		end) or fired
		fired = pcall(function()
			firesignal(btn.MouseButton1Click)
		end) or fired
	end
	local getconns = getconnections or get_signal_cons
	if not fired and getconns then
		for _, sig in ipairs({ btn.Activated, btn.MouseButton1Click }) do
			pcall(function()
				for _, conn in pairs(getconns(sig)) do
					if conn.Fire then
						conn:Fire()
						fired = true
					elseif conn.Function then
						task.spawn(conn.Function)
						fired = true
					end
				end
			end)
		end
	end
	if not fired and VirtualInputManager then
		pcall(function()
			local center = btn.AbsolutePosition + btn.AbsoluteSize / 2
			VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 0)
			task.wait(0.04)
			VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 0)
			fired = true
		end)
	end
	return fired
end

--============================================================================--
--// Automation UI
--============================================================================--
local Farm -- filled in by the Farm Engine section below; declared here so UI callbacks can reach it
local FarmBox = Tabs.Automation:AddGroupbox({
	Side = "Left",
	Name = "Egg Auto-Farm",
	IconName = "egg",
	Description = "Walks to baluts and breaks them. Normal walking only, no teleports.",
})

FarmBox:AddCheckbox("BalutFarmEggs", {
	Text = "Enable Egg Auto-Farm",
	Default = false,
	Tooltip = "Runs to matching baluts and breaks them with the in-game Auto Swing",
}):AddKeyPicker("BalutFarmEggsKey", {
	Default = "H",
	Mode = "Toggle",
	SyncToggleState = true,
	Text = "Egg Auto-Farm",
})

FarmBox:AddDropdown("BalutFarmZones", {
	Text = "Zones",
	Values = table.clone(Util.ZONES),
	Multi = true,
	Default = {},
	Tooltip = "Zones to farm. Leave empty for any zone",
})

FarmBox:AddDropdown("BalutFarmRarities", {
	Text = "Egg Rarity Filter",
	Values = table.clone(Util.RARITIES),
	Multi = true,
	Searchable = true,
	Default = {},
	Tooltip = "Egg rarities to break. Leave empty for any rarity",
})

FarmBox:AddInput("BalutFarmMaxHp", {
	Text = "Max Egg HP (e.g. 50M, 2B)",
	Default = "0",
	Placeholder = "0 = Any",
	ClearTextOnFocus = false,
	Tooltip = "Skip eggs with more HP than this, so you don't spend minutes on one egg",
})

FarmBox:AddDropdown("BalutFarmPriority", {
	Text = "Priority",
	Values = { "Closest", "Lowest HP", "Highest Rarity" },
	Default = "Closest",
})

FarmBox:AddCheckbox("BalutUseAutoSwing", {
	Text = "Use In-Game Auto Swing",
	Default = true,
	Tooltip = "Turns on the game's Auto Swing button. If it can't, the farm clicks with your Asarol instead",
})

FarmBox:AddCheckbox("BalutBestAsarol", {
	Text = "Auto Equip Best Asarol",
	Default = true,
	Tooltip = "Equips your strongest owned Asarol before farming. The first time, it equips each one once to read its power (saved for next time)",
})

FarmBox:AddButton({
	Text = "Re-check Asarol Power",
	Tooltip = "Forget the saved Asarol powers and measure them again on the next farm pass",
	Func = function()
		if Farm then
			Farm.resetAsarolPower()
			Library:Notify("Asarol powers will be re-checked on the next farm pass.", 3)
		end
	end,
})

local StealBox = Tabs.Automation:AddGroupbox({
	Side = "Right",
	Name = "Auto-Steal Pets",
	IconName = "hand",
	Description = "Holds E on wild pets, then walks them home to your base.",
})

StealBox:AddCheckbox("BalutStealPets", {
	Text = "Enable Auto-Steal",
	Default = false,
	Tooltip = "Steals wild pets that match the filters below and carries them to your base",
}):AddKeyPicker("BalutStealPetsKey", {
	Default = "J",
	Mode = "Toggle",
	SyncToggleState = true,
	Text = "Auto-Steal",
})

StealBox:AddCheckbox("BalutStealMine", {
	Text = "Always Take Pets I Hatch",
	Default = true,
	Tooltip = "Takes the pet from every egg the farm breaks, ignoring the filters (works with only Egg Auto-Farm on too)",
})

StealBox:AddDropdown("BalutStealRarities", {
	Text = "Pet Rarity Filter",
	Values = table.clone(Util.RARITIES),
	Multi = true,
	Searchable = true,
	Default = {},
	Tooltip = "Wild pet rarities to steal. Leave empty for any rarity",
})

StealBox:AddInput("BalutStealMinIncome", {
	Text = "Min Income/s (e.g. 500K, 10M)",
	Default = "0",
	Placeholder = "0 = Any",
	ClearTextOnFocus = false,
})

StealBox:AddCheckbox("BalutEquipBest", {
	Text = "Auto Equip Best After Storing",
	Default = true,
	Tooltip = "Presses the game's Equip Best after each pet reaches your base",
})

local SafetyBox = Tabs.Automation:AddGroupbox({
	Side = "Left",
	Name = "Guard Avoidance",
	IconName = "shield-alert",
})

SafetyBox:AddCheckbox("BalutAvoidGuards", {
	Text = "Avoid Guards",
	Default = true,
	Tooltip = "Skips eggs and pets near guards and backs off when a guard is alerted or chasing",
})

SafetyBox:AddSlider("BalutGuardDistance", {
	Text = "Guard Safe Distance",
	Default = 25,
	Min = 10,
	Max = 80,
	Rounding = 0,
	Suffix = " studs",
	Tooltip = "Alerted/chasing guards are avoided within this distance, calm guards within half of it",
})

local StatusBox = Tabs.Automation:AddGroupbox({
	Side = "Right",
	Name = "Status",
	IconName = "activity",
})

local FarmLabels = {
	State = StatusBox:AddLabel({ Text = "State: Idle", DoesWrap = true }),
	Target = StatusBox:AddLabel({ Text = "Target: None", DoesWrap = true }),
	Stats = StatusBox:AddLabel({ Text = "Eggs broken: 0 · Pets stolen: 0 · Stored: 0", DoesWrap = true }),
	Scan = StatusBox:AddLabel({ Text = "", DoesWrap = true }),
}

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

--============================================================================--
--// Farm Engine (egg breaking, pet stealing, carrying home)
--============================================================================--
-- Game layout (from the data scan):
--   workspace.ActiveEggs.<Model>   attrs HP, MaxHP, ZoneId, Rarity, EggName; child "Hitbox"
--   workspace.WildPets.<Model>     attrs PetName, Rarity, Income, Mutation, ExpireAt, State="Wild", Born;
--                                  RootPart.StealPrompt (hold ~1s)
--   workspace.Map.Plots.PlotN      attr OwnerUserId; child PlayerSpawn; Trisikad (attr Rider)
--   workspace.Map.Decor.Guards     guard models; their state arrives through Remotes.GuardFx
--   player attrs Carrying (pet id while carrying), AutoSwing (in-game Auto Swing state)
Farm = {
	RENDER_STEP = "AllainBalutFarmMove",
	moveDir = nil,
	skippedEggs = setmetatable({}, { __mode = "k" }),
	skippedPets = setmetatable({}, { __mode = "k" }),
	guardState = setmetatable({}, { __mode = "k" }),
	stats = { eggs = 0, stolen = 0, stored = 0, failed = 0, guards = 0 },
	eggScan = { total = 0, filtered = 0, guarded = 0 },
	petScan = { total = 0, filtered = 0, guarded = 0, expiring = 0 },
	lastBreak = nil, -- { pos = Vector3, at = server time } of the last egg the farm broke
	carryInfo = nil, -- pet the farm is carrying home
	lastDismount = 0,
	lastEquip = 0,
	lastActivate = 0,
	lastAutoSwingClick = 0,
	autoSwingTries = 0,
	lastState = nil,
	lastTarget = nil,
	conns = {},
	onStored = nil, -- set by the Alerts section
}

function Farm.setState(text)
	if Farm.lastState ~= text then
		Farm.lastState = text
		FarmLabels.State:SetText("State: " .. text)
	end
end

function Farm.setTarget(text)
	if Farm.lastTarget ~= text then
		Farm.lastTarget = text
		FarmLabels.Target:SetText(text)
	end
end

function Farm.remote(name)
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	return folder and folder:FindFirstChild(name)
end

function Farm.character()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if hum and root and hum.Health > 0 then
		return char, hum, root
	end
	return nil
end

function Farm.active()
	return not Library.Unloaded and (Toggles.BalutFarmEggs.Value or Toggles.BalutStealPets.Value)
end

function Farm.carrying()
	local v = player:GetAttribute("Carrying")
	return v ~= nil and v ~= ""
end

--// Movement: steer with Humanoid:Move after the default ControlModule (it zeroes moves set earlier in the frame)
function Farm.applyMove()
	local dir = Farm.moveDir
	if not dir then
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		hum:Move(dir, false)
	end
end

pcall(function()
	RunService:UnbindFromRenderStep(Farm.RENDER_STEP)
end)
if not pcall(function()
	RunService:BindToRenderStep(Farm.RENDER_STEP, Enum.RenderPriority.Character.Value + 1, Farm.applyMove)
end) then
	Farm.moveConn = RunService.RenderStepped:Connect(Farm.applyMove)
end

function Farm.stop()
	Farm.moveDir = nil
	pcall(function()
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:Move(Vector3.zero, false)
		end
	end)
end

--// Base / plot
function Farm.myPlot()
	local map = workspace:FindFirstChild("Map")
	local plots = map and map:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	for _, plot in ipairs(plots:GetChildren()) do
		if plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot
		end
	end
	local id = player:GetAttribute("PlotId")
	return id and plots:FindFirstChild("Plot" .. tostring(id)) or nil
end

function Farm.homePos()
	local plot = Farm.myPlot()
	if not plot then
		return nil
	end
	local spawnPart = plot:FindFirstChild("PlayerSpawn")
	if spawnPart and spawnPart:IsA("BasePart") then
		return spawnPart.Position
	end
	local ok, pivot = pcall(function()
		return plot:GetPivot()
	end)
	return ok and pivot.Position or nil
end

-- The farm walks, so get off the Trisikad first (same remote the game's own dismount uses)
-- Riding = the character says so (RideKind) and my plot's Trisikad lists me as Rider, or I'm seated.
-- Gives up after 3 tries in case one of those attributes is stale.
function Farm.ensureOnFoot(char, hum)
	local plot = Farm.myPlot()
	local trisikad = plot and plot:FindFirstChild("Trisikad")
	local riding = hum.SeatPart ~= nil
		or (char:GetAttribute("RideKind") ~= nil and trisikad ~= nil and trisikad:GetAttribute("Rider") == player.UserId)
	if not riding then
		Farm.dismountTries = 0
		return
	end
	if (Farm.dismountTries or 0) >= 3 or os.clock() - Farm.lastDismount < 3 then
		return
	end
	Farm.dismountTries = (Farm.dismountTries or 0) + 1
	Farm.lastDismount = os.clock()
	Farm.setState("Getting off the Trisikad...")
	local remote = Farm.remote("TrisikadDismount")
	if remote then
		pcall(function()
			remote:FireServer()
		end)
	end
	if hum.SeatPart then
		hum.Jump = true
	end
	task.wait(0.5)
end

--// Guards
function Farm.guardFolder()
	local map = workspace:FindFirstChild("Map")
	local decor = map and map:FindFirstChild("Decor")
	return decor and decor:FindFirstChild("Guards")
end

function Farm.threats()
	if not Toggles.BalutAvoidGuards.Value then
		return {}
	end
	if Farm.threatCache and os.clock() - Farm.threatCacheAt < 0.2 then
		return Farm.threatCache
	end
	local list = {}
	local folder = Farm.guardFolder()
	for _, guard in ipairs(folder and folder:GetChildren() or {}) do
		if guard:IsA("Model") then
			local root = guard:FindFirstChild("HumanoidRootPart") or guard.PrimaryPart or guard:FindFirstChildWhichIsA("BasePart")
			if root then
				local st = Farm.guardState[guard]
				local hot = st ~= nil and (st.state == "Chase" or st.state == "Alert") and os.clock() - st.at < 20
				table.insert(list, { pos = root.Position, hot = hot })
			end
		end
	end
	Farm.threatCache, Farm.threatCacheAt = list, os.clock()
	return list
end

-- Alerted/chasing guards count within the safe distance, calm guards within half of it
function Farm.threatNear(pos)
	local safe = tonumber(Options.BalutGuardDistance.Value) or 25
	for _, threat in ipairs(Farm.threats()) do
		local d = Util.flat(threat.pos, pos).Magnitude
		if d <= (threat.hot and safe or safe * 0.5) then
			return threat
		end
	end
	return nil
end

-- Runs (normal walking) to getPos(). Returns "arrived", "guard" (+ threat), "stuck" or "stopped"
function Farm.runTo(hum, root, getPos, reach, stillValid, label, avoidGuards)
	local first = getPos()
	if not first then
		return "stopped"
	end
	local startDist = Util.flat(root.Position, first).Magnitude
	local deadline = os.clock() + startDist / math.max(hum.WalkSpeed, 16) * 2 + 6
	local lastPos, lastMoveAt, jumps, lastLabel = root.Position, os.clock(), 0, 0

	while Farm.active() and hum.Health > 0 and root.Parent and stillValid() do
		local target = getPos()
		if not target then
			break
		end
		local delta = Util.flat(root.Position, target)
		if delta.Magnitude <= reach then
			Farm.stop()
			return "arrived"
		end
		if avoidGuards then
			local threat = Farm.threatNear(root.Position)
			if threat then
				Farm.stop()
				return "guard", threat
			end
		end

		Farm.moveDir = delta.Unit
		if os.clock() - lastLabel > 0.25 then
			lastLabel = os.clock()
			Farm.setState(string.format("Running to %s (%dm)", label, math.floor(delta.Magnitude + 0.5)))
		end

		-- Unstuck: jump when blocked, give up after a few tries
		if (root.Position - lastPos).Magnitude > 2 then
			lastPos, lastMoveAt = root.Position, os.clock()
		elseif os.clock() - lastMoveAt > 1 then
			hum.Jump = true
			jumps += 1
			lastPos, lastMoveAt = root.Position, os.clock()
		end
		if jumps >= 4 or os.clock() > deadline then
			Farm.stop()
			return "stuck"
		end
		RunService.Heartbeat:Wait()
	end
	Farm.stop()
	return "stopped"
end

function Farm.retreat(hum, root, fromPos)
	Farm.stats.guards += 1
	Farm.setState("Avoiding guard!")
	local untilT = os.clock() + 1.5
	local safe = tonumber(Options.BalutGuardDistance.Value) or 25
	while Farm.active() and hum.Health > 0 and os.clock() < untilT do
		local away = Util.flat(fromPos, root.Position)
		if away.Magnitude >= safe * 1.3 then
			break
		end
		Farm.moveDir = away.Magnitude > 0.1 and away.Unit or -root.CFrame.LookVector
		RunService.Heartbeat:Wait()
	end
	Farm.stop()
end

--// Swinging: in-game Auto Swing first, clicking with the Asarol as fallback
function Farm.isEggTool(tool)
	return tool ~= nil and tool:IsA("Tool") and tool:GetAttribute("AsarolId") ~= nil
end

function Farm.ensureTool(char, hum)
	local held = char:FindFirstChildOfClass("Tool")
	if Farm.isEggTool(held) then
		return held
	end
	if os.clock() - Farm.lastEquip < 1 then
		return nil
	end
	Farm.lastEquip = os.clock()
	local backpack = player:FindFirstChild("Backpack")
	local fallback = nil
	for _, tool in ipairs(backpack and backpack:GetChildren() or {}) do
		if Farm.isEggTool(tool) then
			fallback = tool
			break
		elseif tool:IsA("Tool") and tool:GetAttribute("BatId") == nil and not fallback then
			fallback = tool -- egg tool without the attribute: anything that isn't the bat
		end
	end
	if fallback then
		pcall(function()
			hum:EquipTool(fallback)
		end)
	end
	return fallback
end

function Farm.autoSwingButton()
	local gui = player:FindFirstChild("PlayerGui")
	local hud = gui and gui:FindFirstChild("HudGui")
	local main = hud and hud:FindFirstChild("Main")
	local btn = main and main:FindFirstChild("AutoSwing")
	return btn and btn:IsA("GuiButton") and btn or nil
end

function Farm.swing(tool)
	if player:GetAttribute("AutoSwing") == true then
		Farm.autoSwingTries = 0
		return
	end
	if Toggles.BalutUseAutoSwing.Value and Farm.autoSwingTries < 3 and os.clock() - Farm.lastAutoSwingClick > 2 then
		Farm.lastAutoSwingClick = os.clock()
		local btn = Farm.autoSwingButton()
		if btn then
			Farm.autoSwingTries += 1
			Util.clickGui(btn)
			return
		end
	end
	if tool and tool.Parent == player.Character and os.clock() - Farm.lastActivate > 0.25 then
		Farm.lastActivate = os.clock()
		pcall(function()
			tool:Activate()
		end)
	end
end

--// Best Asarol: damage comes from the equipped Asarol's power (server-side), e.g. Iron 15 vs Bathala 150M.
-- The game doesn't expose each Asarol's power, so equip each owned one once, read AsarolPower, and cache it.
Farm.asarol = {
	power = {}, -- name -> power (-1 = couldn't equip this session)
	FOLDER = "AllainAutomation/steal-a-balut",
	FILE = "AllainAutomation/steal-a-balut/asarol-power.json",
	lastOwned = nil,
	lastEquipped = nil,
	summary = nil,
}

pcall(function()
	if isfile and readfile and isfile(Farm.asarol.FILE) then
		for name, power in pairs(HttpService:JSONDecode(readfile(Farm.asarol.FILE))) do
			if typeof(power) == "number" then
				Farm.asarol.power[name] = power
			end
		end
	end
end)

function Farm.saveAsarolPower()
	if not writefile then
		return
	end
	pcall(function()
		if makefolder and isfolder then
			if not isfolder("AllainAutomation") then
				makefolder("AllainAutomation")
			end
			if not isfolder(Farm.asarol.FOLDER) then
				makefolder(Farm.asarol.FOLDER)
			end
		end
		local data = {}
		for name, power in pairs(Farm.asarol.power) do
			if power >= 0 then
				data[name] = power
			end
		end
		writefile(Farm.asarol.FILE, HttpService:JSONEncode(data))
	end)
end

function Farm.resetAsarolPower()
	local a = Farm.asarol
	a.power, a.lastOwned, a.lastEquipped, a.summary = {}, nil, nil, nil
	if delfile and isfile then
		pcall(function()
			if isfile(a.FILE) then
				delfile(a.FILE)
			end
		end)
	end
end

function Farm.ownedAsarols()
	local list = {}
	for name in tostring(player:GetAttribute("OwnedAsarols") or ""):gmatch("[^,]+") do
		name = name:match("^%s*(.-)%s*$")
		if name ~= "" and not table.find(list, name) then
			table.insert(list, name)
		end
	end
	return list
end

-- Same call the game's Asarol shop makes; waits until the server confirms the swap
function Farm.equipAsarol(name)
	local remote = Farm.remote("AsarolShop")
	if not remote then
		return false
	end
	local ok = pcall(function()
		remote:InvokeServer("Equip", name)
	end)
	local untilT = os.clock() + 2
	while player:GetAttribute("EquippedAsarol") ~= name and os.clock() < untilT do
		task.wait(0.1)
	end
	task.wait(0.2) -- AsarolPower is set alongside EquippedAsarol; give it a moment
	return ok and player:GetAttribute("EquippedAsarol") == name
end

function Farm.ensureBestAsarol()
	if not Toggles.BalutBestAsarol.Value then
		return
	end
	local a = Farm.asarol
	local owned, equipped = player:GetAttribute("OwnedAsarols"), player:GetAttribute("EquippedAsarol")
	if owned == nil or (owned == a.lastOwned and equipped == a.lastEquipped) then
		return -- nothing changed since the last check
	end

	-- The equipped one can be read for free
	local nowPower = tonumber(player:GetAttribute("AsarolPower"))
	if equipped and nowPower then
		a.power[equipped] = nowPower
	end

	local names = Farm.ownedAsarols()
	local measured, complete = false, true
	for _, name in ipairs(names) do
		if a.power[name] == nil then
			if not Toggles.BalutFarmEggs.Value or Library.Unloaded then
				complete = false
				break
			end
			Farm.setState("Checking Asarol power: " .. name .. "...")
			if Farm.equipAsarol(name) then
				a.power[name] = tonumber(player:GetAttribute("AsarolPower")) or 0
			else
				a.power[name] = -1
			end
			measured = true
			task.wait(0.4)
		end
	end
	if measured then
		Farm.saveAsarolPower()
	end

	local best, bestPower = nil, nil
	for _, name in ipairs(names) do
		local p = a.power[name]
		if p and p >= 0 and (not bestPower or p > bestPower) then
			best, bestPower = name, p
		end
	end
	if best and best ~= player:GetAttribute("EquippedAsarol") then
		Farm.setState("Equipping best Asarol: " .. best .. "...")
		Farm.equipAsarol(best)
	end
	if best then
		a.summary = string.format("%s (%s power)", best, Util.formatNumber(bestPower))
	end
	if complete then
		a.lastOwned, a.lastEquipped = player:GetAttribute("OwnedAsarols"), player:GetAttribute("EquippedAsarol")
	end
end

--// Eggs
function Farm.eggRoot(egg)
	return egg:FindFirstChild("Hitbox") or egg.PrimaryPart or egg:FindFirstChildWhichIsA("BasePart")
end

function Farm.eggAlive(egg, folder)
	if not egg.Parent or egg.Parent ~= (folder or workspace:FindFirstChild("ActiveEggs")) then
		return false
	end
	local hp = tonumber(egg:GetAttribute("HP"))
	return hp == nil or hp > 0
end

function Farm.findEgg(root)
	local folder = workspace:FindFirstChild("ActiveEggs")
	local scan = { total = 0, filtered = 0, guarded = 0 }
	Farm.eggScan = scan
	if not folder then
		return nil
	end
	local zones, rarities = Options.BalutFarmZones.Value, Options.BalutFarmRarities.Value
	local maxHp = Util.parseNumber(Options.BalutFarmMaxHp.Value)
	local priority = Options.BalutFarmPriority.Value
	local best = nil

	for _, egg in ipairs(folder:GetChildren()) do
		local part = egg:IsA("Model") and Farm.eggAlive(egg, folder) and Farm.eggRoot(egg)
		local skipUntil = Farm.skippedEggs[egg]
		if part and not (skipUntil and os.clock() < skipUntil) then
			scan.total += 1
			local rarity = tostring(egg:GetAttribute("Rarity") or "")
			local hp = tonumber(egg:GetAttribute("HP")) or math.huge
			local zone = tostring(egg:GetAttribute("ZoneId") or "?")
			if not Util.selected("Zone " .. zone, zones) or not Util.selected(rarity, rarities) or (maxHp > 0 and hp > maxHp) then
				scan.filtered += 1
			elseif Farm.threatNear(part.Position) then
				scan.guarded += 1
			else
				local c = {
					egg = egg,
					part = part,
					name = tostring(egg:GetAttribute("EggName") or egg.Name),
					rarity = rarity,
					rank = Util.RARITY_RANK[rarity] or 0,
					zone = zone,
					hp = hp,
					dist = Util.flat(root.Position, part.Position).Magnitude,
				}
				local better
				if not best then
					better = true
				elseif priority == "Lowest HP" then
					better = c.hp < best.hp or (c.hp == best.hp and c.dist < best.dist)
				elseif priority == "Highest Rarity" then
					better = c.rank > best.rank or (c.rank == best.rank and c.dist < best.dist)
				else
					better = c.dist < best.dist
				end
				if better then
					best = c
				end
			end
		end
	end
	return best
end

-- True when a pet worth taking right now exists (used to interrupt long egg breaks)
function Farm.petWaiting(root, hum)
	if not (Toggles.BalutStealPets.Value or Toggles.BalutStealMine.Value) then
		return false
	end
	return Farm.findPet(root, hum, not Toggles.BalutStealPets.Value) ~= nil
end

function Farm.breakEgg(char, hum, root, c)
	local egg, part = c.egg, c.part
	local hpText = c.hp < math.huge and (Util.formatNumber(c.hp) .. " HP") or "?"
	Farm.setTarget(string.format("Egg: %s (%s, Zone %s) · %s", c.name, c.rarity, c.zone, hpText))

	local reach = math.clamp(math.max(part.Size.X, part.Size.Z) / 2 + 4, 5, 14)
	local status, threat = Farm.runTo(hum, root, function()
		return part.Parent and part.Position or nil
	end, reach, function()
		return Toggles.BalutFarmEggs.Value and Farm.eggAlive(egg)
	end, c.name, true)

	if status == "guard" then
		Farm.skippedEggs[egg] = os.clock() + 15
		Farm.retreat(hum, root, threat.pos)
		return
	elseif status == "stuck" then
		Farm.skippedEggs[egg] = os.clock() + 20
		Farm.setTarget("Egg: Unreachable, skipping...")
		return
	elseif status ~= "arrived" then
		return
	end

	Farm.setState("Breaking " .. c.name .. "...")
	local lastHp = tonumber(egg:GetAttribute("HP"))
	local lastHpAt, lastNudge, lastPetCheck = os.clock(), os.clock(), os.clock()
	local lastPos = part.Position
	threat = nil

	while Toggles.BalutFarmEggs.Value and not Library.Unloaded and hum.Health > 0 and Farm.eggAlive(egg) do
		lastPos = part.Position
		local delta = Util.flat(root.Position, part.Position)
		if delta.Magnitude > reach + 4 then
			break -- pushed away; the main loop re-targets
		end
		threat = Farm.threatNear(root.Position)
		if threat then
			break
		end
		if os.clock() - lastPetCheck > 1 then
			lastPetCheck = os.clock()
			if Farm.petWaiting(root, hum) then
				return -- hatched/wild pets despawn, eggs don't: go take the pet first
			end
		end

		local tool = Farm.ensureTool(char, hum)
		Farm.swing(tool or char:FindFirstChildOfClass("Tool"))

		local hpNow = tonumber(egg:GetAttribute("HP"))
		if hpNow ~= lastHp then
			lastHp, lastHpAt, lastNudge = hpNow, os.clock(), os.clock()
		elseif os.clock() - lastNudge > 3 and delta.Magnitude > 0.5 then
			-- No damage: step toward the egg briefly so the character faces it
			lastNudge = os.clock()
			Farm.moveDir = delta.Unit
			task.wait(0.15)
			Farm.stop()
		end
		if os.clock() - lastHpAt > 20 then
			Farm.skippedEggs[egg] = os.clock() + 30
			Farm.setTarget("Egg: No damage for 20s, skipping...")
			return
		end
		task.wait(0.1)
	end

	if threat then
		Farm.skippedEggs[egg] = os.clock() + 15
		Farm.retreat(hum, root, threat.pos)
		return
	end
	if not Farm.eggAlive(egg) then
		Farm.stats.eggs += 1
		Farm.lastBreak = { pos = lastPos, at = Util.serverNow() }
		Farm.setTarget("Egg: Broken! Looking for the hatched pet...")
		task.wait(0.3)
	end
end

--// Wild pets
function Farm.petRoot(pet)
	return pet:FindFirstChild("RootPart") or pet.PrimaryPart
end

function Farm.petPrompt(pet)
	local root = Farm.petRoot(pet)
	local prompt = root and root:FindFirstChild("StealPrompt")
	return prompt and prompt:IsA("ProximityPrompt") and prompt or nil
end

function Farm.petAvailable(pet, folder)
	if pet.Parent ~= folder then
		return false
	end
	local state = pet:GetAttribute("State")
	if state ~= nil and state ~= "Wild" then
		return false
	end
	local prompt = Farm.petPrompt(pet)
	return prompt ~= nil and prompt.Enabled
end

-- Pet that hatched from the egg the farm just broke
function Farm.isMyHatch(pet)
	local lb = Farm.lastBreak
	local root = Farm.petRoot(pet)
	if not lb or not root then
		return false
	end
	local born = tonumber(pet:GetAttribute("Born")) or 0
	return born >= lb.at - 3 and born <= lb.at + 8 and Util.flat(root.Position, lb.pos).Magnitude < 40
end

function Farm.findPet(root, hum, onlyMine)
	local folder = workspace:FindFirstChild("WildPets")
	local scan = { total = 0, filtered = 0, guarded = 0, expiring = 0 }
	Farm.petScan = scan
	if not folder then
		return nil
	end
	local rarities = Options.BalutStealRarities.Value
	local minIncome = Util.parseNumber(Options.BalutStealMinIncome.Value)
	local takeMine = Toggles.BalutStealMine.Value
	local now = Util.serverNow()
	local speed = math.max(hum.WalkSpeed, 16)
	local best = nil

	for _, pet in ipairs(folder:GetChildren()) do
		local proot = pet:IsA("Model") and Farm.petAvailable(pet, folder) and Farm.petRoot(pet)
		local skipUntil = Farm.skippedPets[pet]
		if proot and not (skipUntil and os.clock() < skipUntil) then
			scan.total += 1
			local mine = takeMine and Farm.isMyHatch(pet)
			local income = tonumber(pet:GetAttribute("Income")) or 0
			local rarity = tostring(pet:GetAttribute("Rarity") or "")
			local dist = Util.flat(root.Position, proot.Position).Magnitude
			local expireAt = tonumber(pet:GetAttribute("ExpireAt"))
			if onlyMine and not mine then
				scan.filtered += 1
			elseif not mine and (not Util.selected(rarity, rarities) or income < minIncome) then
				scan.filtered += 1
			elseif expireAt and expireAt - now < dist / speed + 2.5 then
				scan.expiring += 1
			elseif Farm.threatNear(proot.Position) then
				scan.guarded += 1
			else
				local c = {
					pet = pet,
					root = proot,
					name = tostring(pet:GetAttribute("PetName") or pet.Name),
					rarity = rarity,
					income = income,
					mutation = tostring(pet:GetAttribute("Mutation") or "None"),
					dist = dist,
					mine = mine,
				}
				if not best
					or (c.mine and not best.mine)
					or (c.mine == best.mine and (c.income > best.income or (c.income == best.income and c.dist < best.dist)))
				then
					best = c
				end
			end
		end
	end
	return best
end

-- Real E key hold (like a player); fireproximityprompt only when the executor can't send keys
function Farm.holdSteal(hum, root, c, prompt, reach)
	local folder = c.pet.Parent
	local holdFor = (prompt.HoldDuration or 1) + 0.6
	if not VirtualInputManager and typeof(fireproximityprompt) == "function" then
		pcall(fireproximityprompt, prompt)
		task.wait(0.5)
		return
	end
	Util.sendKey(Enum.KeyCode.E, true)
	local untilT = os.clock() + holdFor
	while os.clock() < untilT and not Library.Unloaded and hum.Health > 0 and not Farm.carrying() and Farm.petAvailable(c.pet, folder) do
		-- Pets wander: keep within prompt range without walking off
		local delta = Util.flat(root.Position, c.root.Position)
		if delta.Magnitude > reach then
			Farm.moveDir = delta.Unit
		else
			Farm.moveDir = nil
		end
		task.wait(0.05)
	end
	Farm.stop()
	Util.sendKey(Enum.KeyCode.E, false)
	local waitUntil = os.clock() + 0.6
	while not Farm.carrying() and os.clock() < waitUntil do
		task.wait(0.05)
	end
end

function Farm.stealPet(hum, root, c)
	local prompt = Farm.petPrompt(c.pet)
	if not prompt then
		return
	end
	Farm.setTarget(string.format(
		"Pet: %s (%s%s) · $%s/s%s",
		c.name,
		c.rarity,
		c.mutation ~= "None" and (", " .. c.mutation) or "",
		Util.formatNumber(c.income),
		c.mine and " · hatched by you" or ""
	))

	local reach = math.clamp((prompt.MaxActivationDistance or 10) - 5, 4, 10)
	local folder = c.pet.Parent
	local status, threat = Farm.runTo(hum, root, function()
		return c.root.Parent and c.root.Position or nil
	end, reach, function()
		return Farm.petAvailable(c.pet, folder) and not Farm.carrying()
	end, c.name, true)

	if status == "guard" then
		Farm.skippedPets[c.pet] = os.clock() + 10
		Farm.retreat(hum, root, threat.pos)
		return
	elseif status == "stuck" then
		Farm.skippedPets[c.pet] = os.clock() + 20
		Farm.setTarget("Pet: Unreachable, skipping...")
		return
	elseif status ~= "arrived" then
		return -- someone else took it, or it despawned
	end

	Farm.setState("Stealing " .. c.name .. " (holding E)...")
	Farm.holdSteal(hum, root, c, prompt, reach)

	if Farm.carrying() then
		Farm.stats.stolen += 1
		Farm.carryInfo = c
		if c.mine then
			Farm.lastBreak = nil
		end
		Farm.returnHome(hum, root)
	else
		Farm.stats.failed += 1
		Farm.skippedPets[c.pet] = os.clock() + 20
		Farm.setTarget("Pet: Couldn't steal " .. c.name .. ", skipping...")
	end
end

-- Walk the carried pet back to the base; the game stores it when you get there
function Farm.returnHome(hum, root)
	local home = Farm.homePos()
	if not home then
		Farm.setState("Can't find your base!")
		task.wait(1)
		return
	end
	local info = Farm.carryInfo
	Farm.setTarget("Carrying: " .. (info and info.name or tostring(player:GetAttribute("Carrying"))))
	Farm.runTo(hum, root, function()
		return home
	end, 5, Farm.carrying, "your base", false)

	local waitUntil = os.clock() + 4
	while Farm.carrying() and os.clock() < waitUntil and Farm.active() do
		task.wait(0.2)
	end
	if Farm.carrying() then
		return -- not stored yet (stuck/stopped); the main loop tries again
	end

	Farm.stats.stored += 1
	Farm.carryInfo = nil
	Farm.setTarget("Stored " .. (info and info.name or "pet") .. " at your base!")
	if Farm.onStored and info then
		task.spawn(Farm.onStored, info)
	end
	if Toggles.BalutEquipBest.Value then
		task.delay(0.6, function()
			local remote = Farm.remote("PetAction")
			if remote then
				pcall(function()
					remote:InvokeServer("EquipBest", nil)
				end)
			end
		end)
	end
end

--// One pass of the main loop; returns how long to wait before the next pass
function Farm.tick()
	local farmOn, stealOn = Toggles.BalutFarmEggs.Value, Toggles.BalutStealPets.Value
	if not (farmOn or stealOn) then
		if Farm.moveDir then
			Farm.stop()
		end
		Farm.setState("Idle")
		return 0.3
	end

	local char, hum, root = Farm.character()
	if not char then
		Farm.setState("Waiting for respawn...")
		return 1
	end
	Farm.ensureOnFoot(char, hum)

	-- 1. Already carrying (stolen by the farm or by hand): bring it home
	if Farm.carrying() then
		Farm.returnHome(hum, root)
		return 0.1
	end

	-- 2. Pets first: they despawn, eggs don't
	if stealOn or (farmOn and Toggles.BalutStealMine.Value) then
		local pet = Farm.findPet(root, hum, not stealOn)
		if pet then
			Farm.stealPet(hum, root, pet)
			return 0.1
		end
	end

	-- 3. Eggs (strongest Asarol first: it is what sets your damage)
	if farmOn then
		Farm.ensureBestAsarol()
		local egg = Farm.findEgg(root)
		if egg then
			Farm.breakEgg(char, hum, root, egg)
			return 0.1
		end
		Farm.stop()
		if Farm.eggScan.guarded > 0 then
			Farm.setTarget(string.format("Egg: %d matching egg(s) guarded, waiting...", Farm.eggScan.guarded))
		else
			Farm.setTarget("Egg: None match your filters right now")
		end
		Farm.setState("Waiting for eggs...")
		return 0.5
	end

	Farm.stop()
	Farm.setTarget("Pet: Waiting for a matching wild pet...")
	Farm.setState("Auto-Steal watching")
	return 0.3
end

task.spawn(function()
	while not Library.Unloaded do
		local ok, result = pcall(Farm.tick)
		if not ok then
			warn("[Steal a Balut] Farm error: " .. tostring(result))
			Farm.stop()
			Util.sendKey(Enum.KeyCode.E, false)
			Farm.setState("Error, retrying...")
			result = 1
		end
		task.wait(result)
	end
end)

-- Guard alert/chase state comes from the server as GuardFx(state, guardModel, targetPlayer, ...)
task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
	local guardFx = remotes and remotes:WaitForChild("GuardFx", 10)
	if guardFx and not Library.Unloaded then
		table.insert(Farm.conns, guardFx.OnClientEvent:Connect(function(state, guard, target)
			if typeof(guard) == "Instance" then
				Farm.guardState[guard] = { state = tostring(state), target = target, at = os.clock() }
				Farm.threatCache = nil
			end
		end))
	end
end)

-- Status panel
task.spawn(function()
	while not Library.Unloaded do
		local s = Farm.stats
		FarmLabels.Stats:SetText(string.format(
			"Eggs broken: %d · Pets stolen: %d · Stored: %d · Failed: %d · Guards avoided: %d",
			s.eggs, s.stolen, s.stored, s.failed, s.guards
		))
		local lines = {}
		if Toggles.BalutFarmEggs.Value then
			local e = Farm.eggScan
			table.insert(lines, string.format("Eggs: %d alive · %d filtered out · %d guarded", e.total, e.filtered, e.guarded))
			table.insert(lines, string.format(
				"Asarol: %s · power %s",
				tostring(player:GetAttribute("EquippedAsarol") or "?"),
				Util.formatNumber(player:GetAttribute("AsarolPower") or 0)
			) .. (Farm.asarol.summary and (" · best owned: " .. Farm.asarol.summary) or ""))
		end
		if Toggles.BalutFarmEggs.Value or Toggles.BalutStealPets.Value then
			local p = Farm.petScan
			table.insert(lines, string.format("Wild pets: %d · %d filtered out · %d guarded · %d despawning", p.total, p.filtered, p.guarded, p.expiring))
			table.insert(lines, "Auto Swing: " .. (player:GetAttribute("AutoSwing") == true and "On (in-game)" or "Off (clicking with Asarol)"))
		end
		FarmLabels.Scan:SetText(table.concat(lines, "\n"))
		task.wait(1)
	end
end)

--============================================================================--
--// ESP (eggs and wild pets)
--============================================================================--
local Esp = { eggs = {}, pets = {} }

local VisualBox = Tabs.Visuals:AddGroupbox({
	Side = "Left",
	Name = "ESP",
	IconName = "eye",
})

VisualBox:AddCheckbox("BalutEggEsp", {
	Text = "Egg ESP",
	Default = false,
	Tooltip = "Shows baluts through walls with rarity, HP and zone",
}):AddKeyPicker("BalutEggEspKey", {
	Default = "G",
	Mode = "Toggle",
	SyncToggleState = true,
	Text = "Egg ESP",
})

VisualBox:AddCheckbox("BalutPetEsp", {
	Text = "Wild Pet ESP",
	Default = false,
	Tooltip = "Shows wild pets with rarity, income and time left",
}):AddKeyPicker("BalutPetEspKey", {
	Default = "P",
	Mode = "Toggle",
	SyncToggleState = true,
	Text = "Wild Pet ESP",
})

VisualBox:AddDropdown("BalutEspRarities", {
	Text = "ESP Rarity Filter",
	Values = table.clone(Util.RARITIES),
	Multi = true,
	Searchable = true,
	Default = {},
	Tooltip = "Only show these rarities. Leave empty to show all",
})

do
	local parent = (gethui and gethui()) or CoreGui
	local old = parent:FindFirstChild("__AllainBalutESP")
	if old then
		pcall(function()
			old:Destroy()
		end)
	end
	Esp.container = Instance.new("Folder")
	Esp.container.Name = "__AllainBalutESP"
	Esp.container.Parent = parent
end

function Esp.make(adornee)
	local bb = Instance.new("BillboardGui")
	bb.AlwaysOnTop = true
	bb.Size = UDim2.fromOffset(220, 40)
	bb.StudsOffset = Vector3.new(0, 3.5, 0)
	bb.LightInfluence = 0
	bb.MaxDistance = 3000
	bb.Adornee = adornee
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextStrokeTransparency = 0.35
	label.TextWrapped = true
	label.Parent = bb
	bb.Parent = Esp.container
	return { gui = bb, label = label }
end

-- Keeps one billboard per model in `folder` that passes `filter`; removes the rest
function Esp.sync(store, folder, enabled, getAdornee, describe)
	local rarities = Options.BalutEspRarities.Value
	for model, entry in pairs(store) do
		if not enabled or model.Parent ~= folder or not Util.selected(tostring(model:GetAttribute("Rarity") or ""), rarities) then
			entry.gui:Destroy()
			store[model] = nil
		end
	end
	if not enabled or not folder then
		return
	end
	for _, model in ipairs(folder:GetChildren()) do
		if model:IsA("Model") and Util.selected(tostring(model:GetAttribute("Rarity") or ""), rarities) then
			local entry = store[model]
			if not entry then
				local adornee = getAdornee(model)
				if adornee then
					entry = Esp.make(adornee)
					store[model] = entry
				end
			end
			if entry then
				local text, color = describe(model)
				entry.label.Text = text
				entry.label.TextColor3 = color
			end
		end
	end
end

function Esp.describeEgg(egg)
	local rarity = tostring(egg:GetAttribute("Rarity") or "?")
	local hp, maxHp = tonumber(egg:GetAttribute("HP")), tonumber(egg:GetAttribute("MaxHP"))
	local size = tostring(egg:GetAttribute("EggSize") or "Normal")
	return string.format(
		"%s [%s]%s\n%s / %s HP · Zone %s",
		tostring(egg:GetAttribute("EggName") or egg.Name),
		rarity,
		size ~= "Normal" and (" · " .. size) or "",
		hp and Util.formatNumber(hp) or "?",
		maxHp and Util.formatNumber(maxHp) or "?",
		tostring(egg:GetAttribute("ZoneId") or "?")
	), Util.RARITY_COLORS[rarity] or Color3.new(1, 1, 1)
end

function Esp.describePet(pet)
	local rarity = tostring(pet:GetAttribute("Rarity") or "?")
	local mutation = tostring(pet:GetAttribute("Mutation") or "None")
	local expireAt = tonumber(pet:GetAttribute("ExpireAt"))
	local left = expireAt and math.max(0, math.floor(expireAt - Util.serverNow())) or nil
	return string.format(
		"%s [%s]%s\n$%s/s%s",
		tostring(pet:GetAttribute("PetName") or pet.Name),
		rarity,
		mutation ~= "None" and (" · " .. mutation) or "",
		Util.formatNumber(pet:GetAttribute("Income") or 0),
		left and string.format(" · %ds left", left) or ""
	), Util.RARITY_COLORS[rarity] or Color3.new(1, 1, 1)
end

task.spawn(function()
	while not Library.Unloaded do
		pcall(Esp.sync, Esp.eggs, workspace:FindFirstChild("ActiveEggs"), Toggles.BalutEggEsp.Value, Farm.eggRoot, Esp.describeEgg)
		pcall(Esp.sync, Esp.pets, workspace:FindFirstChild("WildPets"), Toggles.BalutPetEsp.Value, Farm.petRoot, Esp.describePet)
		task.wait(0.5)
	end
end)

--============================================================================--
--// TEMP DIAGNOSTIC: Game Data Scan -> Discord webhook (remove once automation is built)
--============================================================================--
-- Everything lives in one table: the executor compiles at -O0 and caps a function at 200 live locals.
local Scan = {
	busy = false,
	capturing = false,
	hookInstalled = false,
	LINE_CAP = 1500, -- per tree section
	KEYWORDS = {
		"balut", "egg", "steal", "plot", "base", "owner", "cash", "money", "coin", "sell", "buy",
		"upgrade", "rebirth", "collect", "lock", "shop", "spawn", "conveyor", "income",
	},
}

function Scan.webhookUrl()
	local url = tostring(Options.BalutWebhookUrl and Options.BalutWebhookUrl.Value or ""):match("^%s*(.-)%s*$")
	if url:find("^https://discord%.com/api/webhooks/") or url:find("^https://discordapp%.com/api/webhooks/") then
		return url
	end
	return nil
end

function Scan.httpRequest()
	return request or http_request or (syn and syn.request) or (fluxus and fluxus.request)
end

function Scan.path(inst)
	local ok, p = pcall(function()
		return inst:GetFullName()
	end)
	p = ok and p or tostring(inst)
	return (p:gsub("^Players%.[^%.]+%.PlayerGui%.", "PlayerGui."):gsub("^Players%.[^%.]+%.", "LocalPlayer."))
end

function Scan.fmt(v, depth)
	depth = depth or 0
	local t = typeof(v)
	if t == "string" then
		return string.format("%q", #v > 80 and (v:sub(1, 80) .. "...") or v)
	elseif t == "Instance" then
		return "<" .. v.ClassName .. "> " .. Scan.path(v)
	elseif t == "table" then
		if depth >= 2 then
			return "{...}"
		end
		local parts, n = {}, 0
		for k, val in pairs(v) do
			n += 1
			if n > 8 then
				table.insert(parts, "...")
				break
			end
			table.insert(parts, tostring(k) .. "=" .. Scan.fmt(val, depth + 1))
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	elseif t == "CFrame" then
		local p = v.Position
		return string.format("CFrame(%.1f, %.1f, %.1f)", p.X, p.Y, p.Z)
	elseif t == "Vector3" then
		return string.format("V3(%.1f, %.1f, %.1f)", v.X, v.Y, v.Z)
	end
	return tostring(v)
end

function Scan.fmtArgs(packed)
	local parts = {}
	for i = 1, math.min(packed.n or #packed, 6) do
		local ok, s = pcall(Scan.fmt, packed[i])
		table.insert(parts, ok and s or "?")
	end
	return table.concat(parts, ", ")
end

function Scan.attrs(inst)
	local parts = {}
	local ok, attrs = pcall(function()
		return inst:GetAttributes()
	end)
	if ok then
		for k, v in pairs(attrs) do
			table.insert(parts, tostring(k) .. "=" .. Scan.fmt(v, 1))
		end
	end
	table.sort(parts)
	return #parts > 0 and (" @{" .. table.concat(parts, ", ") .. "}") or ""
end

-- One line per instance: Name [Class] plus whatever is useful for that class
function Scan.describe(inst)
	local extra = ""
	if inst:IsA("ValueBase") then
		extra = " = " .. Scan.fmt(inst.Value, 1)
	elseif inst:IsA("ProximityPrompt") then
		extra = string.format(" (Action=%q Object=%q Hold=%.1fs Dist=%.0f Enabled=%s)", inst.ActionText, inst.ObjectText, inst.HoldDuration, inst.MaxActivationDistance, tostring(inst.Enabled))
	elseif inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
		if inst.Text ~= "" then
			extra = " " .. Scan.fmt(inst.Text)
		end
	elseif inst:IsA("Model") and Players:GetPlayerFromCharacter(inst) then
		extra = " (player character)"
	end
	return string.format("%s [%s]%s%s", inst.Name, inst.ClassName, extra, Scan.attrs(inst))
end

-- Indented tree; identical Name+Class siblings are collapsed into one line with "xN"
function Scan.tree(root, maxDepth, out)
	local start = #out
	local function walk(inst, depth)
		local ok, children = pcall(function()
			return inst:GetChildren()
		end)
		if not ok then
			return
		end
		local groups, order = {}, {}
		for _, c in ipairs(children) do
			local key = c.Name .. "\0" .. c.ClassName
			if not groups[key] then
				groups[key] = {}
				table.insert(order, key)
			end
			table.insert(groups[key], c)
		end
		for _, key in ipairs(order) do
			if #out - start >= Scan.LINE_CAP then
				return
			end
			local g = groups[key]
			local c = g[1]
			table.insert(out, string.rep("  ", depth) .. Scan.describe(c) .. (#g > 1 and ("  x" .. #g) or ""))
			local isChar = c:IsA("Model") and Players:GetPlayerFromCharacter(c)
			if depth + 1 < maxDepth and not isChar and not c:IsA("Terrain") then
				walk(c, depth + 1)
			end
		end
	end
	table.insert(out, Scan.describe(root))
	walk(root, 1)
	if #out - start >= Scan.LINE_CAP then
		table.insert(out, string.format("... (section capped at %d lines)", Scan.LINE_CAP))
	end
end

function Scan.keywordOf(name)
	name = tostring(name):lower()
	for _, k in ipairs(Scan.KEYWORDS) do
		if name:find(k, 1, true) then
			return k
		end
	end
	return nil
end

function Scan.isMine(v)
	return v == player or v == player.Name or v == player.UserId or v == tostring(player.UserId) or v == player.DisplayName
end

-- Sends `text` as a .txt attachment; falls back to chunked code-block messages if the executor can't do multipart
function Scan.send(title, summary, text, fileName)
	local url = Scan.webhookUrl()
	local httpRequest = Scan.httpRequest()
	if not url or not httpRequest then
		return false
	end
	local boundary = "AllainScan" .. HttpService:GenerateGUID(false):gsub("-", "")
	local payload = HttpService:JSONEncode({
		username = "Allain-afk Data Scan",
		embeds = { { title = title, description = summary, color = 0xF5B041 } },
	})
	local body = table.concat({
		"--" .. boundary,
		'Content-Disposition: form-data; name="payload_json"',
		"Content-Type: application/json",
		"",
		payload,
		"--" .. boundary,
		'Content-Disposition: form-data; name="files[0]"; filename="' .. fileName .. '"',
		"Content-Type: text/plain; charset=utf-8",
		"",
		text,
		"--" .. boundary .. "--",
		"",
	}, "\r\n")
	local ok, res = pcall(httpRequest, {
		Url = url,
		Method = "POST",
		Headers = { ["Content-Type"] = "multipart/form-data; boundary=" .. boundary },
		Body = body,
	})
	local code = ok and type(res) == "table" and tonumber(res.StatusCode) or nil
	if ok and (code == nil or (code >= 200 and code < 300)) then
		return true
	end

	-- Fallback: plain messages, 1900 chars each, capped so we don't spam the channel
	local sent = 0
	for i = 1, #text, 1900 do
		if sent >= 8 then
			break
		end
		pcall(httpRequest, {
			Url = url,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = HttpService:JSONEncode({
				username = "Allain-afk Data Scan",
				content = (sent == 0 and ("**" .. title .. "** (file upload failed, truncated)\n") or "") .. "```\n" .. text:sub(i, i + 1899) .. "\n```",
			}),
		})
		sent += 1
		task.wait(1.2)
	end
	return sent > 0
end

function Scan.header(out, title)
	local placeName = "?"
	pcall(function()
		placeName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
	end)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	table.insert(out, "==== " .. title .. " ====")
	table.insert(out, string.format("Game: %s | PlaceId %d | GameId %d | JobId %s", placeName, game.PlaceId, game.GameId, game.JobId))
	table.insert(out, string.format("Player: %s (%d) | Players in server: %d | Executor: %s", player.Name, player.UserId, #Players:GetPlayers(), identifyexecutor and tostring((identifyexecutor())) or "?"))
	table.insert(out, "My position: " .. (hrp and Scan.fmt(hrp.Position) or "no character"))
	table.insert(out, "")
end

function Scan.section(out, name)
	table.insert(out, "")
	table.insert(out, "######## " .. name .. " ########")
end

--// Full static scan \\--
function Scan.runStatic()
	local out = {}
	Scan.header(out, "Steal a Balut - Static Scan")

	Scan.section(out, "PLAYER (attributes, leaderstats, values)")
	table.insert(out, "Player" .. Scan.attrs(player))
	for _, c in ipairs(player:GetChildren()) do
		if c.Name ~= "PlayerGui" and c.Name ~= "PlayerScripts" then
			Scan.tree(c, 4, out)
		end
	end
	if player.Character then
		Scan.section(out, "MY CHARACTER")
		Scan.tree(player.Character, 2, out)
	end

	Scan.section(out, "WORKSPACE (depth 4)")
	Scan.tree(workspace, 4, out)

	Scan.section(out, "REPLICATEDSTORAGE (depth 4)")
	Scan.tree(ReplicatedStorage, 4, out)

	Scan.section(out, "ALL REMOTES")
	local remotes = {}
	for _, root in ipairs({ ReplicatedStorage, workspace, player }) do
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent") or d:IsA("BindableEvent") then
				table.insert(remotes, string.format("%s [%s]", Scan.path(d), d.ClassName))
			end
		end
	end
	table.sort(remotes)
	table.insert(out, "Count: " .. #remotes)
	for i, r in ipairs(remotes) do
		if i > 600 then
			table.insert(out, "... (capped)")
			break
		end
		table.insert(out, r)
	end

	-- One pass over workspace for prompts, ownership markers and keyword-named objects
	Scan.section(out, "INTERACTABLES (ProximityPrompts / ClickDetectors)")
	local prompts, owned, keyHits, keyOrder = {}, {}, {}, {}
	local touchCount = 0
	for i, d in ipairs(workspace:GetDescendants()) do
		if i % 4000 == 0 then
			task.wait()
		end
		if d:IsA("ProximityPrompt") then
			table.insert(prompts, Scan.path(d.Parent) .. " -> " .. Scan.describe(d))
		elseif d:IsA("ClickDetector") then
			table.insert(prompts, Scan.path(d.Parent) .. " -> ClickDetector")
		elseif d:IsA("TouchTransmitter") then
			touchCount += 1
		end
		if d:IsA("ValueBase") then
			local okV, val = pcall(function()
				return d.Value
			end)
			if okV and Scan.isMine(val) then
				table.insert(owned, string.format("%s [%s] = %s", Scan.path(d), d.ClassName, Scan.fmt(val)))
			end
		end
		local okA, attrs = pcall(function()
			return d:GetAttributes()
		end)
		if okA then
			for k, v in pairs(attrs) do
				if Scan.isMine(v) then
					table.insert(owned, string.format("%s [%s] @%s = %s", Scan.path(d), d.ClassName, k, Scan.fmt(v)))
				end
			end
		end
		if Scan.keywordOf(d.Name) and not d:IsA("TouchTransmitter") then
			local key = d.Name .. " [" .. d.ClassName .. "]"
			local g = keyHits[key]
			if not g then
				g = { key = key, count = 0, sample = Scan.path(d) }
				keyHits[key] = g
				table.insert(keyOrder, g)
			end
			g.count += 1
		end
	end
	table.insert(out, string.format("Prompts/ClickDetectors: %d | TouchInterests: %d", #prompts, touchCount))
	for i, p in ipairs(prompts) do
		if i > 300 then
			table.insert(out, "... (capped)")
			break
		end
		table.insert(out, p)
	end

	Scan.section(out, "OWNED BY ME (values/attributes equal to my name or UserId -> likely my plot/base)")
	for i, o in ipairs(owned) do
		if i > 200 then
			table.insert(out, "... (capped)")
			break
		end
		table.insert(out, o)
	end
	if #owned == 0 then
		table.insert(out, "(none found)")
	end

	Scan.section(out, "KEYWORD-NAMED OBJECTS (" .. table.concat(Scan.KEYWORDS, ", ") .. ")")
	table.sort(keyOrder, function(a, b)
		return a.count > b.count
	end)
	for i, g in ipairs(keyOrder) do
		if i > 250 then
			table.insert(out, "... (capped)")
			break
		end
		table.insert(out, string.format("%s x%d  e.g. %s", g.key, g.count, g.sample))
	end

	local pg = player:FindFirstChild("PlayerGui")
	if pg then
		Scan.section(out, "PLAYERGUI (depth 5)")
		Scan.tree(pg, 5, out)
	end

	local text = table.concat(out, "\n")
	local summary = string.format("PlaceId `%d` · GameId `%d`\n%d lines · %d remotes · %d prompts · %d owned markers", game.PlaceId, game.GameId, #out, #remotes, #prompts, #owned)
	return Scan.send("🥚 Steal a Balut: Static Scan", summary, text, "balut-static-scan.txt")
end

--// Live capture: remotes (in + out), my stats, GUI text, spawned objects \\--
function Scan.installHook()
	if Scan.hookInstalled or not (hookmetamethod and getnamecallmethod) then
		return Scan.hookInstalled
	end
	local wrap = newcclosure or function(f)
		return f
	end
	local old
	old = hookmetamethod(game, "__namecall", wrap(function(self, ...)
		if Scan.capturing and not (checkcaller and checkcaller()) then
			local method = getnamecallmethod()
			if method == "FireServer" or method == "InvokeServer" then
				pcall(Scan.recordRemote, "OUT", self, method, table.pack(...))
			end
		end
		return old(self, ...)
	end))
	Scan.hookInstalled = true
	return true
end

-- Remote calls are aggregated per remote; the first 5 of each also go into the ordered timeline
function Scan.recordRemote(dir, remote, method, packed)
	local cap = Scan.cap
	if not cap then
		return
	end
	-- Keyed by the remote instance itself so same-named remotes in different folders stay separate
	local byRemote = cap.remotes[remote]
	if not byRemote then
		byRemote = {}
		cap.remotes[remote] = byRemote
	end
	local g = byRemote[dir .. method]
	if not g then
		g = { dir = dir, remote = remote, method = method, count = 0, samples = {} }
		byRemote[dir .. method] = g
		table.insert(cap.remoteOrder, g)
	end
	g.count += 1
	if #g.samples < 3 then
		table.insert(g.samples, packed)
	end
	if g.count <= 5 and #cap.timeline < 400 then
		table.insert(cap.timeline, { t = os.clock() - cap.start, remote = remote, dir = dir, method = method, args = packed })
	end
end

function Scan.note(text)
	local cap = Scan.cap
	if cap and #cap.timeline < 400 then
		table.insert(cap.timeline, { t = os.clock() - cap.start, text = text })
	end
end

function Scan.runCapture(seconds)
	local cap = { start = os.clock(), remotes = {}, remoteOrder = {}, timeline = {}, spawned = {}, spawnGroups = {}, spawnOrder = {}, gui = {}, guiOrder = {}, conns = {} }
	Scan.cap = cap
	local hooked = Scan.installHook()

	local function watchRemote(d)
		if d:IsA("RemoteEvent") or d:IsA("UnreliableRemoteEvent") then
			table.insert(cap.conns, d.OnClientEvent:Connect(function(...)
				Scan.recordRemote("IN", d, "OnClientEvent", table.pack(...))
			end))
		end
	end
	for _, root in ipairs({ ReplicatedStorage, workspace, player }) do
		for _, d in ipairs(root:GetDescendants()) do
			watchRemote(d)
		end
	end

	table.insert(cap.conns, player.AttributeChanged:Connect(function(name)
		Scan.note(string.format("PlayerAttr %s = %s", name, Scan.fmt(player:GetAttribute(name), 1)))
	end))
	local pg = player:FindFirstChild("PlayerGui")
	for _, d in ipairs(player:GetDescendants()) do
		if d:IsA("ValueBase") and not (pg and d:IsDescendantOf(pg)) then
			local last = d.Value
			table.insert(cap.conns, d.Changed:Connect(function()
				Scan.note(string.format("Value %s: %s -> %s", Scan.path(d), Scan.fmt(last, 1), Scan.fmt(d.Value, 1)))
				last = d.Value
			end))
		end
	end

	-- GUI text changes are aggregated per label (currency counters usually only live here)
	if pg then
		local n = 0
		for _, d in ipairs(pg:GetDescendants()) do
			if (d:IsA("TextLabel") or d:IsA("TextButton")) and n < 3000 then
				n += 1
				table.insert(cap.conns, d:GetPropertyChangedSignal("Text"):Connect(function()
					local g = cap.gui[d]
					if not g then
						g = { path = Scan.path(d), first = d.Text, count = 0 }
						cap.gui[d] = g
						table.insert(cap.guiOrder, g)
					end
					g.count += 1
					g.last = d.Text
				end))
			end
		end
	end

	-- New workspace objects (top-most new instance only, characters skipped)
	table.insert(cap.conns, workspace.DescendantAdded:Connect(function(inst)
		if not (inst:IsA("BasePart") or inst:IsA("Model") or inst:IsA("Folder")) then
			return
		end
		task.defer(function()
			if not inst.Parent then
				return
			end
			local p = inst.Parent
			while p and p ~= workspace do
				if cap.spawned[p] or (p:IsA("Model") and Players:GetPlayerFromCharacter(p)) then
					return
				end
				p = p.Parent
			end
			local parentPath = Scan.path(inst.Parent)
			local key = inst.Name .. " [" .. inst.ClassName .. "] in " .. parentPath
			local g = cap.spawnGroups[key]
			if not g then
				g = { key = key, count = 0, removed = 0, sample = Scan.describe(inst) }
				cap.spawnGroups[key] = g
				table.insert(cap.spawnOrder, g)
			end
			g.count += 1
			cap.spawned[inst] = g
		end)
	end))
	table.insert(cap.conns, workspace.DescendantRemoving:Connect(function(inst)
		local g = cap.spawned[inst]
		if g then
			g.removed += 1
			cap.spawned[inst] = nil
		end
	end))

	Scan.capturing = true
	local lastNotified = 0
	while os.clock() - cap.start < seconds and not Library.Unloaded do
		task.wait(1)
		local elapsed = math.floor(os.clock() - cap.start)
		if elapsed - lastNotified >= 20 and elapsed < seconds then
			lastNotified = elapsed
			Library:Notify(string.format("Live capture: %ds left", seconds - elapsed), 2)
		end
	end
	Scan.capturing = false
	for _, c in ipairs(cap.conns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	if Library.Unloaded then
		return false
	end

	local out = {}
	Scan.header(out, string.format("Steal a Balut - Live Capture (%ds)", seconds))
	table.insert(out, "Outgoing remote logging: " .. (hooked and "ON" or "OFF (executor lacks hookmetamethod)"))

	Scan.section(out, "TIMELINE (first 5 calls per remote + stat changes, in order)")
	for _, e in ipairs(cap.timeline) do
		if e.text then
			table.insert(out, string.format("[%6.2fs] %s", e.t, e.text))
		else
			table.insert(out, string.format("[%6.2fs] %s %s:%s(%s)", e.t, e.dir, Scan.path(e.remote), e.method, Scan.fmtArgs(e.args)))
		end
	end

	Scan.section(out, "REMOTES (by call count, with sample args)")
	table.sort(cap.remoteOrder, function(a, b)
		return a.count > b.count
	end)
	for _, g in ipairs(cap.remoteOrder) do
		table.insert(out, string.format("%s %s:%s x%d", g.dir, Scan.path(g.remote), g.method, g.count))
		for _, s in ipairs(g.samples) do
			table.insert(out, "    (" .. Scan.fmtArgs(s) .. ")")
		end
	end

	Scan.section(out, "GUI TEXT CHANGES (by change count)")
	table.sort(cap.guiOrder, function(a, b)
		return a.count > b.count
	end)
	for i, g in ipairs(cap.guiOrder) do
		if i > 80 then
			break
		end
		table.insert(out, string.format("%s x%d: %s -> %s", g.path, g.count, Scan.fmt(g.first), Scan.fmt(g.last or "")))
	end

	Scan.section(out, "NEW WORKSPACE OBJECTS")
	table.sort(cap.spawnOrder, function(a, b)
		return a.count > b.count
	end)
	for i, g in ipairs(cap.spawnOrder) do
		if i > 150 then
			break
		end
		table.insert(out, string.format("%s x%d (removed %d)\n    %s", g.key, g.count, g.removed, g.sample))
	end

	Scan.cap = nil
	local summary = string.format("%ds capture · %d remotes active · %d timeline events · %d GUI labels changed · %d new object types", seconds, #cap.remoteOrder, #cap.timeline, #cap.guiOrder, #cap.spawnOrder)
	return Scan.send("🥚 Steal a Balut: Live Capture", summary, table.concat(out, "\n"), "balut-live-capture.txt")
end

function Scan.start(kind)
	if Scan.busy then
		Library:Notify("A scan is already running...", 2)
		return
	end
	if not Scan.webhookUrl() then
		Library:Notify("Enter a valid Discord Webhook URL first!", 4)
		return
	end
	if not Scan.httpRequest() then
		Library:Notify("Your executor doesn't support HTTP requests.", 4)
		return
	end
	Scan.busy = true
	task.spawn(function()
		local ok, result
		if kind == "static" then
			Library:Notify("Scanning game data...", 3)
			ok, result = pcall(Scan.runStatic)
		else
			local seconds = math.floor(tonumber(Options.BalutCaptureSeconds and Options.BalutCaptureSeconds.Value) or 60)
			Library:Notify(string.format("Live capture started (%ds). Play normally: buy, steal, sell, collect!", seconds), 6)
			ok, result = pcall(Scan.runCapture, seconds)
		end
		Scan.busy = false
		Scan.capturing = false
		if not ok then
			warn("[Steal a Balut] Scan error: " .. tostring(result))
			Library:Notify("Scan failed: " .. tostring(result):sub(1, 80), 6)
		elseif result then
			Library:Notify("Scan sent! Check your Discord webhook.", 4)
		elseif not Library.Unloaded then
			Library:Notify("Failed to send the webhook.", 4)
		end
	end)
end

local ScanBox = Tabs.Scan:AddGroupbox({
	Side = "Left",
	Name = "Game Data Scan",
	IconName = "search",
	Description = "Sends the game's structure to Discord as a .txt file.",
})

ScanBox:AddInput("BalutWebhookUrl", {
	Text = "Webhook URL",
	Placeholder = "https://discord.com/api/webhooks/...",
	ClearTextOnFocus = false,
})

ScanBox:AddButton({
	Text = "Send Static Scan",
	Tooltip = "Workspace, ReplicatedStorage, remotes, prompts, your plot/stats and PlayerGui",
	Func = function()
		Scan.start("static")
	end,
})

ScanBox:AddDivider()

ScanBox:AddSlider("BalutCaptureSeconds", {
	Text = "Live Capture Length",
	Default = 60,
	Min = 20,
	Max = 180,
	Rounding = 0,
	Suffix = "s",
})

ScanBox:AddButton({
	Text = "Start Live Capture",
	Tooltip = "Records remotes fired, stat/GUI changes and spawned objects while you play",
	Func = function()
		Scan.start("capture")
	end,
})

ScanBox:AddLabel({
	Text = "During live capture, do every action once: buy a balut, steal one, collect cash, sell, upgrade.",
	DoesWrap = true,
})

--============================================================================--
--// Alerts (rare wild pets, stored pets) — uses the Webhook URL above
--============================================================================--
local Alerts = { seen = setmetatable({}, { __mode = "k" }) }

local AlertBox = Tabs.Scan:AddGroupbox({
	Side = "Right",
	Name = "Pet Alerts",
	IconName = "sparkles",
	Description = "Uses the Webhook URL from the Game Data Scan box.",
})

AlertBox:AddCheckbox("BalutRareAlerts", {
	Text = "Alert on Rare Wild Pets",
	Default = false,
	Tooltip = "Notifies when a wild pet of a selected rarity appears anywhere on the map",
})

AlertBox:AddDropdown("BalutAlertRarities", {
	Text = "Alert Rarities",
	Values = table.clone(Util.RARITIES),
	Multi = true,
	Searchable = true,
	Default = { "Mythic", "Divine", "Secret" },
})

AlertBox:AddInput("BalutAlertMinIncome", {
	Text = "Alert Min Income/s",
	Default = "0",
	Placeholder = "0 = Any",
	ClearTextOnFocus = false,
})

AlertBox:AddCheckbox("BalutAlertWebhook", {
	Text = "Send Alerts to Discord",
	Default = true,
	Tooltip = "Off = in-game notification only",
})

AlertBox:AddCheckbox("BalutStoredWebhook", {
	Text = "Discord Message per Stored Pet",
	Default = false,
	Tooltip = "Sends a message each time the farm brings a pet home",
})

function Alerts.post(embed)
	local url, httpRequest = Scan.webhookUrl(), Scan.httpRequest()
	if not url or not httpRequest then
		return false
	end
	embed.timestamp = DateTime.now():ToIsoDate()
	embed.footer = { text = "Steal a Balut · " .. player.Name }
	return pcall(httpRequest, {
		Url = url,
		Method = "POST",
		Headers = { ["Content-Type"] = "application/json" },
		Body = HttpService:JSONEncode({ username = "Allain-afk Steal a Balut", embeds = { embed } }),
	})
end

function Alerts.color(rarity)
	local c = Util.RARITY_COLORS[rarity] or Color3.new(1, 1, 1)
	return math.floor(c.R * 255) * 65536 + math.floor(c.G * 255) * 256 + math.floor(c.B * 255)
end

function Alerts.checkPet(pet)
	if Alerts.seen[pet] or not Toggles.BalutRareAlerts.Value or Library.Unloaded or not pet.Parent then
		return
	end
	local rarity = tostring(pet:GetAttribute("Rarity") or "")
	local selection = Options.BalutAlertRarities.Value
	local income = tonumber(pet:GetAttribute("Income")) or 0
	if not Util.hasSelection(selection) or not Util.selected(rarity, selection) or income < Util.parseNumber(Options.BalutAlertMinIncome.Value) then
		return
	end
	Alerts.seen[pet] = true

	local name = tostring(pet:GetAttribute("PetName") or pet.Name)
	local mutation = tostring(pet:GetAttribute("Mutation") or "None")
	local expireAt = tonumber(pet:GetAttribute("ExpireAt"))
	local left = expireAt and math.max(0, math.floor(expireAt - Util.serverNow())) or nil
	Library:Notify(string.format("%s wild pet: %s ($%s/s)", rarity, name, Util.formatNumber(income)), 6)

	if Toggles.BalutAlertWebhook.Value then
		Alerts.post({
			title = string.format("%s wild pet: %s", rarity, name),
			color = Alerts.color(rarity),
			fields = {
				{ name = "Income", value = "$" .. Util.formatNumber(income) .. "/s", inline = true },
				{ name = "Mutation", value = mutation, inline = true },
				{ name = "Weight", value = tostring(pet:GetAttribute("Kg") or "?") .. " kg", inline = true },
				{ name = "Despawns in", value = left and (left .. "s") or "?", inline = true },
			},
		})
	end
end

Farm.onStored = function(info)
	if not Toggles.BalutStoredWebhook.Value then
		return
	end
	Alerts.post({
		title = "Stored " .. info.name .. (info.mine and " (hatched)" or " (stolen)"),
		color = Alerts.color(info.rarity),
		fields = {
			{ name = "Rarity", value = info.rarity ~= "" and info.rarity or "?", inline = true },
			{ name = "Income", value = "$" .. Util.formatNumber(info.income) .. "/s", inline = true },
			{ name = "Mutation", value = info.mutation, inline = true },
			{ name = "Session", value = string.format("%d eggs · %d stored", Farm.stats.eggs, Farm.stats.stored), inline = true },
		},
	})
end

task.spawn(function()
	local folder = workspace:WaitForChild("WildPets", 60)
	if not folder or Library.Unloaded then
		return
	end
	table.insert(Farm.conns, folder.ChildAdded:Connect(function(pet)
		-- Attributes can arrive a moment after the model is parented
		task.delay(0.5, Alerts.checkPet, pet)
	end))
	-- Pets that were already out when alerts got turned on
	while not Library.Unloaded do
		if Toggles.BalutRareAlerts.Value then
			for _, pet in ipairs(folder:GetChildren()) do
				Alerts.checkPet(pet)
			end
		end
		task.wait(5)
	end
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
	Scan.capturing = false -- the namecall hook can't be removed safely; this makes it a pass-through
	if idledConnection then
		idledConnection:Disconnect()
	end
	Farm.stop()
	Util.sendKey(Enum.KeyCode.E, false)
	pcall(function()
		RunService:UnbindFromRenderStep(Farm.RENDER_STEP)
	end)
	if Farm.moveConn then
		Farm.moveConn:Disconnect()
	end
	for _, conn in ipairs(Farm.conns) do
		pcall(function()
			conn:Disconnect()
		end)
	end
	pcall(function()
		Esp.container:Destroy()
	end)
end)
