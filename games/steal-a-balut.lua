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
local HttpService = cloneref(game:GetService("HttpService"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))

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
	Scan = Window:AddTab("Data Scan", "search"),
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
end)
