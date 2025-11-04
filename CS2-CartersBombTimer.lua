-- CS2 Bomb Timer (FFI + Schema) - Carter-style visuals
-- Redone visuals to match Carter's Bomb Timer (size, layout, fonts, colors)
-- Uses CS2 schema fields where available, with legacy fallbacks for robustness.

-- GUI: Visuals -> Carter's Bomb Timer controls for position (X,Y)

-- Notes on visuals (matching Carter):
-- - Panel: 125x67 at (X,Y), dark background 20,20,20,210
-- - Bomb icon: 60x50 slot drawn at (X-8, Y)
-- - Timer label: Bahnschrift 17 at (X+38, Y-2), white
-- - Damage label: Bahnschrift 15 at (X+38, Y+15), grey/red for fatal
-- - Main bar: 121x10 at (X+2, Y+55), color green/yellow/red based on seconds left
-- - Defuse bar: 121x4 at (X+2, Y+61), blue if defuse in time else yellow

local ffi = ffi
local C = ffi.C
ffi.cdef[[
    void* GetModuleHandleA(const char*);
]]

-- Fixed position (no GUI window)
local function getX() return 30 end
local function getY() return 350 end

-- Fonts
local font_secs, font_dmg
-- Drag state
local is_dragging = false
local drag_dx, drag_dy = 0, 0

-- Planting state for stability across frames
local planting_active = false
local plant_last_seen = 0
local plant_grace = 0.25 -- seconds to keep showing after signal drops briefly
local function ensure_fonts()
    if not font_secs then font_secs = draw.CreateFont("Bahnschrift", 17, 500) end
    if not font_dmg  then font_dmg  = draw.CreateFont("Bahnschrift", 14, 500) end
end

-- Bomb icon (Carter asset)
local bomb_tex, bomb_w, bomb_h = nil, 0, 0
local function ensure_bomb_texture()
    if bomb_tex ~= nil then return end
    if not http or not common or not draw.CreateTexture then return end
    local url = "https://raw.githubusercontent.com/G-A-Development-Team/AA-Bomb-Timer/main/bomb3.png"
    local data = http.Get(url)
    if not data or #data == 0 then return end
    local rgba, w, h = common.DecodePNG(data)
    if rgba and w and h then
        bomb_tex = draw.CreateTexture(rgba, w, h)
        bomb_w, bomb_h = w, h
    end
end
local function draw_bomb_icon(x, y)
    if not bomb_tex then return end
    local slot_w, slot_h = 60, 50
    local scale = math.min(slot_w / bomb_w, slot_h / bomb_h)
    local dw, dh = math.floor(bomb_w * scale), math.floor(bomb_h * scale)
    local ox = math.floor((slot_w - dw) / 2)
    local oy = math.floor((slot_h - dh) / 2)
    draw.SetTexture(bomb_tex)
    draw.Color(255, 255, 255, 255)
    draw.FilledRect(x - 8 + ox, y + oy, x - 8 + ox + dw, y + oy + dh)
    draw.SetTexture(nil)
end

-- Events (Carter behavior)
client.AllowListener("bomb_planted")
client.AllowListener("bomb_begindefuse")
client.AllowListener("bomb_abortdefuse")
client.AllowListener("bomb_exploded")
client.AllowListener("round_officially_ended")
client.AllowListener("bomb_defused")
client.AllowListener("round_start")
client.AllowListener("round_freeze_end")

local timePlanted, defusing, ended = 0, false, false
callbacks.Register("FireGameEvent", function(event)
    local name = event:GetName()
    if name == "bomb_planted" then timePlanted = globals.CurTime(); ended = false end
    if name == "bomb_begindefuse" then defusing = true; ended = false end
    if name == "bomb_abortdefuse" then defusing = false; ended = false end
    if name == "bomb_defused" or name == "bomb_exploded" or name == "round_officially_ended" then ended = true end
    if name == "round_start" or name == "round_freeze_end" then
        -- Reset planting state between rounds to avoid stale conditions
        timePlanted = 0
        defusing = false
        ended = false
    end
end)

-- Helpers
local function get_planted_c4()
    local list = entities.FindByClass and entities.FindByClass("C_PlantedC4") or nil
    if not list or not list[1] then list = entities.FindByClass and entities.FindByClass("CPlantedC4") or nil end
    if list and list[1] then return list[1] end
    return nil
