--// PLaNS SHOP - Gem Farming Script
repeat wait() until game.Players.LocalPlayer and game.Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("spawn_units")
repeat wait() until game.Players.LocalPlayer:FindFirstChild("_stats")

--------------------------------------------------------------------------------
-- (A) Initialize Services & Variables
--------------------------------------------------------------------------------

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer

-- Utility Functions
local function GetNumberFromString(S) return string.match(S,"%d+") end 
local function GetTimeFromString(S) return string.match(S, "%d+:%d+") end

-- Get Player Avatar
local ThumbnailURL = nil
local success, result = pcall(function()
    local ThumbnailRequest = http.request({
        Url = "https://thumbnails.roblox.com/v1/users/avatar?userIds="..tostring(player.UserId).."&size=420x420&format=Png&isCircular=false",
        Method = "GET",
        Headers = {["Content-Type"] = "application/json"},
    })
    return (HttpService:JSONDecode(ThumbnailRequest.Body))["data"][1]["imageUrl"]
end)
if success then ThumbnailURL = result else warn("Failed to get avatar:", result) end

--------------------------------------------------------------------------------
-- (B) Webhook Configuration
--------------------------------------------------------------------------------

_G.Webhook = "https://discord.com/api/webhooks/1283623950017892382/2y8Qax0xHlH-UYlDulC9-2GCsG_qjIqswU6rt-q9fGR3ix9o7SfDGXR-9lL6PqB64jbb" -- Main webhook
_G.Webhook2 = "https://discord.com/api/webhooks/1283623950017892382/2y8Qax0xHlH-UYlDulC9-2GCsG_qjIqswU6rt-q9fGR3ix9o7SfDGXR-9lL6PqB64jbb" -- Secondary webhook
local WebhookEnd = "https://discord.com/api/webhooks/1099711689450066060/_0cDSkNN4gfosy0oL-5i9Rg8BXF0hQ2Bu4d3H-AlCuZf1T8_3hL-qxi3X1mt1DrDtLcV" -- End webhook
local LogoURLs = "https://cdn.discordapp.com/attachments/1082245350166892554/1323232911272448010/logo.png?ex=6773c42e&is=677272ae&hm=73bbda78feab2829609946c3dced71b8e6f9f544c3888a019a1ae5f304332588&"

--------------------------------------------------------------------------------
-- (C) Local Storage System
--------------------------------------------------------------------------------

local SettingsFile = player.Name .. "_SHOPData.json"

local DefaultData = {
    MaxGems = 0,
    DiscordID = "",
    OldGems = 0,
    IsSended = false,
    AddGemsWanted = 0,
    sumGems = 0,
    SavedLevel = "???",
    SavedBP = "???",
    SavedBP2 = "???",
    TimeWanted = 0,
    StartTime = 0,
    IsTimeMode = false  -- เพิ่มตัวแปรสำหรับเช็คโหมดการทำงาน
}

-- Storage Functions
local function loadSettings()
    if not isfile or not isfile(SettingsFile) then
        if writefile then
            writefile(SettingsFile, HttpService:JSONEncode(DefaultData))
        end
        return DefaultData
    end

    local success, data = pcall(function()
        return HttpService:JSONDecode(readfile(SettingsFile))
    end)
    
    if not success or type(data) ~= "table" then
        warn("Invalid JSON file - creating new one")
        if writefile then
            writefile(SettingsFile, HttpService:JSONEncode(DefaultData))
        end
        return DefaultData
    end
    
    return data
end

local function saveSettings(tbl)
    if writefile then
        local success, result = pcall(function()
            writefile(SettingsFile, HttpService:JSONEncode(tbl))
        end)
        if not success then
            warn("Failed to save settings:", result)
        end
    end
end

-- แก้ไขฟังก์ชัน resetModes ให้รีเซ็ตค่า WebhookSent ด้วย
local function resetModes()
    if not LocalData then return end
    LocalData.TimeWanted = 0
    LocalData.StartTime = 0
    LocalData.IsTimeMode = false
    LocalData.MaxGems = 0
    LocalData.AddGemsWanted = 0
    LocalData.sumGems = 0
    LocalData.WebhookSent = false
    WebhookSent = false  -- เพิ่มการรีเซ็ตตัวแปร global
    saveSettings(LocalData)
end

--------------------------------------------------------------------------------
-- (D) Load Player Data
--------------------------------------------------------------------------------

local LocalData = loadSettings()
local function SafeGet(key, default) return LocalData[key] ~= nil and LocalData[key] or default end

-- Initialize variables with safe defaults
local MaxGems = SafeGet("MaxGems", 0)
local DiscordID = SafeGet("DiscordID", "")
local OldGems = SafeGet("OldGems", 0)
local IsSended = SafeGet("IsSended", false)
local AddGemsWanted = SafeGet("AddGemsWanted", 0)
local SavedLevel = SafeGet("SavedLevel", "???")
local SavedBP = SafeGet("SavedBP", "???")
local SavedBP2 = SafeGet("SavedBP2", "???")

