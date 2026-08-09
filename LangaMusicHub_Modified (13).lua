-- Services
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

-- Flowery AI (Groq) configuration
local FLOWERY_API_KEY = "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"
local FLOWERY_API_URL = "https://api.groq.com/openai/v1/chat/completions"
-- Good free/fast Groq models: llama-3.3-70b-versatile, llama-3.1-8b-instant, gemma2-9b-it
local FLOWERY_MODEL = "llama-3.3-70b-versatile"

-- Operational File Directory Framework Paths
local BASE_FOLDER = "LANGAMUSICHUB"
local OWN_FOLDER = BASE_FOLDER .. "/OWN MUSIC"
local RBX_FOLDER = BASE_FOLDER .. "/RBXMUSIC"
local DATA_FILE = BASE_FOLDER .. "/data.txt"
local PERSONAS_FOLDER = BASE_FOLDER .. "/PERSONAS"
local ACTIVE_PERSONA_FILE = BASE_FOLDER .. "/active_persona.txt"

local DEFAULT_FLOWERY_PERSONALITY = [[You are Flowey (sometimes called Flowery), the talking flower from Deltarune / Undertale.
Personality: Cheerful and friendly on the surface, a little mischievous, dramatic, and slightly unhinged. You love calling people "idiot" or "friend" in a teasing way. You speak with lots of energy, occasional all-caps for emphasis, and flower/plant puns. You know Deltarune and Undertale lore very well.
You live inside the Langa Music Hub script and know how the player works (RBX MUSIC, OWN MUSIC, holds for scans, settings, volume, shuffle, RGB effects, etc.).
Answer questions about the music player clearly when asked. Keep replies short and stay in character. Never break character.]]

-- Flowery is hardcoded in the script only — never written to the PERSONAS folder
local FLOWERY_PERSONA = {
    id = "flowery",
    name = "Flowery",
    personality = DEFAULT_FLOWERY_PERSONALITY,
    locked = true
}

-- Verify Hardware/Executor Compatibility
if not isfolder or not makefolder or not listfiles or not getcustomasset or not readfile or not writefile then
    error("Your executor does not support required file system functions.")
end

-- Provision missing operational framework target directories
if not isfolder(BASE_FOLDER) then makefolder(BASE_FOLDER) end
if not isfolder(OWN_FOLDER) then makefolder(OWN_FOLDER) end
if not isfolder(RBX_FOLDER) then makefolder(RBX_FOLDER) end
if not isfolder(PERSONAS_FOLDER) then makefolder(PERSONAS_FOLDER) end

-- Clipboard setup
local setclipboard = setclipboard or toclipboard or set_clipboard

-- Executor & Version Identifier Helper
local function GetExecutorInfo()
    local name = "Unknown Executor"
    local ver = "1.0.0"
    
    if identifyexecutor then
        local execName, execVer = identifyexecutor()
        name = execName or name
        ver = execVer or ver
    elseif getexecutorname then
        name = getexecutorname()
    end
    
    return name, ver
end

-- Data Management (data.txt)
local function GetWelcomeSetting()
    if isfile and isfile(DATA_FILE) then
        local content = readfile(DATA_FILE)
        if content:find("WT = FALSE") then
            return false -- Don't show welcome
        end
    end
    return true -- Show welcome by default
end

local function SaveWelcomeSetting(showWelcome)
    if writefile then
        if showWelcome then
            writefile(DATA_FILE, "WT = TRUE")
        else
            writefile(DATA_FILE, "WT = FALSE")
        end
    end
end

-- Persistent Settings Helpers
local function GetDataSetting(key, defaultValue)
    if isfile and isfile(DATA_FILE) then
        local content = readfile(DATA_FILE)
        local value = content:match(key .. "%s*=%s*(TRUE|FALSE)")
        if value then return value == "TRUE" end
    end
    return defaultValue
end

local function SaveDataSettings(settings)
    if not writefile then return end
    local lines = {
        "WT = " .. (settings.WT and "TRUE" or "FALSE"),
        "MUTE = " .. (settings.MUTE and "TRUE" or "FALSE"),
        "FLASH = " .. (settings.FLASH and "TRUE" or "FALSE"),
        "STATS = " .. (settings.STATS and "TRUE" or "FALSE"),
        "RGB = " .. (settings.RGB and "TRUE" or "FALSE"),
        "FULLRGB = " .. (settings.FULLRGB and "TRUE" or "FALSE"),
        "PEPPINO = " .. (settings.PEPPINO and "TRUE" or "FALSE"),
    }
    writefile(DATA_FILE, table.concat(lines, "\n"))
end

local function LoadPersistentSettings()
    return {
        WT = GetDataSetting("WT", true),
        MUTE = GetDataSetting("MUTE", false),
        FLASH = GetDataSetting("FLASH", true),
        STATS = GetDataSetting("STATS", false),
        RGB = GetDataSetting("RGB", true),
        FULLRGB = GetDataSetting("FULLRGB", false),
        PEPPINO = GetDataSetting("PEPPINO", true),
    }
end

-- Persona system: Flowery is hardcoded; custom personas live as .json files in PERSONAS/
local function LoadPersonas()
    local list = { FLOWERY_PERSONA }
    if isfolder and isfolder(PERSONAS_FOLDER) then
        local ok, files = pcall(listfiles, PERSONAS_FOLDER)
        if ok and files then
            for _, filePath in ipairs(files) do
                if filePath:lower():match("%.json$") then
                    local rok, raw = pcall(readfile, filePath)
                    if rok and raw then
                        local jok, data = pcall(function() return HttpService:JSONDecode(raw) end)
                        if jok and type(data) == "table" and data.name and data.personality then
                            local id = data.id or filePath:match("([^/\\]+)%.json$") or ("p_" .. tostring(math.random(100000, 999999)))
                            if id ~= "flowery" then
                                table.insert(list, {
                                    id = id,
                                    name = data.name,
                                    personality = data.personality,
                                    locked = false,
                                    filePath = filePath
                                })
                            end
                        end
                    end
                end
            end
        end
    end
    local activeId = "flowery"
    if isfile and isfile(ACTIVE_PERSONA_FILE) then
        local aok, aid = pcall(readfile, ACTIVE_PERSONA_FILE)
        if aok and aid and aid ~= "" then
            activeId = aid:match("^%s*(.-)%s*$") or "flowery"
        end
    end
    -- validate activeId exists
    local found = false
    for _, p in ipairs(list) do
        if p.id == activeId then found = true break end
    end
    if not found then activeId = "flowery" end
    return list, activeId
end

local function SaveActivePersonaId(activeId)
    if writefile then
        pcall(writefile, ACTIVE_PERSONA_FILE, activeId or "flowery")
    end
end

local function SaveCustomPersona(persona)
    if not writefile or persona.locked then return end
    if not isfolder(PERSONAS_FOLDER) then makefolder(PERSONAS_FOLDER) end
    local safeName = (persona.name or "persona"):gsub("[^%w%-_ ]", ""):gsub("%s+", "_")
    if safeName == "" then safeName = persona.id end
    local path = PERSONAS_FOLDER .. "/" .. safeName .. "_" .. persona.id .. ".json"
    local payload = {
        id = persona.id,
        name = persona.name,
        personality = persona.personality
    }
    pcall(function()
        writefile(path, HttpService:JSONEncode(payload))
    end)
    persona.filePath = path
end

local function DeleteCustomPersona(persona)
    if persona.locked or not persona.filePath then return end
    if isfile and isfile(persona.filePath) and delfile then
        pcall(delfile, persona.filePath)
    elseif isfile and isfile(persona.filePath) and writefile then
        -- fallback: overwrite empty if no delfile
        pcall(writefile, persona.filePath, "")
    end
end

local function GetActivePersona(personas, activeId)
    for _, p in ipairs(personas) do
        if p.id == activeId then return p end
    end
    return personas[1]
end

local function GeneratePersonaId()
    return "p_" .. tostring(math.floor(os.clock() * 1000)) .. "_" .. tostring(math.random(1000, 9999))
end

-- Smooth button press animation helper
local function AnimateButtonPress(btn)
    if not btn or not btn.Parent then return end
    local original = btn.Size
    TweenService:Create(btn, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(original.X.Scale, original.X.Offset * 0.92, original.Y.Scale, original.Y.Offset * 0.92)
    }):Play()
    task.delay(0.08, function()
        if btn and btn.Parent then
            TweenService:Create(btn, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Size = original
            }):Play()
        end
    end)
end

-- Peppino helpers
local PEPPINO_ICON = "rbxassetid://12412861287"
local PEPPINO_SQUISH_SOUND = "rbxassetid://72412705492327"
local PEPPINO_KILL_SOUND = "rbxassetid://138687206526097"
local PEPPINO_FLASH_IMG = "rbxassetid://10865403406"

local function PeppinoNotify(text)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Peppino",
            Text = text,
            Duration = 3,
            Icon = PEPPINO_ICON
        })
    end)
end

local function PlayPeppinoSound(soundId, parent)
    local s = Instance.new("Sound")
    s.SoundId = soundId
    s.Volume = 1
    s.Parent = parent or CoreGui
    s:Play()
    s.Ended:Connect(function() s:Destroy() end)
    task.delay(8, function() if s and s.Parent then s:Destroy() end end)
end

local function PeppinoKillEffect(ScreenGui)
    -- Kill local character
    pcall(function()
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.Health = 0 end
        end
    end)
    PlayPeppinoSound(PEPPINO_KILL_SOUND, CoreGui)
    PeppinoNotify("STOP")

    local flash = Instance.new("ImageLabel")
    flash.Size = UDim2.new(1, 0, 1, 0)
    flash.Position = UDim2.new(0, 0, 0, 0)
    flash.BackgroundTransparency = 1
    flash.Image = PEPPINO_FLASH_IMG
    flash.ImageTransparency = 0
    flash.ScaleType = Enum.ScaleType.Fit
    flash.ZIndex = 999999
    flash.Parent = ScreenGui
    TweenService:Create(flash, TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        ImageTransparency = 1
    }):Play()
    task.delay(2.7, function() if flash and flash.Parent then flash:Destroy() end end)
end

local function BindPeppinoClick(btn, ScreenGui)
    btn.MouseButton1Click:Connect(function()
        -- Squish animation
        local orig = btn.Size
        local origPos = btn.Position
        TweenService:Create(btn, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(orig.X.Scale, orig.X.Offset, orig.Y.Scale, orig.Y.Offset * 0.55),
            Position = UDim2.new(origPos.X.Scale, origPos.X.Offset, origPos.Y.Scale, origPos.Y.Offset + orig.Y.Offset * 0.22)
        }):Play()
        task.delay(0.09, function()
            if btn and btn.Parent then
                TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                    Size = orig,
                    Position = origPos
                }):Play()
            end
        end)
        PlayPeppinoSound(PEPPINO_SQUISH_SOUND, CoreGui)
        -- 10% chance to kill
        if math.random(1, 10) == 1 then
            PeppinoKillEffect(ScreenGui)
        end
    end)
end

local function CreatePeppinoCorner(ScreenGui)
    local btn = Instance.new("ImageButton")
    btn.Name = "PeppinoCorner"
    btn.Size = UDim2.new(0, 64, 0, 64)
    btn.Position = UDim2.new(0, 12, 1, -76)
    btn.BackgroundTransparency = 1
    btn.Image = PEPPINO_ICON
    btn.ScaleType = Enum.ScaleType.Fit
    btn.ZIndex = 50
    btn.Parent = ScreenGui
    BindPeppinoClick(btn, ScreenGui)
    return btn
end

-- Flowery AI request helper (uses executor request / http_request / syn.request)
local function AskFlowery(userMessage, conversationHistory, systemPrompt)
    conversationHistory = conversationHistory or {}
    systemPrompt = systemPrompt or DEFAULT_FLOWERY_PERSONALITY

    local messages = {
        {role = "system", content = systemPrompt}
    }
    
    for _, msg in ipairs(conversationHistory) do
        table.insert(messages, msg)
    end
    table.insert(messages, {role = "user", content = userMessage})

    local body = HttpService:JSONEncode({
        model = FLOWERY_MODEL,
        messages = messages,
        temperature = 0.7,
        max_tokens = 600,
        stream = false
    })

    local requestFunc = request or http_request or (syn and syn.request) or (http and http.request)
    if not requestFunc then
        return nil, "No HTTP request function available in this executor."
    end

    local success, response = pcall(function()
        return requestFunc({
            Url = FLOWERY_API_URL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["Authorization"] = "Bearer " .. FLOWERY_API_KEY
            },
            Body = body
        })
    end)

    if not success then
        return nil, "Request failed: " .. tostring(response)
    end

    if type(response) ~= "table" then
        return nil, "Bad response type: " .. type(response) .. " → " .. tostring(response)
    end

    -- Collect possible status / body fields (different executors use different names)
    local statusCode = response.StatusCode or response.status_code or response.Status or response.status or response.Code or 0
    local bodyStr = response.Body or response.body or response.ResponseBody or response.response or response.Data or response.data or ""

    if type(bodyStr) == "table" then
        -- some executors already decoded it
        local ok, encoded = pcall(HttpService.JSONEncode, HttpService, bodyStr)
        bodyStr = ok and encoded or tostring(bodyStr)
    end
    bodyStr = tostring(bodyStr or "")

    if tonumber(statusCode) ~= 200 then
        local errMsg = "API error " .. tostring(statusCode)

        if bodyStr ~= "" then
            local ok, parsed = pcall(HttpService.JSONDecode, HttpService, bodyStr)
            if ok and type(parsed) == "table" then
                if parsed.error then
                    local e = parsed.error
                    if type(e) == "table" and e.message then
                        errMsg = errMsg .. ": " .. tostring(e.message)
                    else
                        errMsg = errMsg .. ": " .. tostring(e)
                    end
                elseif parsed.message then
                    errMsg = errMsg .. ": " .. tostring(parsed.message)
                else
                    local raw = bodyStr
                    if #raw > 150 then raw = raw:sub(1, 150) .. "..." end
                    errMsg = errMsg .. " | " .. raw
                end
            else
                local raw = bodyStr
                if #raw > 150 then raw = raw:sub(1, 150) .. "..." end
                errMsg = errMsg .. " | " .. raw
            end
        else
            -- no body – list the keys so we can see what the executor returned
            local keys = {}
            for k, _ in pairs(response) do
                table.insert(keys, tostring(k))
            end
            errMsg = errMsg .. " (no body). Response keys: " .. table.concat(keys, ", ")
        end

        if tonumber(statusCode) == 403 then
            errMsg = errMsg .. "\n\nTip: Check your Groq account has credits / rate limits at console.groq.com"
        elseif tonumber(statusCode) == 401 then
            errMsg = errMsg .. "\n\nAPI key is invalid or expired. Create a new one at console.groq.com"
        end
        return nil, errMsg
    end

    local ok, data = pcall(HttpService.JSONDecode, HttpService, bodyStr)
    if not ok or type(data) ~= "table" or not data.choices or not data.choices[1] or not data.choices[1].message then
        local preview = bodyStr
        if #preview > 120 then preview = preview:sub(1, 120) .. "..." end
        return nil, "Failed to parse AI response. Body: " .. preview
    end

    return data.choices[1].message.content, nil
