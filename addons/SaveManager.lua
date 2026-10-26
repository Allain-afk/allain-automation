local cloneref = (cloneref or clonereference or function(instance: any)
    return instance
end)
local clonefunction = (clonefunction or copyfunction or function(func) 
    return func 
end)

local HttpService: HttpService = cloneref(game:GetService("HttpService"))

--// Fix is_____ functions for shitsploits, those functions should never error, only return a boolean. (why is this still a problem in the big 2026)
local isfolder, isfile, listfiles = isfolder, isfile, listfiles
local isfolder_copy, isfile_copy, listfiles_copy = clonefunction(isfolder), clonefunction(isfile), clonefunction(listfiles)
local isfolder_success, isfolder_error = pcall(function() return isfolder_copy("test" .. tostring(math.random(1000000, 9999999))) end)

if isfolder_success == false or typeof(isfolder_error) ~= "boolean" then
    isfolder = function(folder)
        local success, data = pcall(isfolder_copy, folder)
        return (if success then data else false)
    end

    isfile = function(file)
        local success, data = pcall(isfile_copy, file)
        return (if success then data else false)
    end

    listfiles = function(folder)
        local success, data = pcall(listfiles_copy, folder)
        return (if success then data else {})
    end
end

--// Save Manager
local SaveManager = {
    Library = nil,

    Folder = "ObsidianLibSettings",
    SubFolder = "",

    Ignore = {},
    LoadingOrder = {},
    UseLoadingOrder = false,

    AutoloadConfig = nil
}

function SaveManager:SetLibrary(Library)
    SaveManager.Library = Library
end

--// Element Parser \\--
local SpecialValueParser = {
    UDim2 = {
        Encode = function(Value: UDim2)
            return {
                X = { Scale = Value.X.Scale, Offset = Value.X.Offset },
                Y = { Scale = Value.Y.Scale, Offset = Value.Y.Offset }
            }
        end,

        Decode = function(Data: any)
            local DataType = typeof(Data)
            if DataType == "table" then
                return UDim2.new(Data.X.Scale, Data.X.Offset, Data.Y.Scale, Data.Y.Offset)
            elseif DataType == "UDim2" then
                return Data
            end

            return nil
        end
    }
}