--------------------------------------------------------------------------------
-- (E) Game Stats Tracking
--------------------------------------------------------------------------------

-- Get current gems
local currentGems = 0
pcall(function()
    local stats = player:WaitForChild("_stats", 5)
    local gemObj = stats and stats:WaitForChild("gem_amount", 2)
    if gemObj and typeof(gemObj.Value) == "number" then
        currentGems = gemObj.Value
    end
end)

-- Get current gold
local currentGold = 0
pcall(function()
    local stats = player:WaitForChild("_stats", 5)
    local goldObj = stats and stats:WaitForChild("gold_amount", 2)
    if goldObj and typeof(goldObj.Value) == "number" then
        currentGold = goldObj.Value
    end
end)

--------------------------------------------------------------------------------
-- (F) Level & Battle Pass Tracking
--------------------------------------------------------------------------------

local function TryGetLevelOrSaved()
    local foundLevel = nil
    pcall(function()
        local spawnUnits = player:WaitForChild("PlayerGui", 5):WaitForChild("spawn_units", 2)
        local lvlObj = spawnUnits.Lives.Main.Desc:WaitForChild("Level", 2)
        foundLevel = lvlObj.Text
    end)
    
    if not foundLevel then return SavedLevel end
    
    local newLV = string.gsub(foundLevel, "Level ", "")
    LocalData.SavedLevel = newLV
    saveSettings(LocalData)
    return newLV
end

local function TryGetBPOrSaved()
    local foundBP = nil
    pcall(function()
        local bpGui = player:WaitForChild("PlayerGui", 5):WaitForChild("BattlePass", 2)
        local mainFrm = bpGui:WaitForChild("Main", 2)
        local lvFrm = mainFrm:WaitForChild("Level", 2)
        foundBP = lvFrm:WaitForChild("V", 2).Text
    end)
    
    if not foundBP or foundBP == "99" then return SavedBP end
    
    LocalData.SavedBP = foundBP
    saveSettings(LocalData)
    return foundBP
end

local function TryGetBPOrSaved2()
    local foundBP2 = nil
    pcall(function()
        local bpGui = player:WaitForChild("PlayerGui", 5):WaitForChild("BattlePass", 2)
        local mainFrm = bpGui:WaitForChild("Main", 2)
        local lvFrm = mainFrm:WaitForChild("FurthestRoom", 2)
        foundBP2 = lvFrm:WaitForChild("V", 2).Text
    end)
    
    if not foundBP2 or foundBP2 == "100000" or foundBP2 == "100000/100000" then 
        return SavedBP2 
    end
    
    LocalData.SavedBP2 = foundBP2
    saveSettings(LocalData)
    return foundBP2
end

-- Update current values
local currentLevel = TryGetLevelOrSaved()
local currentBP = TryGetBPOrSaved()
local currentBP2 = TryGetBPOrSaved2()

--------------------------------------------------------------------------------
-- (G) Webhook System
--------------------------------------------------------------------------------

local function SendWebhookRequest(url, payload)
    local req = http_request or request or HttpPost or syn and syn.request
    if not req then
        warn("HTTP request function not found")
        return false
    end
    
    local success, result = pcall(function()
        return req({
            Url = url,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(payload)
        })
    end)
    
    if not success then
        warn("Failed to send webhook:", result)
        return false
    end
    
    return true
end

local function sendWebhook(title, desc)
    local payload = {
        content = "",
        embeds = {{
            title = title,
            description = desc,
            color = 0x00FF99,
            image = { url = ThumbnailURL },
            footer = { icon_url = LogoURLs, text = "PLaNS SHOP"},
            timestamp = DateTime.now():ToIsoDate()
        }}
    }
    return SendWebhookRequest(_G.Webhook, payload)
end

local function sendWebhook2(title, desc)
    local payload = {
        content = string.format("<@%s> <@&1006505817769521177>", DiscordID),
        embeds = {{
            title = title,
            description = desc,
            color = 0xFF1493,
            image = { url = ThumbnailURL },
            footer = { icon_url = LogoURLs, text = "PLaNS SHOP"},
            timestamp = DateTime.now():ToIsoDate()
        }}
    }
    return SendWebhookRequest(_G.Webhook, payload)
end

local function sendWebhookEnd(title, desc)
    local payload = {
        content = string.format("<@%s> <@&1006505817769521177>", DiscordID),
        embeds = {{
            title = title,
            description = desc,
            color = 0xFF1493,
            image = { url = ThumbnailURL },
            footer = { icon_url = LogoURLs, text = "PLaNS SHOP"},
            timestamp = DateTime.now():ToIsoDate()
        }}
    }
    return SendWebhookRequest(WebhookEnd, payload)