end
local function safe_call(ent, method, name)
    if not ent or not method or not ent[method] then return nil end
    local ok, res = pcall(function() return ent[method](ent, name) end)
    if ok then return res end
    return nil
end

local function get_float(ent, name)
    local v = safe_call(ent, 'GetFieldFloat', name)
    if type(v) ~= 'number' then v = safe_call(ent, 'GetFieldFloat', name) end
    if type(v) ~= 'number' then v = safe_call(ent, 'GetField', name) end
    if type(v) ~= 'number' then v = safe_call(ent, 'GetField', name) end
    if type(v) == 'number' then return v end
    return 0
end
local function get_bool(ent, name)
    local v = safe_call(ent, 'GetFieldBool', name)
    if type(v) ~= 'boolean' then v = safe_call(ent, 'GetFieldBool', name) end
    if type(v) ~= 'boolean' then v = safe_call(ent, 'GetField', name) end
    if type(v) ~= 'boolean' then v = safe_call(ent, 'GetField', name) end
    if type(v) == 'boolean' then return v end
    if type(v) == 'number' then return v ~= 0 end
    return false
end

-- Map-specific bomb radius (from BombAPIV2)
local g_bombradius_map = {
    ["maps/de_ancient.vpk"]  = 650 * 3.5,
    ["maps/de_anubis.vpk"]   = 450 * 3.5,
    ["maps/de_assembly.vpk"] = 500 * 3.5,
    ["maps/de_inferno.vpk"]  = 620 * 3.5,
    ["maps/de_mills.vpk"]    = 500 * 3.5,
    ["maps/de_mirage.vpk"]   = 650 * 3.5,
    ["maps/de_nuke.vpk"]     = 650 * 3.5,
    ["maps/de_overpass.vpk"] = 650 * 3.5,
    ["maps/de_thera.vpk"]    = 500 * 3.5,
    ["maps/de_vertigo.vpk"]  = 500 * 3.5,
}
local function GetBombRadius()
    local map = engine and engine.GetMapName and engine.GetMapName() or nil
    return (map and g_bombradius_map[map]) or 1750
end

-- Damage calculation (CS2-consistent)
local function BombDamage(Bomb, Player)
    if not Bomb or not Player then return 0 end
    local ppos = Player:GetAbsOrigin()
    local bpos = Bomb:GetAbsOrigin()
    if not ppos or not bpos then return 0 end

    -- Add view offset to player's origin like BombAPIV2
    local view = (Player.GetFieldVector and Player:GetFieldVector("m_vecViewOffset")) or {x=0,y=0,z=0}
    local px = ppos.x + (view.x or 0)
    local py = ppos.y + (view.y or 0)
    local pz = ppos.z + (view.z or 0)
    local dx = bpos.x - px
    local dy = bpos.y - py
    local dz = bpos.z - pz
    local flDistance = math.sqrt(dx*dx + dy*dy + dz*dz)

    local flBombRadius = GetBombRadius()
    -- Formula from BombAPIV2
    local flDamage = (flBombRadius / 3.5) * math.exp((flDistance * flDistance) / (-2 * (flBombRadius / 3) * (flBombRadius / 3)))

    local armor = (Player.GetFieldInt and Player:GetFieldInt("m_ArmorValue")) or (Player.GetField and Player:GetField("m_ArmorValue")) or 0
    armor = tonumber(armor) or 0
    if armor == 0 then
        return math.max(flDamage, 0)
    end

    local flReducedDamage = flDamage / 2
    if armor < flReducedDamage then
        local flFraction = armor / flReducedDamage
        return math.max((flFraction * flReducedDamage) + (1 - flFraction) * flDamage, 0)
    end
    return math.max(flReducedDamage, 0)
end

-- Find the C4 weapon to detect planting state
local function get_c4_weapon()
    local bombs = entities.FindByClass("C_C4")
    if bombs == nil then return nil end
    for i = 1, #bombs do
        if not bombs[i]:GetFieldBool("m_bBombPlanted") then
            return bombs[i]
        end
    end
    return nil 
end