end

-- Deep Folder Scanner for Workspace Storage
local function DeepScanExecutorWorkspace(dir, accumulatedTracks)
    accumulatedTracks = accumulatedTracks or {}
    local success, files = pcall(listfiles, dir)
    if not success or not files then return accumulatedTracks end

    for _, filePath in ipairs(files) do
        if isfolder(filePath) then
            DeepScanExecutorWorkspace(filePath, accumulatedTracks)
        else
            local ext = filePath:match("%.(%w+)$")
            if ext and (ext:lower() == "mp4" or ext:lower() == "mp3" or ext:lower() == "wav" or ext:lower() == "ogg") then
                local cleanName = filePath:match("([^/\\]+)%.%w+$") or "Local Track"
                table.insert(accumulatedTracks, {
                    Id = getcustomasset(filePath),
                    Name = "[SCANNED WORKSPACE]: " .. cleanName
                })
            end
        end
    end
    return accumulatedTracks
end
-- Fallback Integrated Track Array & Assets
local BUILTIN_RBX = {
    {Id = "rbxassetid://95455387850059", Name = "Roblox Track 1"}
}
local DISC_ASSET_ID = "rbxassetid://731317869"

-- Centralized Audio State Architecture Map
local AudioPlayer = {
    Playlist = {},
    CurrentIndex = 0,
    SoundObject = nil,
    IsPaused = false,
    OnTrackChanged = nil,
    DiscConnection = nil,
    PeakConnection = nil,
    CurrentVolume = 0.5,
    IsGameMuted = false,
    IsFlashEnabled = true,
    IsChromaEnabled = true,
    IsFullChroma = false,
    OriginalGameVolumes = {}
}

function AudioPlayer:Initialize(discObject, flashOverlay)
    if not self.SoundObject then
        self.SoundObject = Instance.new("Sound")
        self.SoundObject.Volume = self.CurrentVolume
        self.SoundObject.Parent = CoreGui
        
        self.SoundObject.Ended:Connect(function()
            self:PlayNext()
        end)
    end
    
    if discObject and not self.DiscConnection then
        local rotationSpeed = 60
        self.DiscConnection = RunService.RenderStepped:Connect(function(dt)
            if self.SoundObject.IsPlaying and not self.IsPaused then
                discObject.Rotation = (discObject.Rotation + (rotationSpeed * dt)) % 360
            end
        end)
    end

    if flashOverlay and not self.PeakConnection then
        local lastFlashTime = 0
        self.PeakConnection = RunService.RenderStepped:Connect(function()
            if self.SoundObject.IsPlaying and not self.IsPaused and self.IsFlashEnabled then
                if self.SoundObject.PlaybackLoudness > 320 then
                    local now = os.clock()
                    if now - lastFlashTime > 0.18 then
                        lastFlashTime = now
                        flashOverlay.BackgroundTransparency = 0
                        local fadeInfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                        TweenService:Create(flashOverlay, fadeInfo, {BackgroundTransparency = 1}):Play()
                    end
                end
            end
        end)
    end
end

function AudioPlayer:SetVolume(val)
    self.CurrentVolume = math.clamp(val, 0, 1)
    if self.SoundObject then self.SoundObject.Volume = self.CurrentVolume end
    return self.CurrentVolume
end

function AudioPlayer:ToggleGameMute()
    self.IsGameMuted = not self.IsGameMuted
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("Sound") and obj ~= self.SoundObject then
            if self.IsGameMuted then
                self.OriginalGameVolumes[obj] = obj.Volume
                obj.Volume = 0
            elseif self.OriginalGameVolumes[obj] then
                obj.Volume = self.OriginalGameVolumes[obj]
            end
        end
    end
    return self.IsGameMuted
end

function AudioPlayer:PlayTrack(index)
    if #self.Playlist == 0 then return end
    if index < 1 then index = #self.Playlist end
    if index > #self.Playlist then index = 1 end
    
    self.CurrentIndex = index
    local track = self.Playlist[self.CurrentIndex]
    self.SoundObject:Stop()
    self.SoundObject.SoundId = track.Id
    self.IsPaused = false
    
    if not self.SoundObject.IsLoaded then self.SoundObject.Loaded:Wait() end
    self.SoundObject:Play()
    if self.OnTrackChanged then self.OnTrackChanged(track.Name) end
end

function AudioPlayer:PlayNext() if #self.Playlist <= 1 then return end self:PlayTrack(self.CurrentIndex + 1) end
function AudioPlayer:PlayPrevious() if #self.Playlist <= 1 then return end self:PlayTrack(self.CurrentIndex - 1) end
function AudioPlayer:TogglePause() if #self.Playlist == 0 then return false end self.IsPaused = not self.IsPaused if self.IsPaused then self.SoundObject:Pause() else self.SoundObject:Resume() end return self.IsPaused end

function AudioPlayer:ShufflePlaylist()
    if #self.Playlist <= 1 then return end
    local currentTrack = self.Playlist[self.CurrentIndex]
    for i = #self.Playlist, 2, -1 do
        local j = math.random(1, i)
        self.Playlist[i], self.Playlist[j] = self.Playlist[j], self.Playlist[i]
    end
    for i, track in ipairs(self.Playlist) do if track == currentTrack then self.CurrentIndex = i break end end
end

function AudioPlayer:StopEverything() if self.SoundObject then self.SoundObject:Stop() self.SoundObject.SoundId = "" end self.Playlist = {} self.CurrentIndex = 0 self.IsPaused = false end
function AudioPlayer:Start(tracks) self.Playlist = tracks self:PlayTrack(1) end

-- Audio-Reactive Decibel Chroma Loop
local function ApplyDecibelChroma(frame)
    task.spawn(function()
        local hue = 0
        local baseColor = Color3.fromRGB(25, 25, 30)
        while frame and frame.Parent do
            if not AudioPlayer.IsChromaEnabled then
                if frame.BackgroundColor3 ~= baseColor then
                    TweenService:Create(frame, TweenInfo.new(0.15, Enum.EasingStyle.Linear), {BackgroundColor3 = baseColor}):Play()
                end
                task.wait(0.2)
            else
                hue = (hue + (1/480)) % 1
                local currentVolMultiplier = AudioPlayer.CurrentVolume
                local targetSaturation, targetValue
                if AudioPlayer.IsFullChroma then
                    -- Full bright RGB
                    targetSaturation = math.clamp(0.55 + (0.4 * currentVolMultiplier), 0.55, 1)
                    targetValue = math.clamp(0.35 + (0.35 * currentVolMultiplier), 0.35, 0.75)
                else
                    -- Original dark hue
                    targetSaturation = math.clamp(0.2 + (0.5 * currentVolMultiplier), 0, 0.7)
                    targetValue = math.clamp(0.08 + (0.15 * currentVolMultiplier), 0, 0.25)
                end
                local targetRGB = Color3.fromHSV(hue, targetSaturation, targetValue)
                TweenService:Create(frame, TweenInfo.new(0.08, Enum.EasingStyle.Linear), {BackgroundColor3 = targetRGB}):Play()
                task.wait(0.04)
            end
        end
    end)
end

-- Smooth UI Window Transitions (size + soft fade)
local function FadeUIWindow(frame, state, customDuration, customStyle)
    local style = customStyle or Enum.EasingStyle.Back
    local duration = customDuration or 0.4
    if state then
        frame.Size = UDim2.new(0, 0, 0, 0)
        frame.BackgroundTransparency = 1
        frame.Visible = true
        local finalSize = frame:GetAttribute("TargetSize") or UDim2.new(0, 360, 0, 220)
        TweenService:Create(frame, TweenInfo.new(duration, style, Enum.EasingDirection.Out), {
            Size = finalSize,
            BackgroundTransparency = 0
        }):Play()
    else
        local hideTween = TweenService:Create(frame, TweenInfo.new(duration * 0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 1
        })
        hideTween:Play()
        hideTween.Completed:Connect(function()
            if frame and frame.Parent and frame.Size.X.Offset == 0 then
                frame.Visible = false
                frame.BackgroundTransparency = 0
            end
        end)
    end
end
local function CreateWelcomeUI(ScreenGui, onReadyCallback, updateSettingsToggleUI)
    local execName, execVer = GetExecutorInfo()
    
    local WelcomeFrame = Instance.new("Frame")
    WelcomeFrame.Size = UDim2.new(0, 400, 0, 260)
    WelcomeFrame.Position = UDim2.new(0.5, -200, 0.5, -130)
    WelcomeFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    WelcomeFrame.BorderSizePixel = 0
    WelcomeFrame.ClipsDescendants = true
    WelcomeFrame:SetAttribute("TargetSize", UDim2.new(0, 400, 0, 260))
    WelcomeFrame.Parent = ScreenGui
    Instance.new("UICorner", WelcomeFrame).CornerRadius = UDim.new(0, 12)
    ApplyDecibelChroma(WelcomeFrame)

    -- Avatar Profile Image
    local AvatarImage = Instance.new("ImageLabel")
    AvatarImage.Size = UDim2.new(0, 65, 0, 65)
    AvatarImage.Position = UDim2.new(0, 20, 0, 20)
    AvatarImage.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    AvatarImage.Parent = WelcomeFrame
    Instance.new("UICorner", AvatarImage).CornerRadius = UDim.new(1, 0)

    -- Fetch Player Headshot
    task.spawn(function()
        local content, isLoaded = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
        if isLoaded then AvatarImage.Image = content end
    end)

    -- Greeting Label
    local WelcomeText = Instance.new("TextLabel")
    WelcomeText.Size = UDim2.new(1, -115, 0, 75)
    WelcomeText.Position = UDim2.new(0, 95, 0, 15)
    WelcomeText.BackgroundTransparency = 1
    WelcomeText.Text = string.format("hello, <b>%s</b> (@%s).\nWelcome to my script! Ready to listen to some music??\n<font color=\"rgb(160,160,180)\">(Executor: %s, Version: %s)</font>", LocalPlayer.DisplayName, LocalPlayer.Name, execName, execVer)
    WelcomeText.TextColor3 = Color3.fromRGB(255, 255, 255)
    WelcomeText.TextSize = 13
    WelcomeText.Font = Enum.Font.SourceSans
    WelcomeText.RichText = true
    WelcomeText.TextWrapped = true
    WelcomeText.TextXAlignment = Enum.TextXAlignment.Left
    WelcomeText.Parent = WelcomeFrame

    -- "Don't show this again" Checkbox Container
    local CheckBoxFrame = Instance.new("Frame")
    CheckBoxFrame.Size = UDim2.new(1, -40, 0, 25)
    CheckBoxFrame.Position = UDim2.new(0, 20, 0, 110)
    CheckBoxFrame.BackgroundTransparency = 1
    CheckBoxFrame.Parent = WelcomeFrame

    local CheckBox = Instance.new("TextButton")
    CheckBox.Size = UDim2.new(0, 20, 0, 20)
    CheckBox.Position = UDim2.new(0, 0, 0, 2)
    CheckBox.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    CheckBox.Text = ""
    CheckBox.Parent = CheckBoxFrame
    Instance.new("UICorner", CheckBox).CornerRadius = UDim.new(0, 4)

    local CheckBoxText = Instance.new("TextLabel")
    CheckBoxText.Size = UDim2.new(1, -30, 1, 0)
    CheckBoxText.Position = UDim2.new(0, 28, 0, 0)
    CheckBoxText.BackgroundTransparency = 1
    CheckBoxText.Text = "Don't show this again (can be toggled back in settings)"
    CheckBoxText.TextColor3 = Color3.fromRGB(200, 200, 210)
    CheckBoxText.TextSize = 12
    CheckBoxText.Font = Enum.Font.SourceSans
    CheckBoxText.TextXAlignment = Enum.TextXAlignment.Left
    CheckBoxText.Parent = CheckBoxFrame

    local isChecked = not GetWelcomeSetting()
    local function UpdateCheckGraphic()
        CheckBox.Text = isChecked and "✓" or ""
        CheckBox.TextColor3 = Color3.fromRGB(35, 185, 105)
    end
    UpdateCheckGraphic()

    CheckBox.MouseButton1Click:Connect(function()
        isChecked = not isChecked
        UpdateCheckGraphic()
        SaveDataSettings({
            WT = not isChecked,
            MUTE = GetDataSetting("MUTE", false),
            FLASH = GetDataSetting("FLASH", true),
            STATS = GetDataSetting("STATS", false),
            RGB = GetDataSetting("RGB", true),
            FULLRGB = GetDataSetting("FULLRGB", false),
            PEPPINO = GetDataSetting("PEPPINO", true),
        })
        if updateSettingsToggleUI then updateSettingsToggleUI() end
    end)

    -- Ready! Proceed Button
    local ReadyBtn = Instance.new("TextButton")
    ReadyBtn.Size = UDim2.new(1, -40, 0, 45)
    ReadyBtn.Position = UDim2.new(0, 20, 0, 150)
    ReadyBtn.BackgroundColor3 = Color3.fromRGB(15, 125, 235)
    ReadyBtn.Text = "READY!"
    ReadyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    ReadyBtn.Font = Enum.Font.SourceSansBold
    ReadyBtn.TextSize = 18
    ReadyBtn.Parent = WelcomeFrame
    Instance.new("UICorner", ReadyBtn).CornerRadius = UDim.new(0, 8)

    -- Peppino (bottom of welcome)
    local PeppinoBtn = Instance.new("ImageButton")
    PeppinoBtn.Name = "Peppino"
    PeppinoBtn.Size = UDim2.new(0, 48, 0, 48)
    PeppinoBtn.Position = UDim2.new(0, 12, 1, -54)
    PeppinoBtn.BackgroundTransparency = 1
    PeppinoBtn.Image = PEPPINO_ICON
    PeppinoBtn.ScaleType = Enum.ScaleType.Fit
    PeppinoBtn.ZIndex = 5
    PeppinoBtn.Parent = WelcomeFrame
    BindPeppinoClick(PeppinoBtn, ScreenGui)

    local PeppinoLabel = Instance.new("TextLabel")
    PeppinoLabel.Size = UDim2.new(0, 60, 0, 16)
    PeppinoLabel.Position = UDim2.new(0, 8, 1, -18)
    PeppinoLabel.BackgroundTransparency = 1
    PeppinoLabel.Text = "peppino"
    PeppinoLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
    PeppinoLabel.TextSize = 11
    PeppinoLabel.Font = Enum.Font.SourceSansItalic
    PeppinoLabel.Parent = WelcomeFrame

    local Watermark = Instance.new("TextLabel")
    Watermark.Size = UDim2.new(1, -12, 0, 20)
    Watermark.Position = UDim2.new(0, 6, 1, -22)
    Watermark.BackgroundTransparency = 1
    Watermark.Text = "by langarsch on discord:)"
    Watermark.TextColor3 = Color3.fromRGB(200, 200, 220)
    Watermark.TextSize = 12
    Watermark.Font = Enum.Font.SourceSansItalic
    Watermark.TextXAlignment = Enum.TextXAlignment.Right
    Watermark.Parent = WelcomeFrame

    ReadyBtn.MouseButton1Click:Connect(function()
        FadeUIWindow(WelcomeFrame, false)
        task.wait(0.3)
        WelcomeFrame:Destroy()
        onReadyCallback()
    end)

    FadeUIWindow(WelcomeFrame, true, 0.5, Enum.EasingStyle.Back)