local ElementParser = {}; do
    local function CreateParser(
        ElementType: string, 
        LibaryIndex: string, 
        
        Save: (string, any, ...any) -> any, 
        Load: (any?, any) -> any,
        CustomElementFetcher: boolean?
    )
        ElementParser[ElementType] = { 
            Save = function(Index: string, Element: any, ...)
                local Data = Save(Index, Element, ...)
                Data.type = ElementType
                Data.idx = Index

                return Data
            end, 

            Load = function(Index: string?, Data: any)
                if CustomElementFetcher == true then
                    return Load(nil, Data)
                end

                local Elements = SaveManager.Library and SaveManager.Library[LibaryIndex]
                local Element = Elements and Elements[Index]
                return Load(Element, Data)
            end
        }
    end

    CreateParser(
        "Toggle", "Toggles",
        function(Index: string, Toggle: any)
            return { value = Toggle.Value }
        end,
        function(Element: any?, Data: any)
            if not Element then return end
            if Element.Value == Data.value then
                Element:RunChanged()
                return
            end
            
            Element:SetValue(Data.value)
        end
    )

    CreateParser(
        "Slider", "Options",
        function(Index: string, Slider: any)
            return { value = tostring(Slider.Value) }
        end,
        function(Element: any?, Data: any)
            if not Element then return end
            if Element.Value == Data.value then
                Element:RunChanged()
                return
            end

            Element:SetValue(Data.value)
        end
    )

    CreateParser(
        "Dropdown", "Options",
        function(Index: string, Dropdown: any)
            return { value = Dropdown.Value, multi = Dropdown.Multi }
        end,
        function(Element: any?, Data: any)
            if not Element then return end
            if Element.Value == Data.value then
                Element:RunChanged()
                return
            end
            
            Element:SetValue(Data.value)
        end
    )

    CreateParser(
        "ColorPicker", "Options",
        function(Index: string, ColorPicker: any)
            return { value = ColorPicker.Value:ToHex(), transparency = ColorPicker.Transparency }
        end,
        function(Element: any?, Data: any)
            if not Element then return end
            
            Element:SetValueRGB(Color3.fromHex(Data.value), Data.transparency)
        end
    )

    CreateParser(
        "KeyPicker", "Options",
        function(Index: string, KeyPicker: any)
            return { mode = KeyPicker.Mode, key = KeyPicker.Value, modifiers = KeyPicker.Modifiers, toggled = KeyPicker.Toggled }
        end,
        function(Element: any?, Data: any)
            if not Element then return end
            
            Element:SetValue({ Data.key, Data.mode, Data.modifiers })
            if Data.mode == "Toggle" and Data.toggled ~= nil then
                Element.Toggled = Data.toggled
                Element:Update()
            end
        end
    )

    CreateParser(
        "Input", "Options",
        function(Index: string, Input: any)
            return { text = Input.Value }
        end,
        function(Element: any?, Data: any)
            if not Element then return end
            if typeof(Data.text) ~= "string" then return end

            if Element.Value == Data.text then
                Element:RunChanged()
                return
            end

            Element:SetValue(Data.text)
        end
    )

    CreateParser(
        "Groupbox", "Tabs",
        function(Index: string, Groupbox: any, TabIndex: string)
            return {
                tabIdx = TabIndex,
                collapsed = Groupbox.Collapsed,
                poppedOut = Groupbox.PoppedOut == true,
                popoutPos = if Groupbox.PoppedOut and Groupbox.PopOutFloat then SpecialValueParser.UDim2.Encode(Groupbox.PopOutFloat.Position) else nil,
            }
        end,
        function(_, Data: any)
            local TabIndex, Index = Data.tabIdx, Data.idx
            if typeof(TabIndex) ~= "string" or typeof(Index) ~= "string" then return end

            local Tabs = SaveManager.Library and SaveManager.Library.Tabs
            local Tab = Tabs and Tabs[TabIndex]
            if not Tab then return end

            local Groupbox = Tab.Groupboxes[Index]
            if not Groupbox then return end

            --// Collapsed
            if Groupbox.Collapsed ~= Data.collapsed then
                Groupbox:SetCollapsed(Data.collapsed == true)
            end

            --// Popout
            if Groupbox.PopOutEnabled then
                if Data.poppedOut == true then
                    local Position = SpecialValueParser.UDim2.Decode(Data.popoutPos)
                    Groupbox:SetPoppedOut(true, Position)
                elseif Groupbox.PoppedOut then
                    Groupbox:SetPoppedOut(false)
                end
            end
        end,
        true
    )

    CreateParser(
        "Tabbox", "Tabs",
        function(Index: string, Tabbox: any, TabIndex: string)
            return {
                tabIdx = TabIndex,
                poppedOut = Tabbox.PoppedOut == true,
                popoutPos = if Tabbox.PoppedOut and Tabbox.PopOutFloat then SpecialValueParser.UDim2.Encode(Tabbox.PopOutFloat.Position) else nil,
            }
        end,
        function(_, Data: any)
            local TabIndex, Index = Data.tabIdx, Data.idx
            if typeof(TabIndex) ~= "string" or typeof(Index) ~= "string" then return end

            local Tabs = SaveManager.Library and SaveManager.Library.Tabs
            local Tab = Tabs and Tabs[TabIndex]
            if not Tab then return end

            local Tabbox = Tab.Tabboxes and Tab.Tabboxes[Index]
            if not Tabbox then return end

            --// Popout
            if Tabbox.PopOutEnabled then
                if Data.poppedOut == true then
                    local Position = SpecialValueParser.UDim2.Decode(Data.popoutPos)
                    Tabbox:SetPoppedOut(true, Position)
                elseif Tabbox.PoppedOut then
                    Tabbox:SetPoppedOut(false)
                end
            end
        end,
        true
    )
end

--// Helpers \\--
local function Trim(Text: string)
    return Text:match("^%s*(.-)%s*$")
end

local function IsStringEmpty(String: string): boolean
    return if typeof(String) == "string" then Trim(String) == "" else true
end