end


local function sendWebhookEnd2(title, desc)
    local payload = {
        content = string.format("<@%s> <@&1006505817769521177>", DiscordID),
        embeds = {{
            title = title,
            description = desc,
            color = 0xFF1493,
            image = { url = ThumbnailURL },
            footer = { icon_url = LogoURLs, text = "PLaNS SHOP"},
            timestamp = DateTime.now():ToIsoDate()
        }}
    }
    return SendWebhookRequest(WebhookEnd, payload)
end
--------------------------------------------------------------------------------
-- (H) Game Finished Handler
--------------------------------------------------------------------------------


local function WaitForGameFinished()
    local GameFinished
    pcall(function()
        local DataFolder = game:GetService("Workspace"):WaitForChild("_DATA", 10)
        if DataFolder then
            GameFinished = DataFolder:WaitForChild("GameFinished", 10)
        end
    end)
    return GameFinished
end



local GameFinished = WaitForGameFinished()
local WebhookSent = false

if GameFinished then
    local function SendGameFinishedWebhook()
        -- ตรวจสอบเงื่อนไขการทำงาน
        if not (GameFinished.Value == true and not WebhookSent) then return end
        WebhookSent = true
        
        -- รอให้ UI พร้อม
        local function waitForUI()
            local success, result = pcall(function()
                local ResultsUI = player.PlayerGui:WaitForChild("ResultsUI", 10)
                if not ResultsUI then return false end
                
                local GemReward = ResultsUI.Holder.LevelRewards.ScrollingFrame:WaitForChild("GemReward", 5)
                if not GemReward then return false end
                
                local Amount = GemReward.Main:WaitForChild("Amount", 2)
                if not Amount then return false end
                
                return true
            end)
            return success and result
        end

        if not waitForUI() then
            warn("Failed to load UI")
            WebhookSent = false --false
            return
        end

        -- กดปุ่ม Next และรอ Unit Info
        task.spawn(function()
            local function clickNextButton()
                local button = player.PlayerGui.ResultsUI.Holder.Buttons:FindFirstChild("Next")
                if button then
                    task.wait(0.35)
                    local function checkUnitInfo()
                        local UnitInfo = player.PlayerGui:FindFirstChild("UnitInfo")
                        if not UnitInfo then return false end
                        
                        local holder = UnitInfo:FindFirstChild("holder")
                        if not holder then return false end
                        
                        local info1 = holder:FindFirstChild("info1")
                        if not info1 then return false end
                        
                        local UnitName = info1:FindFirstChild("UnitName")
                        if not UnitName then return false end
                        
                        -- เพิ่มการตรวจสอบ TextLabel หรือ Text
                        local nameText = UnitName:FindFirstChild("UnitNameText") or UnitName:FindFirstChild("Text")
                        if not nameText then return false end
                        
                        return nameText.Text and string.find(nameText.Text, "x") ~= nil
                    end
                    
                    local startTime = tick()
                    repeat
                        spawn(function()
                            for _, connection in pairs(getconnections(button.Activated)) do
                                connection:Fire()
                            end
                        end)
                        wait(0.5)
                    until checkUnitInfo() or (tick() - startTime > 2)
                else
                    print("ไม่พบปุ่ม Next ใน GUI!")
                    WebhookSent = false
                end
            end

            local startTime = tick()
            repeat
                clickNextButton()
                task.wait(0.35)
            until (player.PlayerGui:FindFirstChild("UnitInfo") 
                   and player.PlayerGui.UnitInfo:FindFirstChild("holder")
                   and player.PlayerGui.UnitInfo.holder:FindFirstChild("info1")
                   and player.PlayerGui.UnitInfo.holder.info1:FindFirstChild("UnitName")
                   and player.PlayerGui.UnitInfo.holder.info1.UnitName:FindFirstChild("UnitNameText")
                   and string.find(player.PlayerGui.UnitInfo.holder.info1.UnitName.UnitNameText.Text, "x"))
                   or (tick() - startTime > 2)
        end)

        -- ดึงข้อมูลเพชรที่ได้
        local GemGET = 0
        pcall(function()
            local gemText = player.PlayerGui.ResultsUI.Holder.LevelRewards.ScrollingFrame.GemReward.Main.Amount.Text
            GemGET = tonumber(GetNumberFromString(gemText)) or 0
            if GemGET == 0 then
                GemGET = 102
            end
            if GemGET > 10000 then -- ป้องกันค่าผิดปกติ
                warn("Suspicious gem amount:", GemGET)
                GemGET = 102
            end
        end)

        -- อัพเดท sumGems
        if LocalData.sumGems > 0 then
            LocalData.sumGems = math.max(0, LocalData.sumGems - GemGET)
            print(string.format("Got %d gems => %d remaining", GemGET, LocalData.sumGems))

            -- เช็คว่าฟาร์มครบหรือยัง
            if LocalData.sumGems <= 0 then
                task.spawn(function()
                    local success = sendWebhookEnd(
                        "✨ ฟามเสร็จแล้วเปลี่ยนรหัสผ่านเลย! ✨",
                        string.format(
                            "🔒・Username : ||**%s**||\n" ..
                            "```md\n#Profile\n" ..
                            "💎・Gems : %d\n" ..
                            "🟡・Gold : %d\n" ..
                            "🧪・Level : %s\n" ..
                            "🔋・Battle Pass : %s [%s]\n" ..
                            "- ฟามเสร็จแล้ว! [%d/%d]\n" ..
                            "```\n" ..
                            "```md\n#Package Info\n- ฟามเพชร : %d 💎```\n\n" ..
                            "อย่าลืมรีวิวด้วยน้า·ʚ♡ɞ·\n[ฝาก +1 โปร์ไฟล์เฟสด้วยงับ](https://www.facebook.com/photo/?fbid=817544902138722&set=a.117678525458700)\n\n<a:emoji_98_jk:1054831096929452042> ขอบคุณที่ใช้บริการน้า <a:8699rightrainbowstar:1054740408434966588>",
                            player.Name,
                            currentGems,
                            currentGold,
                            currentLevel,
                            currentBP,
                            currentBP2,
                            LocalData.AddGemsWanted - LocalData.sumGems,
                            LocalData.AddGemsWanted,
                            LocalData.AddGemsWanted
                        )
                    )
                end)
            end
            saveSettings(LocalData)
        end

        -- เตรียมข้อมูลสำหรับ webhook ปกติ
        local stats = {
            Level = player.PlayerGui["spawn_units"].Lives.Main.Desc.Level.Text,
            GEMS = player["_stats"]["gem_amount"].Value,
            Gold = player["_stats"]["gold_amount"].Value,
            XP = player.PlayerGui.ResultsUI.Holder.LevelRewards.ScrollingFrame.XPReward.Main.Amount.Text,
            Title = player.PlayerGui.NewArea.holder.areaTitle.Text,
            Description = player.PlayerGui.NewArea.holder.areaDescription.Text,
            Difficulty = player.PlayerGui.NewArea.holder.Difficulty.Text,
            Wave = player.PlayerGui.ResultsUI.Holder.Middle.WavesCompleted.Text,
            Time = player.PlayerGui.ResultsUI.Holder.Middle.Timer.Text,
            Kills = player["_stats"].kills.Value
        }

        -- ดึงข้อมูล items ที่ได้
        local AllItem = ""
        task.wait(0.35) -- รอก่อน
        pcall(function()
            local UnitInfo = player.PlayerGui:FindFirstChild("UnitInfo")
            if UnitInfo then
                local holder = UnitInfo:FindFirstChild("holder")
                if holder then
                    local info1 = holder:FindFirstChild("info1")
                    if info1 then
                        local UnitName = info1:FindFirstChild("UnitName")
                        if UnitName then
                            local nameText = UnitName:FindFirstChild("UnitNameText") or UnitName:FindFirstChild("Text")
                            if nameText and nameText.Text then
                                AllItem = "◈ " .. nameText.Text .. "\n"
                                print("Found item:", nameText.Text) -- Debug log
                            end
                        end
                    end
                end
            end
        end)

        -- สร้าง description สำหรับ webhook
        local InfoGameEnd = player.PlayerGui.ResultsUI.Holder.Title.Text or "N/A"
        local descFormat = string.format(
            "🔒・Username : ||%s||\n" ..
            "```md\n#Profile\n" ..
            "💎・Gems : %s\n" ..
            "🟡・Gold : %s\n" ..
            "🧪・Level : %s\n" ..
            "🔋・Battle Pass : %s [%s]" ..
            "```\n" ..
            "```md\n#Game Information\n" ..
            "- Result : %s\n" ..
            "- Map : %s\n" ..
            "- Mode : %s\n" ..
            "- Difficulty : %s\n" ..
            "- Wave : %s | Time: %s" ..
            "```\n" ..
            "```md\n#Enemies Killed\n" ..
            "- %d" ..
            "```\n" ..
            "```md\n#Rewards\n" ..
            "◈ %s 💎\n" ..
            "◈ %s 🍀\n" ..
            "%s" ..
            "```\n" ..
            "```md\n#Package Info\n" ..
            "- ฟามเพชรจำนวน : %d 💎\n" ..
            "- ดำเนินการแล้ว : [%d|%d]" ..
            "```\n",
            player.Name,
            stats.GEMS,
            stats.Gold,
            stats.Level,
            currentBP,
            currentBP2,
            InfoGameEnd,
            stats.Title,
            stats.Description,
            stats.Difficulty,
            GetNumberFromString(stats.Wave) or 0,
            GetTimeFromString(stats.Time) or "N/A",
            tonumber(stats.Kills) or 0,
            GemGET,
            stats.XP,
            AllItem,
            LocalData.AddGemsWanted,
            LocalData.AddGemsWanted - LocalData.sumGems,
            LocalData.AddGemsWanted            
        )

        if LocalData.sumGems > 0 then
            descFormat = descFormat .. string.format(
                "```md\n- เหลือที่ต้องฟามอีก : %d 💎```\n\n- จ้างโดยคุณ <@%s>",
                LocalData.sumGems,
                DiscordID
            )
        end

        -- ส่ง webhook ปกติ
        local req = http_request or request or HttpPost or syn and syn.request
        if req then
            local BodyJson = {
                content = "",
                embeds = {
                    {
                        title = "** <a:lp:1054740345709146182>  Round Complete! <a:lp:1054740345709146182>  **",
                        description = descFormat,
                        type = "rich",
                        color = 0x33FFCC,
                        image = { url = ThumbnailURL },
                        footer = { icon_url = LogoURLs, text = "PLaNS SHOP" },
                        timestamp = DateTime.now():ToIsoDate()
                    }
                }
            }

            req({
                Url = _G.Webhook,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(BodyJson)
            })
        end
    end
    

    -- เพิ่มฟังก์ชันใหม่สำหรับ webhook แบบเวลา
    local function SendGameFinishedWebhook2()
        if not (GameFinished.Value == true and not WebhookSent) then return end
        WebhookSent = true
        
        -- รอให้ UI พร้อม
    local function waitForUI()
        local success, result = pcall(function()
            local ResultsUI = player.PlayerGui:WaitForChild("ResultsUI", 10)
            if not ResultsUI then return false end
            
            local GemReward = ResultsUI.Holder.LevelRewards.ScrollingFrame:WaitForChild("GemReward", 5)
            if not GemReward then return false end
            
            local Amount = GemReward.Main:WaitForChild("Amount", 2)
            if not Amount then return false end
            
            return true
        end)
        return success and result
    end

    if not waitForUI() then
        warn("Failed to load UI")
        WebhookSent = false --false
        return
    end

    -- กดปุ่ม Next และรอ Unit Info
    task.spawn(function()
        local function clickNextButton()
            local button = player.PlayerGui.ResultsUI.Holder.Buttons:FindFirstChild("Next")
            if button then
                task.wait(0.35)
                local function checkUnitInfo()
                    local UnitInfo = player.PlayerGui:FindFirstChild("UnitInfo")
                    if not UnitInfo then return false end
                    
                    local holder = UnitInfo:FindFirstChild("holder")
                    if not holder then return false end
                    
                    local info1 = holder:FindFirstChild("info1")
                    if not info1 then return false end
                    
                    local UnitName = info1:FindFirstChild("UnitName")
                    if not UnitName then return false end
                    
                    -- เพิ่มการตรวจสอบ TextLabel หรือ Text
                    local nameText = UnitName:FindFirstChild("UnitNameText") or UnitName:FindFirstChild("Text")
                    if not nameText then return false end
                    
                    return nameText.Text and string.find(nameText.Text, "x") ~= nil
                end
                
                local startTime = tick()
                repeat
                    spawn(function()
                        for _, connection in pairs(getconnections(button.Activated)) do
                            connection:Fire()
                        end
                    end)
                    wait(1)
                until checkUnitInfo() or (tick() - startTime > 2)
            else
                print("ไม่พบปุ่ม Next ใน GUI!")
                WebhookSent = false
            end
        end

        local startTime = tick()
        repeat
            clickNextButton()
            task.wait(1)
        until (player.PlayerGui:FindFirstChild("UnitInfo") 
               and player.PlayerGui.UnitInfo:FindFirstChild("holder")
               and player.PlayerGui.UnitInfo.holder:FindFirstChild("info1")
               and player.PlayerGui.UnitInfo.holder.info1:FindFirstChild("UnitName")
               and player.PlayerGui.UnitInfo.holder.info1.UnitName:FindFirstChild("UnitNameText")
               and string.find(player.PlayerGui.UnitInfo.holder.info1.UnitName.UnitNameText.Text, "x"))
               or (tick() - startTime > 2)
    end)
        local stats = {
            Level = player.PlayerGui["spawn_units"].Lives.Main.Desc.Level.Text,
            GEMS = player["_stats"]["gem_amount"].Value,
            Gold = player["_stats"]["gold_amount"].Value,
            XP = player.PlayerGui.ResultsUI.Holder.LevelRewards.ScrollingFrame.XPReward.Main.Amount.Text,
            Title = player.PlayerGui.NewArea.holder.areaTitle.Text,
            Description = player.PlayerGui.NewArea.holder.areaDescription.Text,
            Difficulty = player.PlayerGui.NewArea.holder.Difficulty.Text,
            Wave = player.PlayerGui.ResultsUI.Holder.Middle.WavesCompleted.Text,
            Time = player.PlayerGui.ResultsUI.Holder.Middle.Timer.Text,
            Kills = player["_stats"].kills.Value
        }
        
        local GemGET = 0
        pcall(function()
            local gemText = player.PlayerGui.ResultsUI.Holder.LevelRewards.ScrollingFrame.GemReward.Main.Amount.Text
            GemGET = tonumber(GetNumberFromString(gemText)) or 0
            if GemGET == 0 then
                GemGET = 102
            end
        end)

        -- ดึงข้อมูล items ที่ได้ player.PlayerGui.UnitInfo.holder
        local AllItem = ""
        task.wait(0.35)
        pcall(function()
            local UnitInfo = player.PlayerGui:FindFirstChild("UnitInfo")
            if UnitInfo then
                local holder = UnitInfo:FindFirstChild("holder")
                if holder then
                    local info1 = holder:FindFirstChild("info1")
                    if info1 then
                        local UnitName = info1:FindFirstChild("UnitName")
                        if UnitName then
                            local nameText = UnitName:FindFirstChild("UnitNameText") or UnitName:FindFirstChild("Text")
                            if nameText and nameText.Text then
                                AllItem = AllItem .. "◈ " .. nameText.Text .. "\n"
                            end
                        end
                    end
                end
            end
        end)
        
        local InfoGameEnd = player.PlayerGui.ResultsUI.Holder.Title.Text or "N/A"
        -- คำนวณเวลา
        local currentTime = os.time()
        local elapsedTime = currentTime - LocalData.StartTime
        local remainingTime = math.max(0, LocalData.TimeWanted - elapsedTime)
        
        local days = math.floor(remainingTime / 86400)
        local hours = math.floor((remainingTime % 86400) / 3600)
        local minutes = math.floor((remainingTime % 3600) / 60)
        local seconds = remainingTime % 60
        
        local totalHours = math.floor(LocalData.TimeWanted / 3600)
        local elapsedHours = math.floor(elapsedTime / 3600)
        local totalDays = math.floor(totalHours / 24)
        local remainingHours = totalHours % 24
    
        -- ...existing waitForUI and other setup code...
    
        local descFormat = string.format(
            -- ...existing format string but with time info...
            "🔒・Username : ||%s||\n" ..
            "```md\n#Profile\n" ..
            "💎・Gems : %s\n" ..
            "🟡・Gold : %s\n" ..
            "🧪・Level : %s\n" ..
            "🔋・Battle Pass : %s [%s]" ..
            "```\n" ..
            "```md\n#Game Information\n" ..
            "- Result : %s\n" ..
            "- Map : %s\n" ..
            "- Mode : %s\n" ..
            "- Difficulty : %s\n" ..
            "- Wave : %s | Time: %s" ..
            "```\n" ..
            "```md\n#Enemies Killed\n" ..
            "- %d" ..
            "```\n" ..
            "```md\n#Rewards\n" ..
            "◈ %s 💎\n" ..
            "◈ %s 🍀\n" ..
            "%s" ..
            "```\n" ..
            "```md\n#Package Info\n" ..
            "- ฟามเวลาจำนวน : %d วัน : %d ชั่วโมง\n" ..
            "- ดำเนินการแล้ว : [%d ชั่วโมง|%d ชั่วโมง]" ..
            "```\n",
            -- ...existing parameters...
            player.Name,
            stats.GEMS,
            stats.Gold,
            stats.Level,
            currentBP,
            currentBP2,
            InfoGameEnd,
            stats.Title,
            stats.Description,
            stats.Difficulty,
            GetNumberFromString(stats.Wave) or 0,
            GetTimeFromString(stats.Time) or "N/A",
            tonumber(stats.Kills) or 0,
            GemGET,
            stats.XP,
            AllItem,
            totalDays, remainingHours,
            elapsedHours, totalHours
        )
    
        if remainingTime > 0 then
            descFormat = descFormat .. string.format(
                "```md\n- เหลือที่ต้องฟามอีก : %d วัน : %d ชั่วโมง : %d นาที : %d วินาที```\n\n- จ้างโดยคุณ <@%s>",
                days, hours, minutes, seconds,
                DiscordID
            )
        end
    
        -- ส่ง webhook
        local req = http_request or request or HttpPost or syn and syn.request
        if req then
            local BodyJson = {
                content = "",
                embeds = {
                    {
                        title = "** <a:lp:1054740345709146182>  Round Complete! <a:lp:1054740345709146182>  **",
                        description = descFormat,
                        type = "rich",
                        color = 0x33FFCC,
                        image = { url = ThumbnailURL },
                        footer = { icon_url = LogoURLs, text = "PLaNS SHOP" },
                        timestamp = DateTime.now():ToIsoDate()
                    }
                }
            }
    
            req({
                Url = _G.Webhook,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(BodyJson)
            })
        end
    end

    -- เชื่อมต่อกับ RunService
    RunService.Stepped:Connect(function()
        if GameFinished and GameFinished.Value == true then
            task.delay(3.25, function()
                if not WebhookSent then
                    if LocalData.IsTimeMode then
                        SendGameFinishedWebhook2()
                    else
                        SendGameFinishedWebhook()
                    end
                end
            end)
        elseif GameFinished and GameFinished.Value == false then
            WebhookSent = false
        end
    end)