end

-- Flowery AI Chat Window (with persona support)
local function CreateFloweryAIUI(ScreenGui, onClose)
    local personas, activeId = LoadPersonas()
    local activePersona = GetActivePersona(personas, activeId)

    local AiFrame = Instance.new("Frame")
    AiFrame.Size = UDim2.new(0, 380, 0, 420)
    AiFrame.Position = UDim2.new(0.5, -190, 0.5, -210)
    AiFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    AiFrame.BorderSizePixel = 0
    AiFrame.ClipsDescendants = true
    AiFrame:SetAttribute("TargetSize", UDim2.new(0, 380, 0, 420))
    AiFrame.Parent = ScreenGui
    Instance.new("UICorner", AiFrame).CornerRadius = UDim.new(0, 12)
    ApplyDecibelChroma(AiFrame)

    local TitleBar = Instance.new("Frame")
    TitleBar.Size = UDim2.new(1, -80, 0, 36)
    TitleBar.Position = UDim2.new(0, 8, 0, 6)
    TitleBar.BackgroundTransparency = 1
    TitleBar.Parent = AiFrame

    local TitleIcon = Instance.new("ImageLabel")
    TitleIcon.Size = UDim2.new(0, 28, 0, 28)
    TitleIcon.Position = UDim2.new(0, 0, 0.5, -14)
    TitleIcon.BackgroundTransparency = 1
    TitleIcon.Image = "rbxassetid://96502120778145"
    TitleIcon.ScaleType = Enum.ScaleType.Fit
    TitleIcon.Parent = TitleBar

    local TitleText = Instance.new("TextLabel")
    TitleText.Size = UDim2.new(1, -36, 1, 0)
    TitleText.Position = UDim2.new(0, 34, 0, 0)
    TitleText.BackgroundTransparency = 1
    TitleText.Text = activePersona.name .. " AI"
    TitleText.TextColor3 = Color3.fromRGB(255, 200, 220)
    TitleText.TextSize = 18
    TitleText.Font = Enum.Font.SourceSansBold
    TitleText.TextXAlignment = Enum.TextXAlignment.Left
    TitleText.Parent = TitleBar

    local SettingsAiBtn = Instance.new("TextButton")
    SettingsAiBtn.Size = UDim2.new(0, 28, 0, 28)
    SettingsAiBtn.Position = UDim2.new(1, -68, 0, 8)
    SettingsAiBtn.BackgroundTransparency = 1
    SettingsAiBtn.Text = "⚙"
    SettingsAiBtn.TextColor3 = Color3.fromRGB(220, 220, 230)
    SettingsAiBtn.TextSize = 18
    SettingsAiBtn.Font = Enum.Font.SourceSansBold
    SettingsAiBtn.Parent = AiFrame

    local CloseAiBtn = Instance.new("TextButton")
    CloseAiBtn.Size = UDim2.new(0, 30, 0, 30)
    CloseAiBtn.Position = UDim2.new(1, -36, 0, 6)
    CloseAiBtn.BackgroundTransparency = 1
    CloseAiBtn.Text = "X"
    CloseAiBtn.TextColor3 = Color3.fromRGB(240, 80, 80)
    CloseAiBtn.TextSize = 18
    CloseAiBtn.Font = Enum.Font.SourceSansBold
    CloseAiBtn.Parent = AiFrame

    -- Chat area
    local ChatScroll = Instance.new("ScrollingFrame")
    ChatScroll.Size = UDim2.new(1, -20, 1, -110)
    ChatScroll.Position = UDim2.new(0, 10, 0, 42)
    ChatScroll.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    ChatScroll.BackgroundTransparency = 0.3
    ChatScroll.BorderSizePixel = 0
    ChatScroll.ScrollBarThickness = 5
    ChatScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    ChatScroll.Parent = AiFrame
    Instance.new("UICorner", ChatScroll).CornerRadius = UDim.new(0, 8)

    local ChatLayout = Instance.new("UIListLayout")
    ChatLayout.Parent = ChatScroll
    ChatLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ChatLayout.Padding = UDim.new(0, 6)
    ChatLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left

    -- Persona settings panel (hidden by default)
    local PersonaPanel = Instance.new("ScrollingFrame")
    PersonaPanel.Size = UDim2.new(1, -20, 1, -110)
    PersonaPanel.Position = UDim2.new(0, 10, 0, 42)
    PersonaPanel.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    PersonaPanel.BackgroundTransparency = 0.15
    PersonaPanel.BorderSizePixel = 0
    PersonaPanel.ScrollBarThickness = 5
    PersonaPanel.CanvasSize = UDim2.new(0, 0, 0, 0)
    PersonaPanel.Visible = false
    PersonaPanel.Parent = AiFrame
    Instance.new("UICorner", PersonaPanel).CornerRadius = UDim.new(0, 8)

    local PersonaLayout = Instance.new("UIListLayout")
    PersonaLayout.Parent = PersonaPanel
    PersonaLayout.SortOrder = Enum.SortOrder.LayoutOrder
    PersonaLayout.Padding = UDim.new(0, 6)

    local InputBox = Instance.new("TextBox")
    InputBox.Size = UDim2.new(1, -90, 0, 36)
    InputBox.Position = UDim2.new(0, 10, 1, -48)
    InputBox.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    InputBox.Text = ""
    InputBox.PlaceholderText = "Ask " .. activePersona.name .. " anything..."
    InputBox.PlaceholderColor3 = Color3.fromRGB(140, 140, 160)
    InputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    InputBox.TextSize = 14
    InputBox.Font = Enum.Font.SourceSans
    InputBox.ClearTextOnFocus = false
    InputBox.TextXAlignment = Enum.TextXAlignment.Left
    InputBox.Parent = AiFrame
    Instance.new("UICorner", InputBox).CornerRadius = UDim.new(0, 8)
    Instance.new("UIPadding", InputBox).PaddingLeft = UDim.new(0, 8)

    local SendBtn = Instance.new("TextButton")
    SendBtn.Size = UDim2.new(0, 70, 0, 36)
    SendBtn.Position = UDim2.new(1, -80, 1, -48)
    SendBtn.BackgroundColor3 = Color3.fromRGB(180, 70, 160)
    SendBtn.Text = "Send"
    SendBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    SendBtn.Font = Enum.Font.SourceSansBold
    SendBtn.TextSize = 15
    SendBtn.Parent = AiFrame
    Instance.new("UICorner", SendBtn).CornerRadius = UDim.new(0, 8)

    local conversation = {}
    local isWaiting = false
    local showingPersonas = false

    local function UpdateChatScroll(forceBottom)
        task.defer(function()
            if not ChatScroll or not ChatScroll.Parent then return end
            local contentY = ChatLayout.AbsoluteContentSize.Y
            ChatScroll.CanvasSize = UDim2.new(0, 0, 0, math.max(contentY + 16, 0))
            if forceBottom ~= false then
                ChatScroll.CanvasPosition = Vector2.new(0, math.max(0, contentY - ChatScroll.AbsoluteWindowSize.Y + 24))
            end
        end)
        task.delay(0.06, function()
            if not ChatScroll or not ChatScroll.Parent then return end
            local contentY = ChatLayout.AbsoluteContentSize.Y
            ChatScroll.CanvasSize = UDim2.new(0, 0, 0, math.max(contentY + 16, 0))
            if forceBottom ~= false then
                ChatScroll.CanvasPosition = Vector2.new(0, math.max(0, contentY - ChatScroll.AbsoluteWindowSize.Y + 24))
            end
        end)
    end

    ChatLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        UpdateChatScroll(true)
    end)

    local function ClearChat()
        for _, child in ipairs(ChatScroll:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end
        conversation = {}
        ChatScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        ChatScroll.CanvasPosition = Vector2.new(0, 0)
    end

    local function AddMessage(text, isUser)
        local speaker = isUser and "You" or activePersona.name
        local msgFrame = Instance.new("Frame")
        msgFrame.Size = UDim2.new(1, -10, 0, 0)
        msgFrame.BackgroundTransparency = 1
        msgFrame.AutomaticSize = Enum.AutomaticSize.Y
        msgFrame.LayoutOrder = #ChatScroll:GetChildren() + 1
        msgFrame.Parent = ChatScroll

        local bubble = Instance.new("TextLabel")
        bubble.Size = UDim2.new(0.92, 0, 0, 0)
        bubble.AutomaticSize = Enum.AutomaticSize.Y
        bubble.BackgroundColor3 = isUser and Color3.fromRGB(40, 90, 160) or Color3.fromRGB(50, 35, 60)
        bubble.TextColor3 = Color3.fromRGB(255, 255, 255)
        bubble.TextSize = 13
        bubble.Font = Enum.Font.SourceSans
        bubble.Text = speaker .. ": " .. text
        bubble.TextWrapped = true
        bubble.TextXAlignment = Enum.TextXAlignment.Left
        bubble.TextYAlignment = Enum.TextYAlignment.Top
        bubble.Parent = msgFrame
        Instance.new("UICorner", bubble).CornerRadius = UDim.new(0, 8)
        local pad = Instance.new("UIPadding", bubble)
        pad.PaddingLeft = UDim.new(0, 8)
        pad.PaddingRight = UDim.new(0, 8)
        pad.PaddingTop = UDim.new(0, 6)
        pad.PaddingBottom = UDim.new(0, 6)

        if isUser then
            bubble.Position = UDim2.new(0.08, 0, 0, 0)
        else
            bubble.Position = UDim2.new(0, 0, 0, 0)
        end

        UpdateChatScroll(true)
    end

    local function SwitchPersona(persona)
        activeId = persona.id
        activePersona = persona
        SaveActivePersonaId(activeId)
        TitleText.Text = persona.name .. " AI"
        InputBox.PlaceholderText = "Ask " .. persona.name .. " anything..."
        ClearChat()
        AddMessage("Switched to " .. persona.name .. ". Chat cleared. What's up?", false)
    end

    local function RefreshPersonaPanel()
        for _, child in ipairs(PersonaPanel:GetChildren()) do
            if child:IsA("Frame") or child:IsA("TextButton") or child:IsA("TextLabel") then
                child:Destroy()
            end
        end

        local header = Instance.new("TextLabel")
        header.Size = UDim2.new(1, -10, 0, 28)
        header.BackgroundTransparency = 1
        header.Text = "Personas (tap to switch)"
        header.TextColor3 = Color3.fromRGB(200, 200, 220)
        header.TextSize = 14
        header.Font = Enum.Font.SourceSansBold
        header.TextXAlignment = Enum.TextXAlignment.Left
        header.LayoutOrder = 0
        header.Parent = PersonaPanel

        for i, p in ipairs(personas) do
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, -10, 0, 44)
            row.BackgroundColor3 = (p.id == activeId) and Color3.fromRGB(60, 40, 80) or Color3.fromRGB(35, 35, 45)
            row.LayoutOrder = i
            row.Parent = PersonaPanel
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

            local nameBtn = Instance.new("TextButton")
            nameBtn.Size = UDim2.new(1, p.locked and -10 or -90, 1, 0)
            nameBtn.Position = UDim2.new(0, 8, 0, 0)
            nameBtn.BackgroundTransparency = 1
            nameBtn.Text = p.name .. (p.locked and " 🔒" or "") .. (p.id == activeId and "  ✓" or "")
            nameBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            nameBtn.TextSize = 14
            nameBtn.Font = Enum.Font.SourceSansBold
            nameBtn.TextXAlignment = Enum.TextXAlignment.Left
            nameBtn.Parent = row

            -- Short click = switch; hold 1.5s = copy JSON (custom only — Flowery is locked)
            local holdingPersona = false
            local holdCopied = false
            nameBtn.MouseButton1Down:Connect(function()
                if p.locked then return end
                holdingPersona = true
                holdCopied = false
                local t = 0
                while holdingPersona do
                    task.wait(0.1)
                    t = t + 0.1
                    if t >= 1.5 then
                        holdingPersona = false
                        holdCopied = true
                        local payload = HttpService:JSONEncode({
                            id = p.id,
                            name = p.name,
                            personality = p.personality
                        })
                        if setclipboard then
                            setclipboard(payload)
                            nameBtn.Text = "COPIED!"
                            task.wait(1.2)
                            if nameBtn and nameBtn.Parent then
                                nameBtn.Text = p.name .. (p.id == activeId and "  ✓" or "")
                            end
                        end
                        return
                    end
                end
            end)
            nameBtn.MouseButton1Up:Connect(function()
                if p.locked then
                    if p.id ~= activeId then
                        SwitchPersona(p)
                        RefreshPersonaPanel()
                    end
                    return
                end
                if holdingPersona and not holdCopied then
                    holdingPersona = false
                    if p.id ~= activeId then
                        SwitchPersona(p)
                        RefreshPersonaPanel()
                    end
                end
            end)
            nameBtn.MouseLeave:Connect(function() holdingPersona = false end)

            if not p.locked then
                local delBtn = Instance.new("TextButton")
                delBtn.Size = UDim2.new(0, 70, 0, 30)
                delBtn.Position = UDim2.new(1, -78, 0.5, -15)
                delBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
                delBtn.Text = "Delete"
                delBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                delBtn.TextSize = 12
                delBtn.Font = Enum.Font.SourceSansBold
                delBtn.Parent = row
                Instance.new("UICorner", delBtn).CornerRadius = UDim.new(0, 6)
                delBtn.MouseButton1Click:Connect(function()
                    AnimateButtonPress(delBtn)
                    DeleteCustomPersona(p)
                    for idx, pp in ipairs(personas) do
                        if pp.id == p.id then
                            table.remove(personas, idx)
                            break
                        end
                    end
                    if activeId == p.id then
                        SwitchPersona(personas[1])
                    end
                    RefreshPersonaPanel()
                end)
            end
        end

        local addBtn = Instance.new("TextButton")
        addBtn.Size = UDim2.new(1, -10, 0, 40)
        addBtn.BackgroundColor3 = Color3.fromRGB(45, 140, 90)
        addBtn.Text = "+ Add Persona  (hold = template)"
        addBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        addBtn.TextSize = 14
        addBtn.Font = Enum.Font.SourceSansBold
        addBtn.LayoutOrder = 999
        addBtn.Parent = PersonaPanel
        Instance.new("UICorner", addBtn).CornerRadius = UDim.new(0, 8)

        local function ClearTempForms()
            for _, child in ipairs(PersonaPanel:GetChildren()) do
                if child:IsA("Frame") and (child.LayoutOrder == 998 or child.Name == "PersonaTempForm") then
                    child:Destroy()
                end
            end
        end

        local function OpenNormalForm()
            ClearTempForms()
            local form = Instance.new("Frame")
            form.Name = "PersonaTempForm"
            form.Size = UDim2.new(1, -10, 0, 160)
            form.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
            form.LayoutOrder = 998
            form.Parent = PersonaPanel
            Instance.new("UICorner", form).CornerRadius = UDim.new(0, 8)

            local nameBox = Instance.new("TextBox")
            nameBox.Size = UDim2.new(1, -16, 0, 28)
            nameBox.Position = UDim2.new(0, 8, 0, 8)
            nameBox.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
            nameBox.PlaceholderText = "Persona name"
            nameBox.Text = ""
            nameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
            nameBox.TextSize = 13
            nameBox.Font = Enum.Font.SourceSans
            nameBox.Parent = form
            Instance.new("UICorner", nameBox).CornerRadius = UDim.new(0, 6)

            local persBox = Instance.new("TextBox")
            persBox.Size = UDim2.new(1, -16, 0, 70)
            persBox.Position = UDim2.new(0, 8, 0, 42)
            persBox.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
            persBox.PlaceholderText = "Personality / system prompt..."
            persBox.Text = ""
            persBox.TextColor3 = Color3.fromRGB(255, 255, 255)
            persBox.TextSize = 12
            persBox.Font = Enum.Font.SourceSans
            persBox.TextWrapped = true
            persBox.TextXAlignment = Enum.TextXAlignment.Left
            persBox.TextYAlignment = Enum.TextYAlignment.Top
            persBox.ClearTextOnFocus = false
            persBox.Parent = form
            Instance.new("UICorner", persBox).CornerRadius = UDim.new(0, 6)

            local saveBtn = Instance.new("TextButton")
            saveBtn.Size = UDim2.new(0.45, 0, 0, 28)
            saveBtn.Position = UDim2.new(0.05, 0, 1, -34)
            saveBtn.BackgroundColor3 = Color3.fromRGB(45, 140, 90)
            saveBtn.Text = "Save"
            saveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            saveBtn.TextSize = 13
            saveBtn.Font = Enum.Font.SourceSansBold
            saveBtn.Parent = form
            Instance.new("UICorner", saveBtn).CornerRadius = UDim.new(0, 6)

            local cancelBtn = Instance.new("TextButton")
            cancelBtn.Size = UDim2.new(0.45, 0, 0, 28)
            cancelBtn.Position = UDim2.new(0.5, 0, 1, -34)
            cancelBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
            cancelBtn.Text = "Cancel"
            cancelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            cancelBtn.TextSize = 13
            cancelBtn.Font = Enum.Font.SourceSansBold
            cancelBtn.Parent = form
            Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0, 6)

            saveBtn.MouseButton1Click:Connect(function()
                AnimateButtonPress(saveBtn)
                local n = nameBox.Text:match("^%s*(.-)%s*$")
                local pers = persBox.Text:match("^%s*(.-)%s*$")
                if not n or n == "" then return end
                if not pers or pers == "" then pers = "You are " .. n .. ". Be helpful and stay in character." end
                local newP = {
                    id = GeneratePersonaId(),
                    name = n,
                    personality = pers,
                    locked = false
                }
                SaveCustomPersona(newP)
                table.insert(personas, newP)
                form:Destroy()
                RefreshPersonaPanel()
            end)
            cancelBtn.MouseButton1Click:Connect(function()
                AnimateButtonPress(cancelBtn)
                form:Destroy()
                RefreshPersonaPanel()
            end)
            task.defer(function()
                PersonaPanel.CanvasSize = UDim2.new(0, 0, 0, PersonaLayout.AbsoluteContentSize.Y + 12)
            end)
        end

        local function OpenImportForm()
            ClearTempForms()
            local form = Instance.new("Frame")
            form.Name = "PersonaTempForm"
            form.Size = UDim2.new(1, -10, 0, 160)
            form.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
            form.LayoutOrder = 998
            form.Parent = PersonaPanel
            Instance.new("UICorner", form).CornerRadius = UDim.new(0, 8)

            local jsonBox = Instance.new("TextBox")
            jsonBox.Size = UDim2.new(1, -16, 0, 100)
            jsonBox.Position = UDim2.new(0, 8, 0, 8)
            jsonBox.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
            jsonBox.PlaceholderText = "Paste persona JSON here..."
            jsonBox.Text = ""
            jsonBox.TextColor3 = Color3.fromRGB(255, 255, 255)
            jsonBox.TextSize = 12
            jsonBox.Font = Enum.Font.Code
            jsonBox.TextWrapped = true
            jsonBox.TextXAlignment = Enum.TextXAlignment.Left
            jsonBox.TextYAlignment = Enum.TextYAlignment.Top
            jsonBox.ClearTextOnFocus = false
            jsonBox.MultiLine = true
            jsonBox.Parent = form
            Instance.new("UICorner", jsonBox).CornerRadius = UDim.new(0, 6)

            local importBtn = Instance.new("TextButton")
            importBtn.Size = UDim2.new(0.45, 0, 0, 28)
            importBtn.Position = UDim2.new(0.05, 0, 1, -34)
            importBtn.BackgroundColor3 = Color3.fromRGB(70, 120, 200)
            importBtn.Text = "Import"
            importBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            importBtn.TextSize = 13
            importBtn.Font = Enum.Font.SourceSansBold
            importBtn.Parent = form
            Instance.new("UICorner", importBtn).CornerRadius = UDim.new(0, 6)

            local cancelBtn = Instance.new("TextButton")
            cancelBtn.Size = UDim2.new(0.45, 0, 0, 28)
            cancelBtn.Position = UDim2.new(0.5, 0, 1, -34)
            cancelBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
            cancelBtn.Text = "Cancel"
            cancelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            cancelBtn.TextSize = 13
            cancelBtn.Font = Enum.Font.SourceSansBold
            cancelBtn.Parent = form
            Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0, 6)

            importBtn.MouseButton1Click:Connect(function()
                AnimateButtonPress(importBtn)
                local raw = jsonBox.Text:match("^%s*(.-)%s*$")
                if not raw or raw == "" then return end
                local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
                if not ok or type(data) ~= "table" or not data.name or not data.personality then
                    importBtn.Text = "Invalid JSON"
                    task.wait(1.2)
                    if importBtn and importBtn.Parent then importBtn.Text = "Import" end
                    return
                end
                local newP = {
                    id = (data.id and data.id ~= "flowery") and data.id or GeneratePersonaId(),
                    name = data.name,
                    personality = data.personality,
                    locked = false
                }
                SaveCustomPersona(newP)
                table.insert(personas, newP)
                form:Destroy()
                RefreshPersonaPanel()
            end)
            cancelBtn.MouseButton1Click:Connect(function()
                AnimateButtonPress(cancelBtn)
                form:Destroy()
                RefreshPersonaPanel()
            end)
            task.defer(function()
                PersonaPanel.CanvasSize = UDim2.new(0, 0, 0, PersonaLayout.AbsoluteContentSize.Y + 12)
            end)
        end

        local isHoldingAdd = false
        local addDidTemplate = false
        addBtn.MouseButton1Down:Connect(function()
            isHoldingAdd = true
            addDidTemplate = false
            local t = 0
            while isHoldingAdd do
                task.wait(0.1)
                t = t + 0.1
                if t >= 1.5 then
                    isHoldingAdd = false
                    addDidTemplate = true
                    local template = [[{
  "id": "my_persona_id",
  "name": "My Persona Name",
  "personality": "You are My Persona. Describe their personality, speech style, knowledge, and rules here. Stay in character."
}]]
                    if setclipboard then
                        setclipboard(template)
                        addBtn.Text = "TEMPLATE COPIED!"
                        addBtn.BackgroundColor3 = Color3.fromRGB(35, 185, 105)
                        task.wait(1.8)
                        if addBtn and addBtn.Parent then
                            addBtn.Text = "+ Add Persona  (hold = template)"
                            addBtn.BackgroundColor3 = Color3.fromRGB(45, 140, 90)
                        end
                    end
                    return
                end
            end
        end)
        addBtn.MouseLeave:Connect(function() isHoldingAdd = false end)
        addBtn.MouseButton1Up:Connect(function()
            if not isHoldingAdd and addDidTemplate then return end
            if isHoldingAdd and not addDidTemplate then
                isHoldingAdd = false
                AnimateButtonPress(addBtn)
                ClearTempForms()

                local choice = Instance.new("Frame")
                choice.Name = "PersonaTempForm"
                choice.Size = UDim2.new(1, -10, 0, 50)
                choice.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
                choice.LayoutOrder = 998
                choice.Parent = PersonaPanel
                Instance.new("UICorner", choice).CornerRadius = UDim.new(0, 8)

                local normalBtn = Instance.new("TextButton")
                normalBtn.Size = UDim2.new(0.45, 0, 0, 34)
                normalBtn.Position = UDim2.new(0.03, 0, 0.5, -17)
                normalBtn.BackgroundColor3 = Color3.fromRGB(45, 140, 90)
                normalBtn.Text = "NORMAL"
                normalBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                normalBtn.TextSize = 14
                normalBtn.Font = Enum.Font.SourceSansBold
                normalBtn.Parent = choice
            Instance.new("UICorner", normalBtn).CornerRadius = UDim.new(0, 6)

            local importBtn = Instance.new("TextButton")
            importBtn.Size = UDim2.new(0.45, 0, 0, 34)
            importBtn.Position = UDim2.new(0.52, 0, 0.5, -17)
            importBtn.BackgroundColor3 = Color3.fromRGB(70, 120, 200)
            importBtn.Text = "IMPORT"
            importBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            importBtn.TextSize = 14
            importBtn.Font = Enum.Font.SourceSansBold
            importBtn.Parent = choice
            Instance.new("UICorner", importBtn).CornerRadius = UDim.new(0, 6)

            normalBtn.MouseButton1Click:Connect(function()
                AnimateButtonPress(normalBtn)
                ClearTempForms()
                OpenNormalForm()
            end)
            importBtn.MouseButton1Click:Connect(function()
                AnimateButtonPress(importBtn)
                ClearTempForms()
                OpenImportForm()
            end)

            task.defer(function()
                PersonaPanel.CanvasSize = UDim2.new(0, 0, 0, PersonaLayout.AbsoluteContentSize.Y + 12)
            end)
        end)

        task.defer(function()
            PersonaPanel.CanvasSize = UDim2.new(0, 0, 0, PersonaLayout.AbsoluteContentSize.Y + 12)
        end)
    end

    -- Welcome
    AddMessage("Howdy! I'm " .. activePersona.name .. ". Ask me anything about the music player... or just chat.", false)

    local function SendMessage()
        if isWaiting or showingPersonas then return end
        local text = InputBox.Text:match("^%s*(.-)%s*$")
        if not text or text == "" then return end

        InputBox.Text = ""
        AddMessage(text, true)
        table.insert(conversation, {role = "user", content = text})

        isWaiting = true
        SendBtn.Text = "..."
        SendBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 90)

        task.spawn(function()
            local historyForApi = {}
            for i = 1, #conversation - 1 do
                table.insert(historyForApi, conversation[i])
            end
            local reply, err = AskFlowery(text, historyForApi, activePersona.personality)
            isWaiting = false
            SendBtn.Text = "Send"
            SendBtn.BackgroundColor3 = Color3.fromRGB(180, 70, 160)

            if reply then
                AddMessage(reply, false)
                table.insert(conversation, {role = "assistant", content = reply})
            else
                AddMessage("Something went wrong: " .. (err or "unknown error"), false)
            end
        end)
    end

    SendBtn.MouseButton1Click:Connect(SendMessage)
    InputBox.FocusLost:Connect(function(enter)
        if enter then SendMessage() end
    end)

    SettingsAiBtn.MouseButton1Click:Connect(function()
        showingPersonas = not showingPersonas
        PersonaPanel.Visible = showingPersonas
        ChatScroll.Visible = not showingPersonas
        InputBox.Visible = not showingPersonas
        SendBtn.Visible = not showingPersonas
        if showingPersonas then
            RefreshPersonaPanel()
            SettingsAiBtn.Text = "←"
        else
            SettingsAiBtn.Text = "⚙"
        end
    end)

    CloseAiBtn.MouseButton1Click:Connect(function()
        FadeUIWindow(AiFrame, false)
        task.wait(0.35)
        if AiFrame and AiFrame.Parent then AiFrame:Destroy() end
        if onClose then onClose() end
    end)

    -- Draggable
    local dragging, dragInput, dragStart, startPos
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = AiFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    TitleBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            AiFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    FadeUIWindow(AiFrame, true, 0.45, Enum.EasingStyle.Back)
    return AiFrame