local function IsValidFolderPath(Name: string): boolean
    return typeof(Name) == "string" and (
        Trim(Name) ~= "" and 
        not Name:match("^%s*$") and 
        not Name:find('[<>:"|%?%*%z]')
    )
end

--// Folder helper \\--
local function SplitPath(Path: string): {string}
    local Result = {}
    local Current = ""

    for Part in string.gmatch(Path, "[^/]+") do
        Current = if Current == "" then Part else (Current .. "/" .. Part)
        table.insert(Result, Current)
    end

    return Result
end

local function GetFolderPath(): false | string
    if IsStringEmpty(SaveManager.Folder) then
        return false
    end

    return string.format("%s/settings", SaveManager.Folder)
end

local function GetSubFolderPath(): false | string
    if IsStringEmpty(SaveManager.Folder) or IsStringEmpty(SaveManager.SubFolder) then
        return false
    end

    return string.format("%s/settings/%s", SaveManager.Folder, SaveManager.SubFolder)
end

local function GetCurrentSettingsPath(): false | string
    local SubFolderPath = GetSubFolderPath()
    return if SubFolderPath == false then GetFolderPath() else SubFolderPath
end

--// Files helper \\--
local function GetConfigPath(ConfigName: string): false | string
    local CurrentSettingsPath = GetCurrentSettingsPath()
    return if CurrentSettingsPath == false then false else string.format("%s/%s.json", CurrentSettingsPath, ConfigName)
end

local function DoesConfigExist(ConfigName: string): boolean
    local ConfigPath = GetConfigPath(ConfigName)
    return if ConfigPath == false then false else isfile(ConfigPath)
end

local function GetAutoloadPath(): false | string
    local CurrentSettingsPath = GetCurrentSettingsPath()
    return if CurrentSettingsPath == false then false else string.format("%s/autoload.txt", CurrentSettingsPath)
end

--// Indexes \\--
function SaveManager:SetLoadingOrder(Enabled: boolean, Order: {string}?)
    SaveManager.UseLoadingOrder = Enabled == true
    SaveManager.LoadingOrder = typeof(Order) == "table" and Order or SaveManager.LoadingOrder
end

function SaveManager:SetIgnoreIndexes(Indexes: {string}?)
    assert(typeof(Indexes) == "table", "Expected table, got " .. typeof(Indexes))

    for _, Index in Indexes do
        SaveManager.Ignore[Index] = true
    end
end

function SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({
        "BackgroundColor", "MainColor", "AccentColor", "OutlineColor", "FontColor", "FontFace", "BackgroundImage",
        "SurfaceColor", "HoverColor", "InlineColor", "DarkAccentColor", "ToggleOffColor", "MutedFontColor",
        "ThemeManager_ThemeList", "ThemeManager_CustomThemeList", "ThemeManager_CustomThemeName", "ThemeManager_ThemeJSON",
        "ThemeManager_Weather"
    })
end

--// Folders \\--
function SaveManager:GetPaths(): {string}
    local SubFolderPath = GetSubFolderPath()
    if SubFolderPath == false then
        local FolderPath = GetFolderPath()
        return if FolderPath == false then {} else SplitPath(FolderPath)
    end

    return SplitPath(SubFolderPath)
end

function SaveManager:BuildFolderTree(SkipWhenCreated: boolean?)
    local Paths = SaveManager:GetPaths()
    if #Paths == 0 then
        return false
    end

    if SkipWhenCreated == true then
        if isfolder(Paths[1]) then
            return true
        end
    end

    for _, Path in Paths do
        if isfolder(Path) then continue end
        
        makefolder(Path)
    end

    return true
end

function SaveManager:CheckFolderTree()
    return SaveManager:BuildFolderTree(true)
end

function SaveManager:CheckSubFolder(CreateFolder: boolean)
    local SubFolderPath = GetSubFolderPath()
    if SubFolderPath == false then
        return false
    end

    local FolderExists = isfolder(SubFolderPath)
    if not CreateFolder then
        return FolderExists
    end

    makefolder(SubFolderPath)
    return true
end