end

--------------------------------------------------------------------------------
-- (I) User Interface
--------------------------------------------------------------------------------

local OrionLib = loadstring(game:HttpGet('https://raw.githubusercontent.com/EmiyaSanZ/Lib/main/UI2.lua'))()


local Window = OrionLib:MakeWindow({
    Name = "PLaNS x SHOP",
    HidePremium = false,
    SaveConfig = true,
    Minimized = true,
    ConfigFolder = "PLaNSConfig"
})


local MainTab = Window:MakeTab({
    Name = "เพชร",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

local SettingsSection = MainTab:AddSection({
    Name = "Settings"
})

SettingsSection:AddTextbox({
    Name = "How many gems?",
    Default = tostring(AddGemsWanted),
    TextDisappear = false,
    Callback = function(Value)
        local addGemsNum = tonumber(Value) or 0
        if addGemsNum > 0 then
            resetModes() -- รีเซ็ตค่าทั้งหมดก่อน
            LocalData.MaxGems = currentGems + math.max(addGemsNum, 0)
            LocalData.AddGemsWanted = addGemsNum
            LocalData.sumGems = addGemsNum
            LocalData.IsTimeMode = false
            saveSettings(LocalData)
        end
    end
})

SettingsSection:AddTextbox({
    Name = "Discord ID",
    Default = DiscordID,
    TextDisappear = false,
    Callback = function(Value)
        LocalData.DiscordID = Value
        DiscordID = Value
        saveSettings(LocalData)
    end
})

SettingsSection:AddToggle({
    Name = "White Screen",
    Default = true,
    Callback = function(Value)
        RunService:Set3dRenderingEnabled(not Value)
    end    
})

SettingsSection:AddButton({
    Name = "Test Webhook",
    Callback = function()
        local testStr = string.format(
            "Test!\nPlayer : ||%s||\n- Gold : %d\n- Level : %s\n- Battle Pass : %s [%s]\n- เพชรตอนนี้ : %d\n- เป้าหมาย : %d\n\n```md\n#Package\n- จำนวนที่ต้องการ : %d gems\n- เหลือฟามเพชรอีก : %d 💎```",
            player.Name, currentGold, currentLevel, currentBP, currentBP2,
            currentGems, LocalData.MaxGems, LocalData.AddGemsWanted, LocalData.sumGems
        )
        sendWebhook2("<a:alert:1021734820461674527> Test Notification <a:alert:1021734820461674527>", testStr)
    end    
})

OrionLib:Init()

-- ...existing code...----------------------------------------------------------

-- เพิ่ม Tab นับเวลา
local TimeTab = Window:MakeTab({
    Name = "นับเวลา",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})


local TimeSection = TimeTab:AddSection({
    Name = "Settings"
})

-- แก้ไข Callback ของ textbox นับเวลา
TimeSection:AddTextbox({
    Name = "นับเวลาถอยหลังกี่ชั่วโมง?",
    Default = "0",
    TextDisappear = false,
    Callback = function(Value)
        local hours = tonumber(Value) or 0
        if hours > 0 then
            resetModes() -- รีเซ็ตค่าทั้งหมดก่อน
            LocalData.TimeWanted = hours * 3600
            LocalData.StartTime = os.time()
            LocalData.IsTimeMode = true
            LocalData.WebhookSent = false -- เพิ่มการรีเซ็ตอีกครั้งเพื่อความแน่ใจ
            WebhookSent = false -- เพิ่มการรีเซ็ตตัวแปร global
            saveSettings(LocalData)
        end
    end
})

TimeSection:AddTextbox({
    Name = "Discord ID",
    Default = DiscordID,
    TextDisappear = false,
    Callback = function(Value)
        LocalData.DiscordID = Value
        DiscordID = Value
        saveSettings(LocalData)
    end
})

TimeSection:AddButton({
    Name = "Test Webhook",
    Callback = function()
        if LocalData.TimeWanted > 0 then
            local currentTime = os.time()
            local elapsedTime = currentTime - LocalData.StartTime
            local remainingTime = math.max(0, LocalData.TimeWanted - elapsedTime)
            
            local days = math.floor(remainingTime / 86400)
            local hours = math.floor((remainingTime % 86400) / 3600)
            local minutes = math.floor((remainingTime % 3600) / 60)
            local seconds = remainingTime % 60
            
            local timeStr = string.format(
                "Test!\nPlayer : ||%s||\n- Gem : %d\n- Gold : %d\n- Level : %s\n- Battle Pass : %s [%s]\n\n```md\n#Time Remaining\n- คงเหลือที่ต้องฟาม %d วัน : %d ชั่วโมง : %d นาที : %d วินาที```",
                player.Name, currentGems, currentGold, currentLevel, currentBP, currentBP2,
                days, hours, minutes, seconds
            )
            sendWebhook2("<a:alert:1021734820461674527> Test Time Notification <a:alert:1021734820461674527>", timeStr)
        end
    end    
})

-- เพิ่มระบบนับเวลาถอยหลัง
spawn(function()
    while wait(1) do
        if LocalData and LocalData.IsTimeMode and LocalData.TimeWanted > 0 then
            local currentTime = os.time()
            if not LocalData.StartTime then 
                LocalData.StartTime = currentTime 
                saveSettings(LocalData)
            end
            
            local elapsedTime = currentTime - LocalData.StartTime
            local remainingTime = math.max(0, LocalData.TimeWanted - elapsedTime)
            
            -- คำนวณเวลาที่เหลือ
            local days = math.floor(remainingTime / 86400)
            local hours = math.floor((remainingTime % 86400) / 3600)
            local minutes = math.floor((remainingTime % 3600) / 60)
            local seconds = remainingTime % 60
            
            -- คำนวณเวลาทั้งหมด
            local totalHours = math.floor(LocalData.TimeWanted / 3600)
            local totalDays = math.floor(totalHours / 24)
            local remainingHours = totalHours % 24
            
            -- คำนวณเวลาที่ผ่านไป
            local elapsedHours = math.floor(elapsedTime / 3600)
            local elapsedDays = math.floor(elapsedHours / 24)
            
            -- เช็คว่าหมดเวลาและยังไม่ได้ส่ง webhook
            if remainingTime <= 0 and not LocalData.WebhookSent and not WebhookSent then
                LocalData.WebhookSent = true
                WebhookSent = true
                saveSettings(LocalData)
                
                task.spawn(function()
                    local success = sendWebhookEnd2(
                        "⏰ หมดเวลาฟามแล้ว! ⏰",
                        string.format(
                            "🔒・Username : ||**%s**||\n" ..
                            "```md\n#Profile\n" ..
                            "💎・Gems : %d\n" ..
                            "🟡・Gold : %d\n" ..
                            "🧪・Level : %s\n" ..
                            "🔋・Battle Pass : %s [%s]\n" ..
                            "```\n" ..
                            "```md\n#Time Complete!\n" ..
                            "- เวลาที่ตั้งไว้ : [%d วัน : %d ชั่วโมง]\n" ..
                            "- เวลาที่ใช้ไป : [%d วัน : %d ชั่วโมง]\n" ..
                            "- สถานะ : ✅ ครบกำหนดเวลาแล้ว!\n" ..
                            "```\n\n" ..
                            "```md\n#Package Info\n" ..
                            "- ค่าบริการ : ฟาม %d วัน : %d ชั่วโมง\n" ..
                            "```\n\n" ..
                            "อย่าลืมรีวิวด้วยน้า·ʚ♡ɞ·\n[ฝาก +1 โปร์ไฟล์เฟสด้วยงับ](https://www.facebook.com/photo/?fbid=817544902138722&set=a.117678525458700)\n\n" ..
                            "<a:emoji_98_jk:1054831096929452042> ขอบคุณที่ใช้บริการน้า <a:8699rightrainbowstar:1054740408434966588>",
                            player.Name,
                            currentGems,
                            currentGold,
                            currentLevel,
                            currentBP,
                            currentBP2,
                            totalDays, remainingHours,
                            elapsedDays, elapsedHours % 24,
                            totalDays, remainingHours
                        )
                    )
                    
                    -- รีเซ็ตค่าหลังจากส่ง webhook
                    if success then
                        LocalData.TimeWanted = 0
                        LocalData.StartTime = 0
                        LocalData.IsTimeMode = false
                        saveSettings(LocalData)
                    else
                        LocalData.WebhookSent = false
                        WebhookSent = false
                        saveSettings(LocalData)
                    end
                end)
            end

            -- อัพเดท UI Label ถ้ามี
            if TimeSection and TimeSection.Label then
                TimeSection.Label.Text = string.format("%d วัน : %02d:%02d:%02d", days, hours, minutes, seconds)
            end
        end
    end
end)