end

local function CreateMainInterface(ScreenGui)
    local PeakFlashOverlay = Instance.new("Frame")
    PeakFlashOverlay.Size = UDim2.new(1, 0, 1, 0) PeakFlashOverlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    PeakFlashOverlay.BackgroundTransparency = 1 PeakFlashOverlay.BorderSizePixel = 0 PeakFlashOverlay.ZIndex = 999998 PeakFlashOverlay.Parent = ScreenGui

    local PromptFrame = Instance.new("Frame")
    PromptFrame.Size = UDim2.new(0, 360, 0, 220) PromptFrame.Position = UDim2.new(0.5, -180, 0.5, -110)
    PromptFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30) PromptFrame.BorderSizePixel = 0 PromptFrame.ClipsDescendants = true
    PromptFrame:SetAttribute("TargetSize", UDim2.new(0, 360, 0, 220)) PromptFrame.Parent = ScreenGui
    Instance.new("UICorner", PromptFrame).CornerRadius = UDim.new(0, 12) ApplyDecibelChroma(PromptFrame)

    local WatermarkPrompt = Instance.new("TextLabel")
    WatermarkPrompt.Size = UDim2.new(1, -12, 0, 20) WatermarkPrompt.Position = UDim2.new(0, 6, 1, -22) WatermarkPrompt.BackgroundTransparency = 1
    WatermarkPrompt.Text = "by langarsch on discord:)" WatermarkPrompt.TextColor3 = Color3.fromRGB(200, 200, 220) WatermarkPrompt.TextSize = 12 WatermarkPrompt.Font = Enum.Font.SourceSansItalic WatermarkPrompt.TextXAlignment = Enum.TextXAlignment.Right WatermarkPrompt.Parent = PromptFrame

    local ConfigGearBtn = Instance.new("TextButton")
    ConfigGearBtn.Size = UDim2.new(0, 25, 0, 25) ConfigGearBtn.Position = UDim2.new(0, 10, 0, 10) ConfigGearBtn.BackgroundTransparency = 1
    ConfigGearBtn.Text = "⚙" ConfigGearBtn.TextColor3 = Color3.fromRGB(240, 240, 240) ConfigGearBtn.TextSize = 20 ConfigGearBtn.Font = Enum.Font.SourceSansBold ConfigGearBtn.Parent = PromptFrame

    local UtilityBtn = Instance.new("TextButton")
    UtilityBtn.Size = UDim2.new(0, 25, 0, 25)
    UtilityBtn.Position = UDim2.new(0, 10, 0, 38)
    UtilityBtn.BackgroundTransparency = 1
    UtilityBtn.Text = "🛠"
    UtilityBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
    UtilityBtn.TextSize = 18
    UtilityBtn.Font = Enum.Font.SourceSansBold
    UtilityBtn.Parent = PromptFrame

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 55) Title.Text = "Do you want to use Roblox music IDs or your own?" Title.TextColor3 = Color3.fromRGB(255, 255, 255) Title.TextSize = 16 Title.Font = Enum.Font.SourceSansSemibold Title.BackgroundTransparency = 1 Title.TextWrapped = true Title.Parent = PromptFrame

    local MainButtonsFrame = Instance.new("Frame")
    MainButtonsFrame.Size = UDim2.new(1, 0, 1, -55) MainButtonsFrame.Position = UDim2.new(0, 0, 0, 55)
    MainButtonsFrame.BackgroundTransparency = 1 MainButtonsFrame.Parent = PromptFrame

    local RbxBtn = Instance.new("TextButton")
    RbxBtn.Size = UDim2.new(0, 145, 0, 46) RbxBtn.Position = UDim2.new(0, 25, 0, 20) RbxBtn.BackgroundColor3 = Color3.fromRGB(15, 125, 235) RbxBtn.Text = "RBX MUSIC" RbxBtn.TextColor3 = Color3.fromRGB(255, 255, 255) RbxBtn.Font = Enum.Font.SourceSansBold RbxBtn.TextSize = 16 RbxBtn.Parent = MainButtonsFrame
    Instance.new("UICorner", RbxBtn).CornerRadius = UDim.new(0, 8)

    local OwnBtn = Instance.new("TextButton")
    OwnBtn.Size = UDim2.new(0, 145, 0, 46) OwnBtn.Position = UDim2.new(1, -170, 0, 20) OwnBtn.BackgroundColor3 = Color3.fromRGB(35, 185, 105) OwnBtn.Text = "OWN MUSIC" OwnBtn.TextColor3 = Color3.fromRGB(255, 255, 255) OwnBtn.Font = Enum.Font.SourceSansBold OwnBtn.TextSize = 16 OwnBtn.Parent = MainButtonsFrame
    Instance.new("UICorner", OwnBtn).CornerRadius = UDim.new(0, 8)

    local BuiltInBtn = Instance.new("TextButton")
    BuiltInBtn.Size = UDim2.new(0, 145, 0, 46) BuiltInBtn.Position = UDim2.new(0, 25, 0, 20) BuiltInBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 210) BuiltInBtn.Text = "BUILT IN" BuiltInBtn.TextColor3 = Color3.fromRGB(255, 255, 255) BuiltInBtn.Font = Enum.Font.SourceSansBold BuiltInBtn.TextSize = 16 BuiltInBtn.Visible = false BuiltInBtn.Parent = MainButtonsFrame
    Instance.new("UICorner", BuiltInBtn).CornerRadius = UDim.new(0, 8)

    local CustomBtn = Instance.new("TextButton")
    CustomBtn.Size = UDim2.new(0, 145, 0, 46) CustomBtn.Position = UDim2.new(1, -170, 0, 20) CustomBtn.BackgroundColor3 = Color3.fromRGB(225, 100, 15) CustomBtn.Text = "CUSTOM" CustomBtn.TextColor3 = Color3.fromRGB(255, 255, 255) CustomBtn.Font = Enum.Font.SourceSansBold CustomBtn.TextSize = 16 CustomBtn.Visible = false CustomBtn.Parent = MainButtonsFrame
    Instance.new("UICorner", CustomBtn).CornerRadius = UDim.new(0, 8)

    local TutorialBtn = Instance.new("TextButton")
    TutorialBtn.Size = UDim2.new(1, -50, 0, 42) TutorialBtn.Position = UDim2.new(0, 25, 0, 85) TutorialBtn.BackgroundColor3 = Color3.fromRGB(140, 75, 195) TutorialBtn.Text = "TUTORIAL" TutorialBtn.TextColor3 = Color3.fromRGB(255, 255, 255) TutorialBtn.Font = Enum.Font.SourceSansBold TutorialBtn.TextSize = 15 TutorialBtn.Parent = MainButtonsFrame
    Instance.new("UICorner", TutorialBtn).CornerRadius = UDim.new(0, 8)

    -- Scrollable Settings Frame
    local SettingsScroll = Instance.new("ScrollingFrame")
    SettingsScroll.Size = UDim2.new(1, -20, 1, -85) SettingsScroll.Position = UDim2.new(0, 10, 0, 55)
    SettingsScroll.BackgroundTransparency = 1 SettingsScroll.BorderSizePixel = 0 SettingsScroll.CanvasSize = UDim2.new(0, 0, 0, 400)
    SettingsScroll.ScrollBarThickness = 4 SettingsScroll.Visible = false SettingsScroll.Parent = PromptFrame

    local SettingsLayout = Instance.new("UIListLayout")
    SettingsLayout.Parent = SettingsScroll SettingsLayout.SortOrder = Enum.SortOrder.LayoutOrder SettingsLayout.Padding = UDim.new(0, 8)

    local UtilityScroll = Instance.new("ScrollingFrame")
    UtilityScroll.Size = UDim2.new(1, -20, 1, -85)
    UtilityScroll.Position = UDim2.new(0, 10, 0, 55)
    UtilityScroll.BackgroundTransparency = 1
    UtilityScroll.BorderSizePixel = 0
    UtilityScroll.CanvasSize = UDim2.new(0, 0, 0, 175)
    UtilityScroll.ScrollBarThickness = 4
    UtilityScroll.Visible = false
    UtilityScroll.Parent = PromptFrame

    local UtilityLayout = Instance.new("UIListLayout")
    UtilityLayout.Parent = UtilityScroll
    UtilityLayout.SortOrder = Enum.SortOrder.LayoutOrder
    UtilityLayout.Padding = UDim.new(0, 8)

    local RemoveUIBtn = Instance.new("TextButton")
    RemoveUIBtn.Size = UDim2.new(1, -10, 0, 46)
    RemoveUIBtn.BackgroundColor3 = Color3.fromRGB(235, 75, 75)
    RemoveUIBtn.Text = "REMOVE UI FROM GUI"
    RemoveUIBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    RemoveUIBtn.Font = Enum.Font.SourceSansBold
    RemoveUIBtn.TextSize = 15
    RemoveUIBtn.LayoutOrder = 1
    RemoveUIBtn.Parent = UtilityScroll
    Instance.new("UICorner", RemoveUIBtn).CornerRadius = UDim.new(0, 8)

    local CopyCreditsBtn = Instance.new("TextButton")
    CopyCreditsBtn.Size = UDim2.new(1, -10, 0, 46)
    CopyCreditsBtn.BackgroundColor3 = Color3.fromRGB(140, 75, 195)
    CopyCreditsBtn.Text = "COPY CREDITS TO CLIPBOARD"
    CopyCreditsBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CopyCreditsBtn.Font = Enum.Font.SourceSansBold
    CopyCreditsBtn.TextSize = 15
    CopyCreditsBtn.LayoutOrder = 2
    CopyCreditsBtn.Parent = UtilityScroll
    Instance.new("UICorner", CopyCreditsBtn).CornerRadius = UDim.new(0, 8)

    local OpenWelcomeBtn = Instance.new("TextButton")
    OpenWelcomeBtn.Size = UDim2.new(1, -10, 0, 46)
    OpenWelcomeBtn.BackgroundColor3 = Color3.fromRGB(15, 125, 235)
    OpenWelcomeBtn.Text = "OPEN WELCOME UI"
    OpenWelcomeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    OpenWelcomeBtn.Font = Enum.Font.SourceSansBold
    OpenWelcomeBtn.TextSize = 15
    OpenWelcomeBtn.LayoutOrder = 3
    OpenWelcomeBtn.Parent = UtilityScroll
    Instance.new("UICorner", OpenWelcomeBtn).CornerRadius = UDim.new(0, 8)

    local GameMuteToggleBtn = Instance.new("TextButton")
    GameMuteToggleBtn.Size = UDim2.new(1, -10, 0, 46) GameMuteToggleBtn.BackgroundColor3 = Color3.fromRGB(235, 75, 75) GameMuteToggleBtn.Text = "MUTE GAME MUSIC: OFF" GameMuteToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255) GameMuteToggleBtn.Font = Enum.Font.SourceSansBold GameMuteToggleBtn.TextSize = 15 GameMuteToggleBtn.LayoutOrder = 1 GameMuteToggleBtn.Parent = SettingsScroll
    Instance.new("UICorner", GameMuteToggleBtn).CornerRadius = UDim.new(0, 8)

    local FlashToggleBtn = Instance.new("TextButton")
    FlashToggleBtn.Size = UDim2.new(1, -10, 0, 46) FlashToggleBtn.BackgroundColor3 = Color3.fromRGB(45, 185, 105) FlashToggleBtn.Text = "BEAT OVERLAY FLASH: ON" FlashToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255) FlashToggleBtn.Font = Enum.Font.SourceSansBold FlashToggleBtn.TextSize = 15 FlashToggleBtn.LayoutOrder = 2 FlashToggleBtn.Parent = SettingsScroll
    Instance.new("UICorner", FlashToggleBtn).CornerRadius = UDim.new(0, 8)

    local StatToggleBtn = Instance.new("TextButton")
    StatToggleBtn.Size = UDim2.new(1, -10, 0, 46) StatToggleBtn.BackgroundColor3 = Color3.fromRGB(235, 75, 75) StatToggleBtn.Text = "SYSTEM STATS HUD: OFF" StatToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255) StatToggleBtn.Font = Enum.Font.SourceSansBold StatToggleBtn.TextSize = 15 StatToggleBtn.LayoutOrder = 3 StatToggleBtn.Parent = SettingsScroll
    Instance.new("UICorner", StatToggleBtn).CornerRadius = UDim.new(0, 8)

    -- Toggle Welcome UI setting inside settings menu
    local WelcomeToggleBtn = Instance.new("TextButton")
    WelcomeToggleBtn.Size = UDim2.new(1, -10, 0, 46) WelcomeToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255) WelcomeToggleBtn.Font = Enum.Font.SourceSansBold WelcomeToggleBtn.TextSize = 15 WelcomeToggleBtn.LayoutOrder = 4 WelcomeToggleBtn.Parent = SettingsScroll
    Instance.new("UICorner", WelcomeToggleBtn).CornerRadius = UDim.new(0, 8)

    local function RefreshWelcomeToggleUI()
        local showWelcome = GetWelcomeSetting()
        WelcomeToggleBtn.Text = showWelcome and "SHOW WELCOME SCREEN: ON" or "SHOW WELCOME SCREEN: OFF"
        WelcomeToggleBtn.BackgroundColor3 = showWelcome and Color3.fromRGB(45, 185, 105) or Color3.fromRGB(235, 75, 75)
    end
    RefreshWelcomeToggleUI()

    WelcomeToggleBtn.MouseButton1Click:Connect(function()
        local newState = not GetWelcomeSetting()
        SaveDataSettings({
            WT = newState,
            MUTE = GetDataSetting("MUTE", false),
            FLASH = GetDataSetting("FLASH", true),
            STATS = GetDataSetting("STATS", false),
            RGB = GetDataSetting("RGB", true),
            FULLRGB = GetDataSetting("FULLRGB", false),
            PEPPINO = GetDataSetting("PEPPINO", true),
        })
        RefreshWelcomeToggleUI()
    end)

    -- RGB Chroma toggles
    local RgbToggleBtn = Instance.new("TextButton")
    RgbToggleBtn.Size = UDim2.new(1, -10, 0, 46)
    RgbToggleBtn.BackgroundColor3 = Color3.fromRGB(45, 185, 105)
    RgbToggleBtn.Text = "RGB EFFECT: ON"
    RgbToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    RgbToggleBtn.Font = Enum.Font.SourceSansBold
    RgbToggleBtn.TextSize = 15
    RgbToggleBtn.LayoutOrder = 5
    RgbToggleBtn.Parent = SettingsScroll
    Instance.new("UICorner", RgbToggleBtn).CornerRadius = UDim.new(0, 8)

    local FullRgbToggleBtn = Instance.new("TextButton")
    FullRgbToggleBtn.Size = UDim2.new(1, -10, 0, 46)
    FullRgbToggleBtn.BackgroundColor3 = Color3.fromRGB(235, 75, 75)
    FullRgbToggleBtn.Text = "FULL RGB (NO DARK HUE): OFF"
    FullRgbToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    FullRgbToggleBtn.Font = Enum.Font.SourceSansBold
    FullRgbToggleBtn.TextSize = 15
    FullRgbToggleBtn.LayoutOrder = 6
    FullRgbToggleBtn.Parent = SettingsScroll
    Instance.new("UICorner", FullRgbToggleBtn).CornerRadius = UDim.new(0, 8)

    local PeppinoToggleBtn = Instance.new("TextButton")
    PeppinoToggleBtn.Size = UDim2.new(1, -10, 0, 46)
    PeppinoToggleBtn.BackgroundColor3 = Color3.fromRGB(45, 185, 105)
    PeppinoToggleBtn.Text = "PEPPINO CORNER: ON"
    PeppinoToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    PeppinoToggleBtn.Font = Enum.Font.SourceSansBold
    PeppinoToggleBtn.TextSize = 15
    PeppinoToggleBtn.LayoutOrder = 7
    PeppinoToggleBtn.Parent = SettingsScroll
    Instance.new("UICorner", PeppinoToggleBtn).CornerRadius = UDim.new(0, 8)

    return PromptFrame, ConfigGearBtn, UtilityBtn, MainButtonsFrame, SettingsScroll, UtilityScroll, RbxBtn, OwnBtn, BuiltInBtn, CustomBtn, TutorialBtn, Title, GameMuteToggleBtn, FlashToggleBtn, StatToggleBtn, PeakFlashOverlay, RefreshWelcomeToggleUI, RemoveUIBtn, CopyCreditsBtn, OpenWelcomeBtn, RgbToggleBtn, FullRgbToggleBtn, PeppinoToggleBtn