function SaveManager:SetFolder(Folder: string)
    assert(IsValidFolderPath(Folder), "Invalid path provided")

    SaveManager.Folder = Folder
    SaveManager:BuildFolderTree()
end

function SaveManager:SetSubFolder(SubFolder: string)
    assert(IsValidFolderPath(SubFolder), "Invalid path provided")

    SaveManager.SubFolder = SubFolder
    SaveManager:BuildFolderTree()
end

--// Config Management \\--
function SaveManager:RefreshConfigList()
    local SettingsPath = GetCurrentSettingsPath()
    if SettingsPath == false then
        return {}
    end

    pcall(makefolder, SettingsPath)
    local SuccessList, Files = pcall(listfiles, SettingsPath)
    if not (SuccessList and typeof(Files) == "table") then
        SaveManager.Library:Notify(string.format("Failed to load config list: %s", tostring(Files)))
        return {}
    end

    local FileNames = {}
    for _, FilePath in Files do
        local RawFileName = FilePath:match("(.+)%..+$")
        if not RawFileName then continue end

        local Position = RawFileName:gsub("\\", "/"):find("/[^/]*$")
        local FileName = Position and RawFileName:sub(Position + 1) or RawFileName
        if not FileName or FileName == "autoload" then continue end

        table.insert(FileNames, FileName)
    end

    return FileNames
end

function SaveManager:SaveJSON(ConfigName)
    local Library = SaveManager.Library
    local IgnoreIndexes = SaveManager.Ignore
    local CurrentData = {
        timestamp = os.date("%d.%m.%Y %H:%M:%S"),
        name = ConfigName or "",

        objects = {},
        keybindMenu = nil,
    }

    if Library.KeybindFrame then
        local Hidden = {}
        for Index, Option in Library.Options do
            if Option.Type == "KeyPicker" and Option.NoUI ~= true and Option.MenuVisible == false then
                Hidden[Index] = true
            end
        end

        local KeybindMenu = Library.KeybindMenu
        local SettingsPosition = nil
        if KeybindMenu and KeybindMenu.SettingsFrame then
            SettingsPosition = SpecialValueParser.UDim2.Encode(KeybindMenu.SettingsFrame.Position)
        end

        CurrentData.keybindMenu = {
            visible = Library.KeybindFrame.Visible,
            position = SpecialValueParser.UDim2.Encode(Library.KeybindFrame.Position),
            collapsed = if KeybindMenu then KeybindMenu.Collapsed == true else false,
            settingsOpen = false,
            settingsPosition = SettingsPosition,
            hidden = Hidden,
        }
    end

    --// Toggles
    for Index, Toggle in Library.Toggles do
        if not Toggle.Type then continue end
        if IgnoreIndexes[Index] then continue end

        local Parser = ElementParser[Toggle.Type]
        if not Parser then continue end

        table.insert(CurrentData.objects, Parser.Save(Index, Toggle))
    end

    --// Options
    for Index, Option in Library.Options do
        if not Option.Type then continue end
        if IgnoreIndexes[Index] then continue end

        local Parser = ElementParser[Option.Type]
        if not Parser then continue end

        table.insert(CurrentData.objects, Parser.Save(Index, Option))
    end

    --// Groupboxes, Tabboxes
    for TabIndex, Tab in Library.Tabs do
        if Tab.Groupboxes then
            for Index, Groupbox in Tab.Groupboxes do
                if typeof(Index) ~= "string" or IgnoreIndexes[Index] then continue end

                local Parser = ElementParser.Groupbox
                if not Parser then continue end

                table.insert(CurrentData.objects, Parser.Save(Index, Groupbox, TabIndex))
            end
        end

        if Tab.Tabboxes then
            for Index, Tabbox in Tab.Tabboxes do
                if typeof(Index) ~= "string" or IgnoreIndexes[Index] then continue end

                local Parser = ElementParser.Tabbox
                if not Parser then continue end

                table.insert(CurrentData.objects, Parser.Save(Index, Tabbox, TabIndex))
            end
        end
    end

    local SuccessEncode, EncodedData = pcall(HttpService.JSONEncode, HttpService, CurrentData)
    if not SuccessEncode then
        return "", false, "Failed to encode data"
    end

    return EncodedData, true
