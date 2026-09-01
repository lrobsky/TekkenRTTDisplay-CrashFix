-- Revised main.lua file that fixes stage transition crashes


print("[TekkenRTTDisplay] Loaded.")

local NATIVE_LIVE_FILE = "TekkenRTT_live.txt"
local DISPLAY_PREFIX = "Ping: "

local current_generation = 0
local currently_polling = false

local last_displayed_rtt = nil
local last_game_disconnect_text = "Disconnection Rate: 0%"
local last_seen_widget_text = nil

local function read_native_live_rtt()
    local file = io.open(NATIVE_LIVE_FILE, "r")
    if not file then return nil end
    local line = file:read("*l")
    file:close()
    if not line or line == "" then return nil end
    return line
end

local function decode_ftext(text_value)
    if text_value == nil then return nil end
    local ok_str, str_value = pcall(function() return text_value:ToString() end)
    if ok_str and str_value ~= nil then
        local ok_tostring, result = pcall(tostring, str_value)
        if ok_tostring then return result end
    end
    return nil
end

local function read_widget_text(widget_obj)
    if not widget_obj then return nil end
    local ok, text_value = pcall(function() return widget_obj:GetText() end)
    if ok and text_value ~= nil then
        return decode_ftext(text_value)
    end
    return nil
end

local function start_dialog_polling(dialog_obj, full_name)
    current_generation = current_generation + 1
    local my_generation = current_generation

    last_seen_widget_text = nil
    last_game_disconnect_text = "Disconnection Rate: 0%"
    last_displayed_rtt = nil
    currently_polling = true

    print("[TekkenRTTDisplay] Live matchmaking dialog found, displaying ping.")

    LoopAsync(500, function()
        if my_generation ~= current_generation then
            return true
        end

        local rtt_now = read_native_live_rtt()
        local should_stop = false

        -- Fix #1 
        -- Interacting with UI elements during stage loads causes memory access violations.
        -- We push the UI interaction back to the GameThread.
        ExecuteInGameThread(function()
            local ok_valid, is_valid = pcall(function() return dialog_obj:IsValid() end)
            if not ok_valid or not is_valid then
                currently_polling = false
                should_stop = true
                return
            end

            local ok_rate, rate_widget = pcall(function() return dialog_obj.TB_DisconnectionRate end)
            if not (ok_rate and rate_widget) then
                return
            end

            local text_now = read_widget_text(rate_widget)
            if text_now ~= nil and text_now ~= last_seen_widget_text then
                last_seen_widget_text = text_now
                if text_now:sub(1, #DISPLAY_PREFIX) ~= DISPLAY_PREFIX then
                    last_game_disconnect_text = text_now
                end
            end

            if rtt_now ~= nil and rtt_now ~= last_displayed_rtt then
                last_displayed_rtt = rtt_now
                local combined = DISPLAY_PREFIX .. rtt_now .. " ms | " .. last_game_disconnect_text
                local ok_set = pcall(function()
                    rate_widget:SetText(FText(combined))
                end)
                if ok_set then
                    last_seen_widget_text = combined
                end
            end
        end)

        return should_stop
    end)
end

local ok_notify = pcall(function()
    NotifyOnNewObject("/Script/UMG.UserWidget", function(new_widget)
        local ok_name, full_name = pcall(function() return new_widget:GetFullName() end)
        if not ok_name or not full_name then return end
        if not full_name:find("WBP_UI_MatchDialog_Menu_C", 1, true) then return end
        if not full_name:find("/Engine/Transient.", 1, true) then return end

        start_dialog_polling(new_widget, full_name)
    end)
end)

if not ok_notify then
    print("[TekkenRTTDisplay] NotifyOnNewObject registration failed")
end

LoopAsync(30000, function()
    if currently_polling then
        return false
    end

    -- Fix #2:
    -- The  original 'FindFirstOf' scan crashes if it lands during a loading screen.
    -- Moving it to the GameThread prevents it from walking memory while it's being deleted.
    ExecuteInGameThread(function()
        local ok_scan, w = pcall(FindFirstOf, "WBP_UI_MatchDialog_Menu_C")
        if ok_scan and w then
            local ok_name, full_name = pcall(function() return w:GetFullName() end)
            if ok_name and full_name and full_name:find("/Engine/Transient.", 1, true) then
                local ok_valid, is_valid = pcall(function() return w:IsValid() end)
                if ok_valid and is_valid then
                    start_dialog_polling(w, full_name)
                end
            end
        end
    end)

    return false
end)