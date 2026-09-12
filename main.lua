-- Revised main.lua file that fixes stage transition crashes and zombie threads

print("[TekkenRTTDisplay] Loaded.")

local NATIVE_LIVE_FILE = "TekkenRTT_live.txt"
local DISPLAY_PREFIX = "Ping: "

local current_generation = 0
local currently_polling = false
local last_game_disconnect_text = "Disconnection Rate: ?"

-- The global cache variable to replace the heavy FindFirstOf scan
local cached_dialog_obj = nil

local function read_native_live_rtt()
    local file = io.open(NATIVE_LIVE_FILE, "r")
    if not file then return nil end
    local line = file:read("*l")
    file:close()
    return line
end

-- Safely extracts and translates UE4 FText into a standard Lua string
local function read_widget_text(widget_obj)
    local ok, text_value = pcall(function() return widget_obj:GetText() end)
    if ok and text_value ~= nil then
        local ok_str, str_val = pcall(function() return text_value:ToString() end)
        if ok_str and str_val then
            return str_val
        end
    end
    return nil
end

local function start_dialog_polling(dialog_obj, full_name)
    current_generation = current_generation + 1
    local my_generation = current_generation
    
    -- The Kill Switch
    local should_stop = false 
    currently_polling = true

    print("[TekkenRTTDisplay] Live matchmaking dialog found, displaying ping.")

    LoopAsync(500, function()
        if should_stop or (current_generation ~= my_generation) then
            if current_generation == my_generation then 
                currently_polling = false 
            end
            return true
        end

        local rtt_now = read_native_live_rtt() or "??"

        -- Fix #1:
        -- Interacting with UI elements during stage loads causes memory access violations.
        -- We push the UI interaction back to the GameThread.
        ExecuteInGameThread(function()
            local ok_valid, is_valid = pcall(function() return dialog_obj:IsValid() end)
            
            if not ok_valid or not is_valid then
                should_stop = true         
                cached_dialog_obj = nil  
                return                   
            end
            
            local ok_rate, rate_widget = pcall(function() return dialog_obj.TB_DisconnectionRate end)
            if not ok_rate or not rate_widget then return end

            local text_now = read_widget_text(rate_widget)
            if text_now and text_now:sub(1, #DISPLAY_PREFIX) ~= DISPLAY_PREFIX then
                last_game_disconnect_text = text_now
            end

            -- Update the text box on screen (forces update to avoid missing the first ping)
            local combined = DISPLAY_PREFIX .. rtt_now .. " ms | " .. last_game_disconnect_text
            pcall(function() rate_widget:SetText(FText(combined)) end)
        end)
        
        return false
    end)
end

-- ==========================================
-- HOOK 1: Catch brand new matchmaking menus
-- ==========================================
local ok_notify = pcall(function()
    NotifyOnNewObject("/Script/UMG.UserWidget", function(new_widget)
        local ok_name, full_name = pcall(function() return new_widget:GetFullName() end)
        if ok_name and full_name:find("WBP_UI_MatchDialog_Menu_C", 1, true) then
            cached_dialog_obj = new_widget 
            start_dialog_polling(new_widget, full_name)
        end
    end)
end)

if not ok_notify then
    print("[TekkenRTTDisplay] NotifyOnNewObject registration failed")
end

-- ==========================================
-- HOOK 2: Catch recycled menus efficiently 
-- ==========================================
-- Fix #2:
-- The original 'FindFirstOf' scan crashes if it lands during a loading screen.
-- We replaced it with a lightweight cache check pushed to the GameThread.
LoopAsync(2000, function()
    if currently_polling then return false end
    
    ExecuteInGameThread(function()
        local ok_cache, is_valid = pcall(function() return cached_dialog_obj and cached_dialog_obj:IsValid() end)
        
        if ok_cache and is_valid then
            local ok_vis, is_visible = pcall(function() return cached_dialog_obj:IsVisible() end)
            if ok_vis and is_visible then
                start_dialog_polling(cached_dialog_obj, "WBP_UI_MatchDialog_Menu_C_Recycled")
            end
        end
    end)
    
    return false
end)