end

function SaveManager:Save(ConfigName: string): (boolean, string?)
    if IsStringEmpty(ConfigName) then
        return false, "Invalid config name provided"
    end

    if string.lower(ConfigName) == "autoload" then
        return false, "Invalid config name provided"
    end

    local ConfigPath = GetConfigPath(ConfigName)
    if ConfigPath == false then
        return false, "Invalid config name provided"
    end

    SaveManager:CheckFolderTree()

    local EncodedData, SuccessEncode, EncodeErrorMessage = SaveManager:SaveJSON(ConfigName)
    if not SuccessEncode then
        return false, EncodeErrorMessage
    end

    local SuccessWrite, ErrorMessage = pcall(writefile, ConfigPath, EncodedData)
    if not SuccessWrite then
        return false, "Failed to write config file: " .. tostring(ErrorMessage)
    end

    return true
end

function SaveManager:LoadJSON(Content: string)
    if IsStringEmpty(Content) then
        return false, "No JSON provided"
    end

    local SuccessDecode, Decoded = pcall(HttpService.JSONDecode, HttpService, Content)
    if not SuccessDecode or typeof(Decoded) ~= "table" or typeof(Decoded.objects) ~= "table" then
        return false, "Failed to decode config data"
    end

    local Library = SaveManager.Library
    local LoadingOrder = SaveManager.LoadingOrder
    local IgnoreIndexes = SaveManager.Ignore

    if SaveManager.UseLoadingOrder == true and typeof(LoadingOrder) == "table" then
        table.sort(Decoded.objects, function(a, b)
            local aIndex = table.find(LoadingOrder, a.type) or math.huge
            local bIndex = table.find(LoadingOrder, b.type) or math.huge
            return aIndex < bIndex
        end)
    end

    --// Keybind Menu
    if Library.KeybindFrame and typeof(Decoded.keybindMenu) == "table" then
        local KeybindFrameData = Decoded.keybindMenu
        local IsVisible = KeybindFrameData.visible == true
        local Position = SpecialValueParser.UDim2.Decode(KeybindFrameData.position)

        Library.KeybindFrame.Visible = IsVisible
        Library.KeybindFrame.Position = Position or Library.KeybindFrame.Position

        local KeybindMenuToggle = Library.Options and Library.Options.KeybindMenuOpen
        if KeybindMenuToggle then
            KeybindMenuToggle:SetValue(IsVisible)
        end

        local KeybindMenu = Library.KeybindMenu
        if KeybindMenu then
            if KeybindMenu.SetCollapsed then
                KeybindMenu:SetCollapsed(KeybindFrameData.collapsed == true)
            end

            if typeof(KeybindFrameData.hidden) == "table" then
                for Index, Option in Library.Options do
                    if Option.Type ~= "KeyPicker" or Option.NoUI == true or not Option.SetMenuVisibility then
                        continue
                    end

                    Option:SetMenuVisibility(KeybindFrameData.hidden[Index] ~= true)
                end
            end

            local SettingsPosition = SpecialValueParser.UDim2.Decode(KeybindFrameData.settingsPosition)
            if SettingsPosition and KeybindMenu.SettingsFrame then
                KeybindMenu.SettingsFrame.Position = SettingsPosition
            end
            KeybindMenu:SetSettingsOpen(false)
        end
    end

    --// Elements
    for _, Option in Decoded.objects do
        if not Option.type then continue end
        if IgnoreIndexes[Option.idx] then continue end

        local Parser = ElementParser[Option.type]
        if not Parser then continue end

        task.defer(Parser.Load, Option.idx, Option)
    end

    return true
end

function SaveManager:Load(ConfigName: string): (boolean, string?)
    if IsStringEmpty(ConfigName) then
        return false, "No config is selected"
    end

    local ConfigPath = GetConfigPath(ConfigName)
    if ConfigPath == false or not isfile(ConfigPath) then
        return false, "Config file does not exist"
    end

    local SuccessRead, Content = pcall(readfile, ConfigPath)
    if not SuccessRead then
        return false, "Failed to read config file"
    end

    return SaveManager:LoadJSON(Content)
end

