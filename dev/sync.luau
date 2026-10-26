--// Studio dev sync: pulls the repo from `python -m http.server 34873` in the repo root
--// and rebuilds ReplicatedStorage.Sydney + StarterPlayerScripts.SydneyTest.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")

local Base = "http://127.0.0.1:34873/"

local function Fetch(Path)
	return HttpService:GetAsync(Base .. Path, true)
end

--// In-memory stand-ins for executor file functions so the addons can run in Studio
local FsShim = [[
local __fs = shared.__SydneyFs or { files = {}, folders = {} }
shared.__SydneyFs = __fs
local isfolder = function(p) return __fs.folders[p] == true end
local isfile = function(p) return __fs.files[p] ~= nil end
local makefolder = function(p) __fs.folders[p] = true end
local writefile = function(p, c) __fs.files[p] = c end
local readfile = function(p) return __fs.files[p] end
local delfile = function(p) __fs.files[p] = nil end
local listfiles = function(p)
	local out = {}
	for k in __fs.files do if k:sub(1, #p + 1) == p .. "/" then table.insert(out, k) end end
	for k in __fs.folders do if k:sub(1, #p + 1) == p .. "/" then table.insert(out, k) end end
	return out
end
local clonefunction = function(f) return f end
local getgenv = getgenv or function() return shared end
]]

local Old = ReplicatedStorage:FindFirstChild("Sydney")
if Old then Old:Destroy() end
local OldTest = StarterPlayerScripts:FindFirstChild("SydneyTest")
if OldTest then OldTest:Destroy() end

local Folder = Instance.new("Folder")
Folder.Name = "Sydney"
Folder.Parent = ReplicatedStorage

local ScriptEditorService = game:GetService("ScriptEditorService")

--// Direct Source assignment caps at 200k chars; UpdateSourceAsync does not
local function SetSource(S, Source)
	ScriptEditorService:UpdateSourceAsync(S, function()
		return Source
	end)
end

local function Module(Name, Source)
	local M = Instance.new("ModuleScript")
	M.Name = Name
	M.Parent = Folder
	SetSource(M, Source)
end

Module("Library", Fetch("Library.lua"))
Module("ThemeManager", FsShim .. Fetch("addons/ThemeManager.lua"))
Module("SaveManager", FsShim .. Fetch("addons/SaveManager.lua"))

--// Studio can't loadstring the online icon module, so ship it as a ModuleScript
local IconsOk, IconsSource = pcall(HttpService.GetAsync, HttpService,
	"https://raw.githubusercontent.com/notpoiu/lucide-roblox-direct/refs/heads/main/source.lua", true)
if IconsOk then
	Module("Icons", IconsSource)
end

local Example = Fetch("Example.lua")
local Header = [[
local Sydney = game:GetService("ReplicatedStorage"):WaitForChild("Sydney")
local Library = require(Sydney.Library)
if Sydney:FindFirstChild("Icons") then
	Library:SetIconModule(require(Sydney.Icons))
end
local ThemeManager = require(Sydney.ThemeManager)
local SaveManager = require(Sydney.SaveManager)
]]
local Lines = string.split(Example, "\n")
local Body = table.concat(Lines, "\n", 9)

local Test = Instance.new("LocalScript")
Test.Name = "SydneyTest"
Test.Parent = StarterPlayerScripts
SetSource(Test, Header .. Body)

return "synced " .. #Lines .. " example lines"