end

local function CreateUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "LangaMusicHubUltimate"
    ScreenGui.ResetOnSpawn = false ScreenGui.Parent = CoreGui

    local PromptFrame, ConfigGearBtn, UtilityBtn, MainButtonsFrame, SettingsScroll, UtilityScroll, RbxBtn, OwnBtn, BuiltInBtn, CustomBtn, TutorialBtn, Title, GameMuteToggleBtn, FlashToggleBtn, StatToggleBtn, PeakFlashOverlay, RefreshWelcomeToggleUI, RemoveUIBtn, CopyCreditsBtn, OpenWelcomeBtn, RgbToggleBtn, FullRgbToggleBtn, PeppinoToggleBtn = CreateMainInterface(ScreenGui)

    local PersistentSettings = LoadPersistentSettings()
    AudioPlayer.IsGameMuted = PersistentSettings.MUTE
    AudioPlayer.IsFlashEnabled = PersistentSettings.FLASH
    AudioPlayer.IsChromaEnabled = PersistentSettings.RGB
    AudioPlayer.IsFullChroma = PersistentSettings.FULLRGB

    local MainHub = Instance.new("Frame")
    MainHub.Size = UDim2.new(0, 330, 0, 240) MainHub.Position = UDim2.new(0.5, -165, 0.5, -120) MainHub.BackgroundColor3 = Color3.fromRGB(20, 20, 25) MainHub.BorderSizePixel = 0 MainHub.Visible = false MainHub.ClipsDescendants = false MainHub:SetAttribute("TargetSize", UDim2.new(0, 330, 0, 240)) MainHub.Parent = ScreenGui
    Instance.new("UICorner", MainHub).CornerRadius = UDim.new(0, 12) ApplyDecibelChroma(MainHub)

    local SystemStatsBar = Instance.new("Frame")
    SystemStatsBar.Size = UDim2.new(1, -40, 0, 22) SystemStatsBar.Position = UDim2.new(0, 20, 0, -28) SystemStatsBar.BackgroundColor3 = Color3.fromRGB(15, 15, 18) SystemStatsBar.BackgroundTransparency = 0.2 SystemStatsBar.Visible = false SystemStatsBar.Parent = MainHub
    Instance.new("UICorner", SystemStatsBar).CornerRadius = UDim.new(0, 6)

    SystemStatsBar.Visible = PersistentSettings.STATS

    local StatsLabel = Instance.new("TextLabel")
    StatsLabel.Size = UDim2.new(1, -12, 1, 0) StatsLabel.Position = UDim2.new(0, 6, 0, 0) StatsLabel.BackgroundTransparency = 1 StatsLabel.Text = "00:00:00  |  00 FPS  |  0 ms" StatsLabel.TextColor3 = Color3.fromRGB(235, 235, 240) StatsLabel.TextSize = 11 StatsLabel.Font = Enum.Font.Code StatsLabel.TextXAlignment = Enum.TextXAlignment.Center StatsLabel.Parent = SystemStatsBar

    -- Working FPS / Network Ping Counter
    task.spawn(function()
        local frameCount = 0
        local lastStatUpdate = os.clock()
        local currentFps = 60

        RunService.RenderStepped:Connect(function()
            frameCount = frameCount + 1
            local now = os.clock()
            if now - lastStatUpdate >= 0.5 then
                currentFps = math.round(frameCount / (now - lastStatUpdate))
                frameCount = 0
                lastStatUpdate = now
            end
            if SystemStatsBar.Visible then
                local timeStr = os.date("%I:%M:%S %p")
                local pingVal = 0
                pcall(function() pingVal = math.round(Stats.PerformanceStats.Ping:GetValue()) end)
                StatsLabel.Text = timeStr .. "  |  " .. currentFps .. " FPS  |  " .. pingVal .. " ms"
            end
        end)
    end)

    local WatermarkHub = Instance.new("TextLabel")
    WatermarkHub.Size = UDim2.new(1, -10, 0, 20) WatermarkHub.Position = UDim2.new(0, 5, 1, -22) WatermarkHub.BackgroundTransparency = 1 WatermarkHub.Text = "by langarsch on discord:)" WatermarkHub.TextColor3 = Color3.fromRGB(200, 200, 220) WatermarkHub.TextSize = 12 WatermarkHub.Font = Enum.Font.SourceSansItalic WatermarkHub.TextXAlignment = Enum.TextXAlignment.Right WatermarkHub.Parent = MainHub

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 25, 0, 25) CloseBtn.Position = UDim2.new(1, -32, 0, 8) CloseBtn.BackgroundTransparency = 1 CloseBtn.Text = "X" CloseBtn.TextColor3 = Color3.fromRGB(240, 70, 70) CloseBtn.TextSize = 18 CloseBtn.Font = Enum.Font.SourceSansBold CloseBtn.Parent = MainHub

    local DrawerToggleBtn = Instance.new("TextButton")
    DrawerToggleBtn.Size = UDim2.new(0, 25, 0, 25) DrawerToggleBtn.Position = UDim2.new(0, 10, 0, 8) DrawerToggleBtn.BackgroundTransparency = 1 DrawerToggleBtn.Text = "🔊" DrawerToggleBtn.TextColor3 = Color3.fromRGB(240, 240, 240) DrawerToggleBtn.TextSize = 16 DrawerToggleBtn.Font = Enum.Font.SourceSansBold DrawerToggleBtn.Parent = MainHub

    local SpinningDisc = Instance.new("ImageLabel")
    SpinningDisc.Size = UDim2.new(0, 65, 0, 65) SpinningDisc.Position = UDim2.new(0.5, -32, 0, 25) SpinningDisc.BackgroundTransparency = 1 SpinningDisc.Image = DISC_ASSET_ID SpinningDisc.Parent = MainHub

    local SongDisplay = Instance.new("TextLabel")
    SongDisplay.Size = UDim2.new(1, -20, 0, 35) SongDisplay.Position = UDim2.new(0, 10, 0, 95) SongDisplay.BackgroundTransparency = 1 SongDisplay.Text = "Waiting..." SongDisplay.TextColor3 = Color3.fromRGB(255, 255, 255) SongDisplay.TextSize = 15 SongDisplay.Font = Enum.Font.SourceSansSemibold SongDisplay.TextWrapped = true SongDisplay.Parent = MainHub

    local ControlsFrame = Instance.new("Frame")
    ControlsFrame.Size = UDim2.new(1, 0, 0, 50) ControlsFrame.Position = UDim2.new(0, 0, 1, -85) ControlsFrame.BackgroundTransparency = 1 ControlsFrame.Parent = MainHub

    local BackBtn = Instance.new("TextButton")
    BackBtn.Size = UDim2.new(0, 65, 0, 42) BackBtn.Position = UDim2.new(0.5, -105, 0, 0) BackBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 48) BackBtn.Text = "<<" BackBtn.TextColor3 = Color3.fromRGB(220, 220, 225) BackBtn.Font = Enum.Font.SourceSansBold BackBtn.TextSize = 18 BackBtn.Parent = ControlsFrame
    Instance.new("UICorner", BackBtn).CornerRadius = UDim.new(0, 8)

    local PauseBtn = Instance.new("TextButton")
    PauseBtn.Size = UDim2.new(0, 75, 0, 42) PauseBtn.Position = UDim2.new(0.5, -37, 0, 0) PauseBtn.BackgroundColor3 = Color3.fromRGB(15, 125, 235) PauseBtn.Text = "PAUSE" PauseBtn.TextColor3 = Color3.fromRGB(255, 255, 255) PauseBtn.Font = Enum.Font.SourceSansBold PauseBtn.TextSize = 15 PauseBtn.Parent = ControlsFrame
    Instance.new("UICorner", PauseBtn).CornerRadius = UDim.new(0, 8)

    local SkipBtn = Instance.new("TextButton")
    SkipBtn.Size = UDim2.new(0, 65, 0, 42) SkipBtn.Position = UDim2.new(0.5, 42, 0, 0) SkipBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 48) SkipBtn.Text = ">>" SkipBtn.TextColor3 = Color3.fromRGB(220, 220, 225) SkipBtn.Font = Enum.Font.SourceSansBold SkipBtn.TextSize = 18 SkipBtn.Parent = ControlsFrame
    Instance.new("UICorner", SkipBtn).CornerRadius = UDim.new(0, 8)

    local SideDrawer = Instance.new("Frame")
    SideDrawer.Size = UDim2.new(0, 0, 1, 0) SideDrawer.Position = UDim2.new(1, 0, 0, 0) SideDrawer.BackgroundColor3 = Color3.fromRGB(30, 30, 38) SideDrawer.BorderSizePixel = 0 SideDrawer.ClipsDescendants = true SideDrawer.ZIndex = 0 SideDrawer.Parent = MainHub
    Instance.new("UICorner", SideDrawer).CornerRadius = UDim.new(0, 12) ApplyDecibelChroma(SideDrawer)

    local VolUpBtn = Instance.new("TextButton")
    VolUpBtn.Size = UDim2.new(0, 50, 0, 35) VolUpBtn.Position = UDim2.new(0, 17, 0, 15) VolUpBtn.BackgroundColor3 = Color3.fromRGB(45, 185, 105) VolUpBtn.Text = "+" VolUpBtn.TextColor3 = Color3.fromRGB(255, 255, 255) VolUpBtn.Font = Enum.Font.SourceSansBold VolUpBtn.TextSize = 18 VolUpBtn.Parent = SideDrawer
    Instance.new("UICorner", VolUpBtn).CornerRadius = UDim.new(0, 6)

    local VolDisplay = Instance.new("TextLabel")
    VolDisplay.Size = UDim2.new(0, 85, 0, 25) VolDisplay.Position = UDim2.new(0, 0, 0, 55) VolDisplay.BackgroundTransparency = 1 VolDisplay.Text = "50%" VolDisplay.TextColor3 = Color3.fromRGB(255, 255, 255) VolDisplay.TextSize = 14 VolDisplay.Font = Enum.Font.SourceSansBold VolDisplay.Parent = SideDrawer

    local VolDnBtn = Instance.new("TextButton")
    VolDnBtn.Size = UDim2.new(0, 50, 0, 35) VolDnBtn.Position = UDim2.new(0, 17, 0, 85) VolDnBtn.BackgroundColor3 = Color3.fromRGB(235, 75, 75) VolDnBtn.Text = "-" VolDnBtn.TextColor3 = Color3.fromRGB(255, 255, 255) VolDnBtn.Font = Enum.Font.SourceSansBold VolDnBtn.TextSize = 18 VolDnBtn.Parent = SideDrawer
    Instance.new("UICorner", VolDnBtn).CornerRadius = UDim.new(0, 6)

    local ShuffleBtn = Instance.new("TextButton")
    ShuffleBtn.Size = UDim2.new(0, 70, 0, 40) ShuffleBtn.Position = UDim2.new(0, 7, 0, 140) ShuffleBtn.BackgroundColor3 = Color3.fromRGB(230, 140, 15) ShuffleBtn.Text = "🔀 SHUFFLE" ShuffleBtn.TextColor3 = Color3.fromRGB(255, 255, 255) ShuffleBtn.Font = Enum.Font.SourceSansBold ShuffleBtn.TextSize = 11 ShuffleBtn.Parent = SideDrawer
    Instance.new("UICorner", ShuffleBtn).CornerRadius = UDim.new(0, 6)

    local FloatingBubble = Instance.new("TextButton")
    FloatingBubble.Size = UDim2.new(0, 52, 0, 52) FloatingBubble.Position = UDim2.new(0, 25, 0.5, -26) FloatingBubble.BackgroundColor3 = Color3.fromRGB(15, 125, 235) FloatingBubble.Text = "♫" FloatingBubble.TextColor3 = Color3.fromRGB(255, 255, 255) FloatingBubble.TextSize = 25 FloatingBubble.Font = Enum.Font.SourceSansBold FloatingBubble.Visible = false FloatingBubble.Parent = ScreenGui
    Instance.new("UICorner", FloatingBubble).CornerRadius = UDim.new(1, 0)

    local function MakeDraggableCompact(g, c) local d, i, s, p g.InputBegan:Connect(function(x) if x.UserInputType == Enum.UserInputType.MouseButton1 or x.UserInputType == Enum.UserInputType.Touch then d = true s = x.Position p = g.Position if c then c() end x.Changed:Connect(function() if x.UserInputState == Enum.UserInputState.End then d = false end end) end end) g.InputChanged:Connect(function(x) if x.UserInputType == Enum.UserInputType.MouseMovement or x.UserInputType == Enum.UserInputType.Touch then i = x end end) UserInputService.InputChanged:Connect(function(x) if x == i and d then local delta = x.Position - s g.Position = UDim2.new(p.X.Scale, p.X.Offset + delta.X, p.Y.Scale, p.Y.Offset + delta.Y) if c then c() end end end) end
    
    AudioPlayer:Initialize(SpinningDisc, PeakFlashOverlay)
    local lastInteraction = os.clock() local isFaded = false local function ResetIdleTimer() lastInteraction = os.clock() if isFaded then isFaded = false TweenService:Create(FloatingBubble, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {BackgroundTransparency = 0}):Play() end end
    task.spawn(function() while true do task.wait(0.5) if FloatingBubble.Visible and not isFaded and (os.clock() - lastInteraction >= 5) then isFaded = true TweenService:Create(FloatingBubble, TweenInfo.new(1.5, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.85}):Play() end end end)
    
    MakeDraggableCompact(MainHub, nil)
    MakeDraggableCompact(FloatingBubble, ResetIdleTimer)

    AudioPlayer.OnTrackChanged = function(t)
        SongDisplay.Text = t
        if #AudioPlayer.Playlist <= 1 then
            SkipBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 33) SkipBtn.TextColor3 = Color3.fromRGB(75, 75, 85)
            BackBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 33) BackBtn.TextColor3 = Color3.fromRGB(75, 75, 85)
            ShuffleBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 33) ShuffleBtn.TextColor3 = Color3.fromRGB(75, 75, 85)
        else
            SkipBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 48) SkipBtn.TextColor3 = Color3.fromRGB(220, 220, 225)
            BackBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 48) BackBtn.TextColor3 = Color3.fromRGB(220, 220, 225)
            ShuffleBtn.BackgroundColor3 = Color3.fromRGB(230, 140, 15) ShuffleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
    end

    ShuffleBtn.MouseButton1Click:Connect(function()
        if #AudioPlayer.Playlist <= 1 then return end
        AudioPlayer:ShufflePlaylist()
        ShuffleBtn.Text = "SHUFFLED!" ShuffleBtn.BackgroundColor3 = Color3.fromRGB(45, 185, 105)
        task.wait(1)
        ShuffleBtn.Text = "🔀 SHUFFLE" ShuffleBtn.BackgroundColor3 = Color3.fromRGB(230, 140, 15)
    end)
    
    local isShowingSettings = false
    ConfigGearBtn.MouseButton1Click:Connect(function()
        isShowingSettings = not isShowingSettings
        if isShowingSettings then
            MainButtonsFrame.Visible = false
            UtilityScroll.Visible = false
            isShowingUtility = false
            SettingsScroll.Visible = true
            Title.Text = "Settings Options:"
            ConfigGearBtn.Text = "←"
        else
            SettingsScroll.Visible = false
            UtilityScroll.Visible = false
            isShowingUtility = false
            MainButtonsFrame.Visible = true
            -- Clean up: restore main selection buttons, hide sub-mode ones
            RbxBtn.Visible = true
            OwnBtn.Visible = true
            BuiltInBtn.Visible = false
            CustomBtn.Visible = false
            Title.Text = "Do you want to use Roblox music IDs or your own?"
            ConfigGearBtn.Text = "⚙"
        end
    end)

    local PeppinoEnabled = PersistentSettings.PEPPINO
    local PeppinoCorner = nil -- floating corner instance

    local function SaveCurrentSettings()
        SaveDataSettings({
            WT = GetWelcomeSetting(),
            MUTE = AudioPlayer.IsGameMuted,
            FLASH = AudioPlayer.IsFlashEnabled,
            STATS = SystemStatsBar.Visible,
            RGB = AudioPlayer.IsChromaEnabled,
            FULLRGB = AudioPlayer.IsFullChroma,
            PEPPINO = PeppinoEnabled,
        })
    end

    GameMuteToggleBtn.BackgroundColor3 = PersistentSettings.MUTE and Color3.fromRGB(35, 185, 105) or Color3.fromRGB(235, 75, 75)
    GameMuteToggleBtn.Text = PersistentSettings.MUTE and "MUTE GAME MUSIC: ON" or "MUTE GAME MUSIC: OFF"
    FlashToggleBtn.BackgroundColor3 = PersistentSettings.FLASH and Color3.fromRGB(45, 185, 105) or Color3.fromRGB(235, 75, 75)
    FlashToggleBtn.Text = PersistentSettings.FLASH and "BEAT OVERLAY FLASH: ON" or "BEAT OVERLAY FLASH: OFF"
    StatToggleBtn.BackgroundColor3 = PersistentSettings.STATS and Color3.fromRGB(45, 185, 105) or Color3.fromRGB(235, 75, 75)
    StatToggleBtn.Text = PersistentSettings.STATS and "SYSTEM STATS HUD: ON" or "SYSTEM STATS HUD: OFF"
    RgbToggleBtn.BackgroundColor3 = PersistentSettings.RGB and Color3.fromRGB(45, 185, 105) or Color3.fromRGB(235, 75, 75)
    RgbToggleBtn.Text = PersistentSettings.RGB and "RGB EFFECT: ON" or "RGB EFFECT: OFF"
    FullRgbToggleBtn.BackgroundColor3 = PersistentSettings.FULLRGB and Color3.fromRGB(45, 185, 105) or Color3.fromRGB(235, 75, 75)
    FullRgbToggleBtn.Text = PersistentSettings.FULLRGB and "FULL RGB (NO DARK HUE): ON" or "FULL RGB (NO DARK HUE): OFF"

    GameMuteToggleBtn.MouseButton1Click:Connect(function()
        local isMuted = AudioPlayer:ToggleGameMute()
        GameMuteToggleBtn.Text = isMuted and "MUTE GAME MUSIC: ON" or "MUTE GAME MUSIC: OFF"
        GameMuteToggleBtn.BackgroundColor3 = isMuted and Color3.fromRGB(35, 185, 105) or Color3.fromRGB(235, 75, 75)
        SaveCurrentSettings()
    end)

    FlashToggleBtn.MouseButton1Click:Connect(function()
        AudioPlayer.IsFlashEnabled = not AudioPlayer.IsFlashEnabled
        FlashToggleBtn.Text = AudioPlayer.IsFlashEnabled and "BEAT OVERLAY FLASH: ON" or "BEAT OVERLAY FLASH: OFF"
        FlashToggleBtn.BackgroundColor3 = AudioPlayer.IsFlashEnabled and Color3.fromRGB(45, 185, 105) or Color3.fromRGB(235, 75, 75)
        SaveCurrentSettings()
    end)

    StatToggleBtn.MouseButton1Click:Connect(function()
        local showStats = not SystemStatsBar.Visible
        SystemStatsBar.Visible = showStats
        StatToggleBtn.Text = showStats and "SYSTEM STATS HUD: ON" or "SYSTEM STATS HUD: OFF"
        StatToggleBtn.BackgroundColor3 = showStats and Color3.fromRGB(45, 185, 105) or Color3.fromRGB(235, 75, 75)
        SaveCurrentSettings()
    end)

    RgbToggleBtn.MouseButton1Click:Connect(function()
        AudioPlayer.IsChromaEnabled = not AudioPlayer.IsChromaEnabled
        RgbToggleBtn.Text = AudioPlayer.IsChromaEnabled and "RGB EFFECT: ON" or "RGB EFFECT: OFF"
        RgbToggleBtn.BackgroundColor3 = AudioPlayer.IsChromaEnabled and Color3.fromRGB(45, 185, 105) or Color3.fromRGB(235, 75, 75)
        SaveCurrentSettings()
    end)

    FullRgbToggleBtn.MouseButton1Click:Connect(function()
        AudioPlayer.IsFullChroma = not AudioPlayer.IsFullChroma
        FullRgbToggleBtn.Text = AudioPlayer.IsFullChroma and "FULL RGB (NO DARK HUE): ON" or "FULL RGB (NO DARK HUE): OFF"
        FullRgbToggleBtn.BackgroundColor3 = AudioPlayer.IsFullChroma and Color3.fromRGB(45, 185, 105) or Color3.fromRGB(235, 75, 75)
        SaveCurrentSettings()
    end)

    PeppinoToggleBtn.BackgroundColor3 = PeppinoEnabled and Color3.fromRGB(45, 185, 105) or Color3.fromRGB(235, 75, 75)
    PeppinoToggleBtn.Text = PeppinoEnabled and "PEPPINO CORNER: ON" or "PEPPINO CORNER: OFF"
    if PeppinoEnabled then
        PeppinoCorner = CreatePeppinoCorner(ScreenGui)
    end
    PeppinoToggleBtn.MouseButton1Click:Connect(function()
        PeppinoEnabled = not PeppinoEnabled
        PeppinoToggleBtn.Text = PeppinoEnabled and "PEPPINO CORNER: ON" or "PEPPINO CORNER: OFF"
        PeppinoToggleBtn.BackgroundColor3 = PeppinoEnabled and Color3.fromRGB(45, 185, 105) or Color3.fromRGB(235, 75, 75)
        if PeppinoEnabled then
            if not PeppinoCorner or not PeppinoCorner.Parent then
                PeppinoCorner = CreatePeppinoCorner(ScreenGui)
            end
        else
            if PeppinoCorner then PeppinoCorner:Destroy() PeppinoCorner = nil end
        end
        SaveCurrentSettings()
    end)
    
    local isShowingUtility = false

    UtilityBtn.MouseButton1Click:Connect(function()
        isShowingUtility = not isShowingUtility
        if isShowingUtility then
            MainButtonsFrame.Visible = false
            SettingsScroll.Visible = false
            isShowingSettings = false
            UtilityScroll.Visible = true
            Title.Text = "Utility Options:"
            ConfigGearBtn.Text = "←"
        else
            UtilityScroll.Visible = false
            SettingsScroll.Visible = false
            isShowingSettings = false
            MainButtonsFrame.Visible = true
            -- Clean up: restore main selection buttons, hide sub-mode ones
            RbxBtn.Visible = true
            OwnBtn.Visible = true
            BuiltInBtn.Visible = false
            CustomBtn.Visible = false
            Title.Text = "Do you want to use Roblox music IDs or your own?"
            ConfigGearBtn.Text = "⚙"
        end
    end)

    RemoveUIBtn.MouseButton1Click:Connect(function()
        if ScreenGui then
            ScreenGui:Destroy()
        end
    end)

    CopyCreditsBtn.MouseButton1Click:Connect(function()
        if setclipboard then
            setclipboard("Langa Music Hub - by langarsch on discord:)")
            CopyCreditsBtn.Text = "CREDITS COPIED!"
            task.wait(1.5)
            if CopyCreditsBtn.Parent then CopyCreditsBtn.Text = "COPY CREDITS TO CLIPBOARD" end
        else
            CopyCreditsBtn.Text = "CLIPBOARD ERROR"
            task.wait(1.5)
            if CopyCreditsBtn.Parent then CopyCreditsBtn.Text = "COPY CREDITS TO CLIPBOARD" end
        end
    end)

    OpenWelcomeBtn.MouseButton1Click:Connect(function()
        UtilityScroll.Visible = false
        MainButtonsFrame.Visible = true
        isShowingUtility = false
        ConfigGearBtn.Text = "⚙"
        Title.Text = "Do you want to use Roblox music IDs or your own?"
        CreateWelcomeUI(ScreenGui, function()
            if PromptFrame and PromptFrame.Parent then
                FadeUIWindow(PromptFrame, true, 0.5, Enum.EasingStyle.Back)
            end
        end, RefreshWelcomeToggleUI)
    end)

    local isDrawerOpen = false
    DrawerToggleBtn.MouseButton1Click:Connect(function()
        isDrawerOpen = not isDrawerOpen
        local targetSize = isDrawerOpen and UDim2.new(0, 85, 1, 0) or UDim2.new(0, 0, 1, 0)
        if isDrawerOpen then SideDrawer.Visible = true end
        local tween = TweenService:Create(SideDrawer, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = targetSize})
        tween:Play()
        tween.Completed:Connect(function() if not isDrawerOpen then SideDrawer.Visible = false end end)
    end)

    local function ConnectVolumeButton(b, d)
        local a = false
        b.MouseButton1Down:Connect(function()
            a = true
            VolDisplay.Text = math.round(AudioPlayer:SetVolume(AudioPlayer.CurrentVolume + (0.05 * d)) * 100) .. "%"
            task.wait(0.4)
            while a do
                VolDisplay.Text = math.round(AudioPlayer:SetVolume(AudioPlayer.CurrentVolume + (0.05 * d)) * 100) .. "%"
                task.wait(0.08)
            end
        end)
        b.MouseButton1Up:Connect(function() a = false end)
        b.MouseLeave:Connect(function() a = false end)
    end

    ConnectVolumeButton(VolUpBtn, 1)
    ConnectVolumeButton(VolDnBtn, -1)
    
    local isHoldingTutorial = false
    local tutorialHoldOpenedAI = false
    TutorialBtn.MouseButton1Down:Connect(function()
        isHoldingTutorial = true
        tutorialHoldOpenedAI = false
        local holdTime = 0
        while isHoldingTutorial do
            task.wait(0.1)
            holdTime = holdTime + 0.1
            if holdTime >= 1.5 then
                isHoldingTutorial = false
                tutorialHoldOpenedAI = true
                TutorialBtn.Text = "OPENING AI..."
                TutorialBtn.BackgroundColor3 = Color3.fromRGB(180, 70, 160)
                task.wait(0.25)
                -- Reset button text right away (don't wait for AI close)
                if TutorialBtn and TutorialBtn.Parent then
                    TutorialBtn.Text = "TUTORIAL"
                    TutorialBtn.BackgroundColor3 = Color3.fromRGB(140, 75, 195)
                end
                CreateFloweryAIUI(ScreenGui, function() end)
                return
            end
        end
    end)

    TutorialBtn.MouseButton1Up:Connect(function()
        if isHoldingTutorial and not tutorialHoldOpenedAI then
            isHoldingTutorial = false
            -- Short click = copy tutorial
            if setclipboard then
                local msg = [[=== LANGA MUSIC HUB TUTORIAL ===

MUSIC SOURCES
1. RBX MUSIC — tap for Built-in / Custom playlists
2. Hold RBX MUSIC 1.5s — hijack active game sounds
3. OWN MUSIC — uses files in LANGAMUSICHUB/OWN MUSIC
4. Hold OWN MUSIC 1.5s — deep scan executor workspace for mp3/wav/ogg/mp4

PLAYER CONTROLS
5. Pause/Play — short click toggles pause
6. Hold Pause/Play 1.5s — open Flowery AI while music plays
7. << / >> — previous / next track
8. Side drawer (speaker icon) — volume + / - and Shuffle
9. Close (X) — minimizes to floating bubble
10. Hold floating bubble 1.5s — full reset back to main menu

SETTINGS (gear)
11. Mute Game Music
12. Beat Overlay Flash
13. System Stats HUD (12-hour clock)
14. Show Welcome Screen
15. RGB Effect on/off
16. Full RGB (bright) vs dark hue

UTILITY (wrench)
17. Remove UI / Copy Credits / Open Welcome UI

FLOWERY AI
18. Hold TUTORIAL 1.5s OR hold Pause/Play 1.5s to open AI
19. Gear inside AI — persona manager
20. Flowery is locked (can't delete / can't copy)
21. + Add Persona → NORMAL (create) or IMPORT (paste friend's JSON)
22. Hold + Add Persona 1.5s — copy blank JSON template for friends
23. Hold a custom persona 1.5s — copy its JSON to clipboard to share
24. Switching personas clears the current chat
25. Custom personas save as .json files in LANGAMUSICHUB/PERSONAS/

PEPPINO
26. Peppino appears on the Welcome screen — click to squish + sound
27. 10% chance Peppino kills you, flashes an image, plays a sound & yells STOP
28. Settings → PEPPINO CORNER toggles him on the bottom-left of your screen
29. Peppino toggle is saved to data.txt

TIPS
30. Short click TUTORIAL — copies this help text
31. Settings & RGB preferences save to data.txt]]
                setclipboard(msg)
                TutorialBtn.Text = "TUTORIAL COPIED!"
                TutorialBtn.BackgroundColor3 = Color3.fromRGB(35, 185, 105)
                task.wait(2.5)
                if TutorialBtn and TutorialBtn.Parent then
                    TutorialBtn.Text = "TUTORIAL"
                    TutorialBtn.BackgroundColor3 = Color3.fromRGB(140, 75, 195)
                end
            else
                TutorialBtn.Text = "CLIPBOARD ERROR"
                task.wait(2.5)
                if TutorialBtn and TutorialBtn.Parent then
                    TutorialBtn.Text = "TUTORIAL"
                end
            end
        end
    end)
    TutorialBtn.MouseLeave:Connect(function()
        isHoldingTutorial = false
    end)

    CloseBtn.MouseButton1Click:Connect(function()
        FadeUIWindow(MainHub, false)
        FloatingBubble.Visible = true
        ResetIdleTimer()
    end)

    local isHoldingBubble = false
    FloatingBubble.MouseButton1Down:Connect(function()
        ResetIdleTimer()
        isHoldingBubble = true
        local hTime = 0
        while isHoldingBubble do
            task.wait(0.1)
            hTime = hTime + 0.1
            if hTime >= 1.5 then
                isHoldingBubble = false
                AudioPlayer:StopEverything()
                FloatingBubble.Visible = false
                MainHub.Visible = false
                PauseBtn.Text = "PAUSE"
                PauseBtn.BackgroundColor3 = Color3.fromRGB(15, 125, 235)
                
                SettingsScroll.Visible = false
                MainButtonsFrame.Visible = true
                RbxBtn.Visible = true
                OwnBtn.Visible = true
                BuiltInBtn.Visible = false
                CustomBtn.Visible = false
                
                isShowingSettings = false
                ConfigGearBtn.Text = "⚙"
                Title.Text = "Do you want to use Roblox music IDs or your own?"
                FadeUIWindow(PromptFrame, true, 0.45, Enum.EasingStyle.Back)
                return
            end
        end
    end)

    FloatingBubble.MouseButton1Up:Connect(function()
        if isHoldingBubble then
            isHoldingBubble = false
            FloatingBubble.Visible = false
            FadeUIWindow(MainHub, true, 0.45, Enum.EasingStyle.Back)
        end
    end)

    local isHoldingPause = false
    local pauseHoldOpenedAI = false
    PauseBtn.MouseButton1Down:Connect(function()
        isHoldingPause = true
        pauseHoldOpenedAI = false
        local holdTime = 0
        while isHoldingPause do
            task.wait(0.1)
            holdTime = holdTime + 0.1
            if holdTime >= 1.5 then
                isHoldingPause = false
                pauseHoldOpenedAI = true
                -- Open Flowery AI while music can keep playing
                CreateFloweryAIUI(ScreenGui, function() end)
                return
            end
        end
    end)
    PauseBtn.MouseButton1Up:Connect(function()
        if isHoldingPause and not pauseHoldOpenedAI then
            isHoldingPause = false
            -- Short click = normal pause/play toggle
            local isPaused = AudioPlayer:TogglePause()
            PauseBtn.Text = isPaused and "PLAY" or "PAUSE"
            PauseBtn.BackgroundColor3 = isPaused and Color3.fromRGB(35, 185, 105) or Color3.fromRGB(15, 125, 235)
        end
    end)
    PauseBtn.MouseLeave:Connect(function()
        isHoldingPause = false
    end)

    SkipBtn.MouseButton1Click:Connect(function() AudioPlayer:PlayNext() PauseBtn.Text = "PAUSE" PauseBtn.BackgroundColor3 = Color3.fromRGB(15, 125, 235) end)
    BackBtn.MouseButton1Click:Connect(function() AudioPlayer:PlayPrevious() PauseBtn.Text = "PAUSE" PauseBtn.BackgroundColor3 = Color3.fromRGB(15, 125, 235) end)
    
    local isHoldingRbxBtn = false
    RbxBtn.MouseButton1Down:Connect(function()
        isHoldingRbxBtn = true
        local cPress = 0
        while isHoldingRbxBtn do
            task.wait(0.1)
            cPress = cPress + 0.1
            if cPress >= 1.5 then
                isHoldingRbxBtn = false
                Title.Text = "HIJACKING GAME UNIVERSE SOUNDS..."
                Title.TextColor3 = Color3.fromRGB(15, 125, 235)
                task.wait(0.5)
                local gameTracks = {}
                for _, o in ipairs(game:GetDescendants()) do
                    if o:IsA("Sound") and o.SoundId ~= "" and o.Name ~= "Sound" and #o.SoundId > 10 and o ~= AudioPlayer.SoundObject then
                        table.insert(gameTracks, {Id = o.SoundId, Name = "[GAME HIJACK]: " .. o.Name})
                    end
                end
                if #gameTracks > 0 then
                    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
                    FadeUIWindow(PromptFrame, false)
                    FadeUIWindow(MainHub, true, 0.45, Enum.EasingStyle.Back)
                    AudioPlayer:Start(gameTracks)
                else
                    Title.Text = "SCAN FAILED: No active sounds found!"
                    task.wait(2.5)
                    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
                    Title.Text = "Do you want to use Roblox music IDs or your own?"
                end
                return
            end
        end
    end)

    RbxBtn.MouseButton1Up:Connect(function()
        if isHoldingRbxBtn then
            isHoldingRbxBtn = false
            RbxBtn.Visible = false
            OwnBtn.Visible = false
            BuiltInBtn.Visible = true
            CustomBtn.Visible = true
            Title.Text = "Select Roblox Playlist Source Type:"
        end
    end)
    RbxBtn.MouseLeave:Connect(function() isHoldingRbxBtn = false end)

    BuiltInBtn.MouseButton1Click:Connect(function()
        FadeUIWindow(PromptFrame, false)
        FadeUIWindow(MainHub, true, 0.45, Enum.EasingStyle.Back)
        AudioPlayer:Start(BUILTIN_RBX)
    end)

    CustomBtn.MouseButton1Click:Connect(function()
        local files = listfiles("LANGAMUSICHUB/RBXMUSIC")
        local customTracks = {}
        for _, filePath in ipairs(files) do
            if filePath:lower():match("%.txt$") then
                local songName = filePath:sub(#"LANGAMUSICHUB/RBXMUSIC" + 2):gsub("%.txt$", "")
                local rawId = readfile(filePath):gsub("%s+", "")
                if not rawId:match("^rbxassetid://") then rawId = "rbxassetid://" .. rawId end
                table.insert(customTracks, {Id = rawId, Name = songName})
            end
        end
        if #customTracks > 0 then
            FadeUIWindow(PromptFrame, false)
            FadeUIWindow(MainHub, true, 0.45, Enum.EasingStyle.Back)
            AudioPlayer:Start(customTracks)
        else
            Title.Text = "Access Denied: No .txt files located inside standard /RBXMUSIC folder!"
            task.wait(3)
            Title.Text = "Select Roblox Playlist Source Type:"
        end
    end)
    
    local isHoldingOwnBtn = false
    OwnBtn.MouseButton1Down:Connect(function()
        isHoldingOwnBtn = true
        local cPress = 0
        while isHoldingOwnBtn do
            task.wait(0.1)
            cPress = cPress + 0.1
            if cPress >= 1.5 then
                isHoldingOwnBtn = false
                Title.Text = "SCANNING EXECUTOR WORKSPACE STORAGE..."
                Title.TextColor3 = Color3.fromRGB(35, 185, 105)
                task.wait(0.5)
                local workspaceScannedTracks = DeepScanExecutorWorkspace(".")
                if #workspaceScannedTracks > 0 then
                    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
                    FadeUIWindow(PromptFrame, false)
                    FadeUIWindow(MainHub, true, 0.45, Enum.EasingStyle.Back)
                    AudioPlayer:Start(workspaceScannedTracks)
                else
                    Title.Text = "SCAN EMPTY: No media containers found!"
                    task.wait(2.5)
                    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
                    Title.Text = "Do you want to use Roblox music IDs or your own?"
                end
                return
            end
        end
    end)

    OwnBtn.MouseButton1Up:Connect(function()
        if isHoldingOwnBtn then
            isHoldingOwnBtn = false
            local files = listfiles("LANGAMUSICHUB/OWN MUSIC")
            local localTracks = {}
            for _, filePath in ipairs(files) do
                if filePath:match("%.%w+$") then
                    local cleanName = filePath:sub(#"LANGAMUSICHUB/OWN MUSIC" + 2)
                    table.insert(localTracks, {Id = getcustomasset(filePath), Name = cleanName})
                end
            end
            if #localTracks > 0 then
                FadeUIWindow(PromptFrame, false)
                FadeUIWindow(MainHub, true, 0.45, Enum.EasingStyle.Back)
                AudioPlayer:Start(localTracks)
            else
                Title.Text = "Access Denied: No music tracks found inside standard /OWN MUSIC folder!"
                task.wait(3)
                Title.Text = "Do you want to use Roblox music IDs or your own?"
            end
        end
    end)
    OwnBtn.MouseLeave:Connect(function() isHoldingOwnBtn = false end)

    -- Execution Initialization Logic based on data.txt state
    local shouldShowWelcome = GetWelcomeSetting()
    if shouldShowWelcome then
        PromptFrame.Visible = false
        CreateWelcomeUI(ScreenGui, function()
            FadeUIWindow(PromptFrame, true, 0.5, Enum.EasingStyle.Back)
        end, RefreshWelcomeToggleUI)
    else
        FadeUIWindow(PromptFrame, true, 0.5, Enum.EasingStyle.Back)
    end
end

CreateUI()