function SaveManager:Delete(ConfigName: string): (boolean | string?)
    if IsStringEmpty(ConfigName) then
        return false, "No config is selected"
    end

    local ConfigPath = GetConfigPath(ConfigName)
    if ConfigPath == false or not isfile(ConfigPath) then
        return false, "Config file does not exist"
    end

    local SuccessDelete, ErrorMessage = pcall(delfile, ConfigPath)
    if not SuccessDelete then
        return false, "Failed to delete config file: " .. tostring(ErrorMessage)
    end

    if ConfigName == SaveManager.AutoloadConfig then
        SaveManager:DeleteAutoLoadConfig()
    end

    return true
end

--// Auto Load Config \\--
function SaveManager:GetAutoloadConfig(): (string, boolean, string?)
    SaveManager:CheckFolderTree()

    local AutoloadPath = GetAutoloadPath()
    if AutoloadPath == false then
        return "none", false, "Invalid path provided"
    end

    if not isfile(AutoloadPath) then
        return "none", false, "Autoload config is not set"
    end

    local SuccessRead, AutoloadConfigName = pcall(readfile, AutoloadPath)
    if not (SuccessRead and typeof(AutoloadConfigName) == "string") then
        return "none", false, AutoloadConfigName
    end

    local ConfigExists = DoesConfigExist(AutoloadConfigName)
    if not ConfigExists then
        return "none", false, "Config file not found"
    end

    SaveManager.AutoloadConfig = AutoloadConfigName
    return AutoloadConfigName, true
end

function SaveManager:SaveAutoloadConfig(ConfigName: string): (boolean, string?)
    if IsStringEmpty(ConfigName) then
        return false, "No config is selected"
    end

    SaveManager:CheckFolderTree()

    local AutoloadPath = GetAutoloadPath()
    if AutoloadPath == false then
        return false, "Invalid path provided"
    end

    if not DoesConfigExist(ConfigName) then
        return false, "Config does not exist"
    end

    local SuccessWrite, ErrorMessage = pcall(writefile, AutoloadPath, ConfigName)
    if not SuccessWrite then
        return false, ErrorMessage
    end

    SaveManager.AutoloadConfig = ConfigName
    return true
end

function SaveManager:LoadAutoloadConfig()
    local ConfigName, Success, FetchErrorMessage = SaveManager:GetAutoloadConfig()
    if not Success or FetchErrorMessage then
        if FetchErrorMessage ~= "Autoload config is not set" then
            SaveManager.Library:Notify(string.format("Failed to load autoload config: %s", FetchErrorMessage))
        end

        return
    end

    local SuccessLoad, LoadErrorMessage = SaveManager:Load(ConfigName)
    if not SuccessLoad then
        SaveManager.Library:Notify(string.format("Failed to load autoload config: %s", LoadErrorMessage))
        return
    end

    SaveManager.Library:Notify(string.format("Successfully loaded autoload config %q", ConfigName))
end

function SaveManager:DeleteAutoLoadConfig(): (boolean, string?)
    SaveManager:CheckFolderTree()

    local AutoloadPath = GetAutoloadPath()
    if AutoloadPath == false then
        return false, "Invalid path provided"
    end

    if not isfile(AutoloadPath) then
        return false, "Autoload config is not set"
    end

    local SuccessDelete, ErrorMessage = pcall(delfile, AutoloadPath)
    if not SuccessDelete then
        return false, ErrorMessage
    end

    SaveManager.AutoloadConfig = nil
    return true
end

--// GUI \\--
local function ShowDialog(
    Condition: () -> boolean,

    Index: string, 
    Title: string, 
    Description: string,

    DestructiveText: string,
    DestructiveAction: () -> nil
)
    if Condition() == false then
        return DestructiveAction()
    end

    return SaveManager.Library.Window:AddDialog(Index, {
        Title = Title,
        Description = Description,
        AutoDismiss = false,

        FooterButtons = {
            Cancel = {
                Title = "Cancel",
                Variant = "Ghost",
                Order = 1,
                Callback = function(Dialog)
                    Dialog:Dismiss()
                end
            },

            DestructiveAction = {
                Title = DestructiveText,
                Variant = "Destructive",
                Order = 2,
                Callback = function(Dialog)
                    Dialog:Dismiss()
                    DestructiveAction()
                end
            }
        }
    })