-- Color selection for timer bar
local function color_for_time(seconds)
    if seconds <= 5 then return 240, 20, 0 end          -- Red
    if seconds <= 10 then return 210, 150, 0 end        -- Yellow
    return 6, 176, 37                                   -- Green
end

-- Draw panel and elements identically to Carter's layout
-- HSV to RGB helper for rainbow border
local function hsv_to_rgb(h, s, v)
    h = h % 1.0
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    local r, g, b
    if i % 6 == 0 then r, g, b = v, t, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    else r, g, b = v, p, q end
    return math.floor(r*255), math.floor(g*255), math.floor(b*255)
end

local function draw_panel(x, y, w, h)
    -- Animated rainbow outer glow border
    local t = globals.CurTime() or 0
    local hue = (t * 0.4) % 1.0
    local segments = 20
    local thickness = 2
    for i=0,segments-1 do
        local hseg = (hue + i/segments) % 1.0
        local r,g,b = hsv_to_rgb(hseg, 1, 1)
        draw.Color(r, g, b, 180)
        -- top
        local x0 = x + math.floor(i * (w/segments))
        local x1 = x + math.floor((i+1) * (w/segments))
        draw.FilledRect(x0, y - thickness, x1, y)
        -- bottom
        draw.FilledRect(x0, y + h, x1, y + h + thickness)
        -- left
        local y0 = y + math.floor(i * (h/segments))
        local y1 = y + math.floor((i+1) * (h/segments))
        draw.FilledRect(x - thickness, y0, x, y1)
        -- right
        draw.FilledRect(x + w, y0, x + w + thickness, y1)
    end

    -- Background (no rounded edges in Carter's 10 style)
    draw.Color(20, 20, 20, 210)
    draw.FilledRect(x, y, x + w, y + h)
end

local function on_draw()
    -- Ensure window is created; leave visibility managed by the UI system
    -- If you still don't see it, press INSERT (Aimware default) to open the menu.
    ensure_fonts()
    ensure_bomb_texture()

    -- Sync GUI position with dragging paradigm (if any in host); fallback to editbox values
    local x, y = getX(), getY()

    -- Drag interaction over the panel area when menu is open
    local W, H = 125, 67
    if gui.IsMenuOpen and gui.IsMenuOpen() then
        local mx, my = input.GetMousePos()
        local hovering = mx >= x and mx <= x + W and my >= y and my <= y + H
        if hovering and input.IsButtonDown(1) then
            if not is_dragging then
                is_dragging = true
                drag_dx = mx - x
                drag_dy = my - y
            end
        else
            if is_dragging and not input.IsButtonDown(1) then
                is_dragging = false
            end
        end
        if is_dragging then
            x = mx - drag_dx
            y = my - drag_dy
            bt_x:SetValue(x)
            bt_y:SetValue(y)
        end
    end

    if ended then
        -- Hide if ended, but still keep UI position editable
        return
    end

    local bomb = get_planted_c4()
    -- If no planted bomb, show planting UI if arming C4
    if not bomb then
        -- Local-only planting: show when the local player's C4 is being armed
        local wpn = get_c4_weapon()
        if wpn then
            local arming = get_bool(wpn, "m_bStartedArming")
            local via_use = get_bool(wpn, "m_bIsPlantingViaUse")
            local armed_time = get_float(wpn, "m_fArmedTime")
            local cur = globals.CurTime()
            local plant_left = math.max(0, armed_time - cur)

            if (arming or via_use) and plant_left > 0 then
                local W, H = 125, 67
                draw_panel(x, y, W, H)
                draw_bomb_icon(x, y)

                -- Planting label aligned with damage/fatal text
                ensure_fonts()
                draw.SetFont(font_dmg)
                draw.Color(255, 225, 170, 255)
                local tstr = string.format("Planting: %.1f", plant_left)
                draw.Text(x + 41, y + 21, tstr .. "s")

                -- Progress bar (orange)
                local bar_w, bar_h = 121, 10
                local bar_x, bar_y = x + 2, y + 55
                local total_len = 2.5
                local prog = 1 - (plant_left / total_len)
                if prog ~= prog then prog = 0 end
                prog = math.max(0, math.min(1, prog))
                draw.Color(255, 170, 60, 70)
                draw.FilledRect(bar_x - 2, bar_y - 2, bar_x + math.floor(bar_w * prog) + 2, bar_y + bar_h + 2)
                draw.Color(255, 170, 60, 255)
                draw.FilledRect(bar_x, bar_y, bar_x + math.floor(bar_w * prog), bar_y + bar_h)
                return
            end
        end
        return
    end

    -- Read timers from schema/props
    local cur = globals.CurTime()
    local blow_time = get_float(bomb, "m_flC4Blow")
    local timer_length = get_float(bomb, "m_flTimerLength")
    if timer_length <= 0 then timer_length = 40 end

    local time_left = math.max(0, blow_time - cur)

    -- Base panel
    local W, H = 125, 67
    draw_panel(x, y, W, H)

    -- Bomb icon
    draw_bomb_icon(x, y)

    -- Timer label (secs with one decimal; ensure trailing .0)
    draw.SetFont(font_secs)
    draw.Color(255, 255, 255, 255)
    local tstr = string.format("%.1f", time_left)
    if not string.find(tstr, "%.") then tstr = tstr .. ".0" end
    draw.Text(x + 45, y + 8, tstr .. "s")

    -- Damage label
    local me = entities.GetLocalPlayer and entities.GetLocalPlayer() or nil
    local dmg = (me and BombDamage(bomb, me)) or 0
    local hp = (me and me.GetHealth and me:GetHealth()) or 0
    local fatal = hp > 0 and dmg >= hp
    draw.SetFont(font_dmg)
    if fatal then
        draw.Color(240, 20, 0, 255)
        draw.Text(x + 45, y + 28, "Fatal")
    else
        draw.Color(141, 141, 141, 255)
        draw.Text(x + 45, y + 28, string.format("%d damage", math.floor(0.5 + dmg)))
    end

    -- Main progress bar (121x10 at (x+2,y+55)); background transparent in Carter, but we can omit
    local bar_w, bar_h = 121, 10
    local bar_x, bar_y = x + 2, y + 55

    -- Compute progress by remaining time mapped to [0,timer_length]
    local prog_value = math.max(0, math.min(timer_length, time_left))
    local r, g, b = color_for_time(time_left)

    -- Track background (transparent)
    -- Fill progressed amount
    draw.Color(r, g, b, 70)
    draw.FilledRect(bar_x - 2, bar_y - 2, bar_x + math.floor(bar_w * ((timer_length - prog_value) / timer_length)) + 2, bar_y + bar_h + 2)
    draw.Color(r, g, b, 255)
    draw.FilledRect(bar_x, bar_y, bar_x + math.floor(bar_w * ((timer_length - prog_value) / timer_length)), bar_y + bar_h)

    -- Defuse bar below (121x4 at (x+2,y+61)) if defusing
    local being_defused = get_bool(bomb, "m_bBeingDefused") or defusing
    local def_len = get_float(bomb, "m_flDefuseLength")
    local def_end = get_float(bomb, "m_flDefuseCountDown")

    local def_bar_w, def_bar_h = 121, 4
    local def_bar_x, def_bar_y = x + 2, y + 61

    if being_defused and def_len > 0 and def_end > 0 then
        local def_left = math.max(0, def_end - cur)
        local def_prog = math.max(0, math.min(1, 1 - (def_left / def_len)))
        local can_defuse = time_left >= def_left
        local dr, dg, db = (can_defuse and 0 or 210), (can_defuse and 135 or 150), (can_defuse and 255 or 0)
        if can_defuse then dr, dg, db = 0, 135, 255 else dr, dg, db = 210, 150, 0 end
        draw.Color(dr, dg, db, 60)
        draw.FilledRect(def_bar_x - 1, def_bar_y - 1, def_bar_x + math.floor(def_bar_w * def_prog) + 1, def_bar_y + def_bar_h + 1)
        draw.Color(dr, dg, db, 255)
        draw.FilledRect(def_bar_x, def_bar_y, def_bar_x + math.floor(def_bar_w * def_prog), def_bar_y + def_bar_h)
    end
end

callbacks.Register("Draw", on_draw)
callbacks.Register("Unload", function() end)

print("[bomb_timer_ffi] Loaded Carter-style visuals for CS2 bomb timer.")