end

function SaveManager:BuildConfigSection(Tab: any, IconName: string)
    assert(SaveManager.Library, "Library is not set, call SaveManager:SetLibrary(Library) first.")
    local Library = SaveManager.Library

    local ConfigurationBox = Tab:AddGroupbox({
        Side = "Right",
        Name = "Configuration",
        IconName = IconName or "folder-cog",
    })

    local ConfigNameInput, ConfigList, ConfigJSONInput, AutoloadConfigLabel

    local function FormatConfigName(Value: any)
        if Value == SaveManager.AutoloadConfig then
            return string.format("%s (autoload)", Value)
        end

        return Value
    end

    local function RefreshList()
        --// Rebuild rows so the "(autoload)" tag follows the current autoload config
        ConfigList:SetValues(SaveManager:RefreshConfigList())
    end

    local function RefreshAutoloadConfigLabel()
        local AutoloadConfigName, _Success, _ErrorMessage = SaveManager:GetAutoloadConfig()

        AutoloadConfigLabel:SetText(string.format("Autoload: %s", if AutoloadConfigName == "none" then "None" else AutoloadConfigName))
        if ConfigList then RefreshList() end
    end

    --// The selected list entry wins; otherwise fall back to whatever is typed in the name box
    local function GetTargetConfig(): string?
        local Selected = ConfigList.Value
        if not IsStringEmpty(Selected) then
            return Selected
        end

        local Typed = Trim(ConfigNameInput.Value or "")
        if not IsStringEmpty(Typed) then
            return Typed
        end

        return nil
    end

    --// Browse
    ConfigurationBox:AddListBox("SaveManager_ConfigList", {
        Text = "Configs",
        Values = SaveManager:RefreshConfigList(),
        Height = 150,
        Placeholder = "No configs saved yet",
        FormatListValue = FormatConfigName,
    })

    ConfigurationBox:AddInput("SaveManager_ConfigName", {
        Text = "Config Name:",
        Placeholder = "Type config name here...",
        ClearTextOnFocus = false,
    })

    --// Save / Load
    ConfigurationBox:AddButton("Save", function()
        local Typed = Trim(ConfigNameInput.Value or "")
        local ConfigName = if IsStringEmpty(Typed) then ConfigList.Value else Typed

        if IsStringEmpty(ConfigName) then
            Library:Notify("Type a config name or pick one from the list.")
            return
        end

        if string.lower(ConfigName) == "autoload" then
            Library:Notify("Invalid config name provided.")
            return
        end

        ShowDialog(
            function(): boolean
                return DoesConfigExist(ConfigName)
            end,

            "SaveManager_SaveConfig",
            "Overwrite config",
            string.format("A config named %q already exists. Overwriting will replace it with your current settings.", ConfigName),

            "Overwrite",
            function()
                local Success, ErrorMessage = SaveManager:Save(ConfigName)
                if not Success then
                    Library:Notify(string.format("Failed to save config %q: %s", ConfigName, ErrorMessage))
                    return
                end

                Library:Notify(string.format("Saved config %q", ConfigName))
                RefreshList()
                ConfigList:SetValue(ConfigName)
            end
        )
    end):AddButton("Load", function()
        local ConfigName = GetTargetConfig()
        if not ConfigName then
            Library:Notify("Please select a config first.")
            return
        end

        ShowDialog(
            function(): boolean
                return true --// Always show
            end,

            "SaveManager_LoadConfig",
            "Load config",
            string.format("Are you sure you want to load %q? Your current settings will be overwritten.", ConfigName),

            "Load",
            function()
                local Success, ErrorMessage = SaveManager:Load(ConfigName)
                if not Success then
                    Library:Notify(string.format("Failed to load config %q: %s", ConfigName, ErrorMessage))
                    return
                end

                Library:Notify(string.format("Loaded config %q", ConfigName))
            end
        )
    end)

    --// Delete / Refresh
    ConfigurationBox:AddButton("Delete", function()
        local ConfigName = GetTargetConfig()
        if not ConfigName then
            Library:Notify("Please select a config first.")
            return
        end

        ShowDialog(
            function(): boolean
                return true --// Always show
            end,

            "SaveManager_DeleteConfig",
            "Delete config",
            string.format("Are you sure you want to delete %q? This cannot be undone.", ConfigName),

            "Delete",
            function()
                local Success, ErrorMessage = SaveManager:Delete(ConfigName)
                if not Success then
                    Library:Notify(string.format("Failed to delete config %q: %s", ConfigName, ErrorMessage))
                    return
                end

                Library:Notify(string.format("Deleted config %q", ConfigName))
                ConfigNameInput:SetValue("")
                RefreshAutoloadConfigLabel()
            end
        )
    end):AddButton("Refresh", RefreshList)

    --// Autoload
    AutoloadConfigLabel = ConfigurationBox:AddLabel("Autoload: ...", true)

    ConfigurationBox:AddButton("Set Autoload", function()
        local ConfigName = GetTargetConfig()
        if not ConfigName then
            Library:Notify("Please select a config first.")
            return
        end

        local Success, ErrorMessage = SaveManager:SaveAutoloadConfig(ConfigName)
        if not Success then
            Library:Notify(string.format("Failed to set autoload config %q: %s", ConfigName, ErrorMessage))
            return
        end

        Library:Notify(string.format("Autoload set to %q", ConfigName))
        RefreshAutoloadConfigLabel()
    end):AddButton("Clear Autoload", function()
        ShowDialog(
            function(): boolean
                return true --// Always show
            end,

            "SaveManager_ResetAutoload",
            "Clear autoload config",
            "Are you sure you want to clear the autoload config? No config will be loaded automatically on next launch.",

            "Clear",
            function()
                local Success, ErrorMessage = SaveManager:DeleteAutoLoadConfig()
                if not Success then
                    Library:Notify(string.format("Failed to clear autoload config: %s", ErrorMessage))
                    return
                end

                Library:Notify("Cleared autoload config.")
                RefreshAutoloadConfigLabel()
            end
        )
    end)

    --// Import & Export
    ConfigurationBox:AddInput("SaveManager_JSON", {
        Text = "Import / Export:",
        Placeholder = "Export shows the JSON here / paste a config to import",
        ClearTextOnFocus = false,
    })

    ConfigurationBox:AddButton("Export", function()
        local EncodedData, Success, ErrorMessage = SaveManager:SaveJSON()
        if not Success then
            Library:Notify(ErrorMessage)
            return
        end

        ConfigJSONInput:SetValue(EncodedData)
        if setclipboard then
            setclipboard(EncodedData)
            Library:Notify("Copied config to your clipboard")
        end
    end):AddButton("Import", function()
        local ConfigJSON = ConfigJSONInput.Value
        if IsStringEmpty(ConfigJSON) then
            Library:Notify("Paste a config JSON first.")
            return
        end

        ShowDialog(
            function(): boolean
                return true --// Always show
            end,

            "SaveManager_ImportConfig",
            "Import config",
            "Are you sure you want to import this configuration? Your current settings will be overwritten.",

            "Import",
            function()
                local Success, ErrorMessage = SaveManager:LoadJSON(ConfigJSON)
                if not Success then
                    Library:Notify(string.format("Failed to import config: %s", ErrorMessage))
                    return
                end

                Library:Notify("Imported config")
            end
        )
    end)

    --// Set variables
    ConfigNameInput, ConfigList, ConfigJSONInput =
        Library.Options.SaveManager_ConfigName,
        Library.Options.SaveManager_ConfigList,
        Library.Options.SaveManager_JSON;

    --// Picking a config mirrors its name into the name box
    ConfigList:OnChanged(function(Value)
        if not IsStringEmpty(Value) then
            ConfigNameInput:SetValue(Value)
        end
    end)

    --// Refresh
    RefreshAutoloadConfigLabel()
    SaveManager:SetIgnoreIndexes({ "SaveManager_ConfigList", "SaveManager_ConfigName", "SaveManager_JSON" })

    return ConfigurationBox
end

SaveManager:BuildFolderTree()
return SaveManager
