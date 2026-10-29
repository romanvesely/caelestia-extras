-- caelestia-extras: key bind and labels for the keybind overview (cheatsheet feature).
--
-- Copy this file to ~/.config/caelestia/extras-cheatsheet.lua and add to
-- ~/.config/caelestia/hypr-user.lua:
--
--   require("extras-cheatsheet").setup()
--
-- Options (all optional):
--
--   require("extras-cheatsheet").setup({
--       keys = "SUPER + H",   -- key that opens and closes the overview
--       extra = {             -- labels for your own binds
--           { title = "Apps", binds = {
--               { desc = "Mail", keys = "SUPER + A" },
--           } },
--           { title = "Mine", icon = "star", binds = {
--               { desc = "Dictation", keys = { "SUPER + Z", "SUPER + SHIFT + Z" } },
--           } },
--       },
--   })
--
-- An extra category with the title of a built-in one adds to it. Icons are
-- Material Symbols names. Your labels win over the built-in ones for the same
-- keys. Binds without a label are still shown, under "Other".
--
-- The labels are written to $XDG_RUNTIME_DIR/caelestia-cheatsheet.json on every
-- config reload. Entries whose keys are not bound right now are hidden, so a
-- changed key in hypr-vars.lua shows up by itself.

local M = {}

-- "ctrl + super + q" / "SUPER + CTRL + Q" -> "CTRL + SUPER + q" (same order as the overview)
local MOD_ORDER = { SHIFT = 1, CTRL = 2, ALT = 3, SUPER = 4 }
local MOD_ALIAS = { CONTROL = "CTRL", MOD4 = "SUPER", WIN = "SUPER", MOD1 = "ALT" }

local function normalise_combo(combo)
    local mods, key = {}, nil
    for raw in combo:gmatch("[^+]+") do
        local part = raw:match("^%s*(.-)%s*$")
        local up = part:upper()
        up = MOD_ALIAS[up] or up
        if MOD_ORDER[up] then
            mods[#mods + 1] = up
        elseif part ~= "" then
            key = part:lower()
        end
    end
    table.sort(mods, function(a, b) return MOD_ORDER[a] < MOD_ORDER[b] end)
    mods[#mods + 1] = key or ""
    return table.concat(mods, " + ")
end

-- vars.kb* can be a string, a list or nil
local function combos(...)
    local out = {}
    local function add(v)
        if type(v) == "table" then
            for _, x in ipairs(v) do add(x) end
        elseif type(v) == "string" and v:match("%S") then
            out[#out + 1] = v
        end
    end
    for i = 1, select("#", ...) do add(select(i, ...)) end
    return out
end

-- entry for a Caelestia bind: shown keys = matched keys
local function B(desc, ...)
    local keys = combos(...)
    return { desc = desc, keys = keys, match = keys }
end

-- entry for an own bind: wins over a Caelestia entry with the same keys
local function O(desc, ...)
    local b = B(desc, ...)
    b.own = true
    return b
end

-- entry for "<prefix> + 1 … 0" (workspaces)
local function RANGE(desc, prefix)
    if type(prefix) ~= "string" or not prefix:match("%S") then
        return nil
    end
    local match = {}
    for ws = 1, 10 do
        match[#match + 1] = prefix .. " + " .. tostring(ws % 10)
    end
    return { desc = desc, keys = { prefix .. " + 1…0" }, match = match }
end

-- the binds of caelestia-dots (hypr/hyprland/keybinds.lua)
local function defaults(vars, keys)
    return {
        { title = "Shell & system", icon = "dashboard", binds = {
            B("Launcher", vars.kbLauncher),
            O("Keybind overview", keys),
            B("Power menu", vars.kbSession),
            B("Sidebar", vars.kbShowSidebar),
            B("All panels", vars.kbShowPanels),
            B("Clear notifications", vars.kbClearNotifs),
            B("Lock", vars.kbLock),
            B("Restore lock", vars.kbRestoreLock),
            B("Sleep", vars.kbSleep),
            B("Restart shell", "CTRL + SUPER + ALT + R"),
            B("Kill shell", "CTRL + SUPER + SHIFT + R"),
            B("Test notification", "SUPER + ALT + F12"),
        } },
        { title = "Apps", icon = "apps", binds = {
            B("Terminal", vars.kbTerminal),
            B("Browser", vars.kbBrowser),
            B("Editor", vars.kbEditor),
            B("Files", vars.kbFileExplorer),
            B("Audio settings", vars.kbAudioSettings),
        } },
        { title = "Special workspaces", icon = "star", binds = {
            B("Special workspace", vars.kbSpecialWs),
            B("Communication", vars.kbCommunicationWs),
            B("Music", vars.kbMusicWs),
            B("Todo", vars.kbTodoWs),
            B("System monitor", vars.kbSystemMonitorWs),
            B("Window in", vars.kbMoveWinToWsSpecial),
            B("Window out", vars.kbMoveWinFromWsSpecial),
        } },
        { title = "Workspaces", icon = "grid_view", binds = {
            RANGE("Go to workspace 1–10", vars.kbGoToWs),
            B("Next workspace", vars.kbNextWs),
            B("Previous workspace", vars.kbPrevWs),
            RANGE("Go to group 1–10", vars.kbGoToWsGroup),
            B("Next group", vars.kbNextWsGroup),
            B("Previous group", vars.kbPrevWsGroup),
        } },
        { title = "Move windows", icon = "move_down", binds = {
            RANGE("To workspace 1–10", vars.kbMoveWinToWs),
            RANGE("Send, stay here", vars.kbMoveWinToWsSilent),
            RANGE("To group 1–10", vars.kbMoveWinToWsGroup),
            B("Next workspace", vars.kbMoveWinToWsNext),
            B("Previous workspace", vars.kbMoveWinToWsPrev),
        } },
        { title = "Windows", icon = "select_window", binds = {
            B("Close", vars.kbCloseWindow),
            B("Focus", "SUPER + Left", "SUPER + Right", "SUPER + Up", "SUPER + Down"),
            B("Move", "SUPER + SHIFT + Left", "SUPER + SHIFT + Right", "SUPER + SHIFT + Up", "SUPER + SHIFT + Down"),
            B("Next window", vars.kbWindowCycleNext),
            B("Previous window", vars.kbWindowCyclePrev),
            B("Drag", vars.kbMoveWindow, "SUPER + mouse:272"),
            B("Drag to resize", vars.kbResizeWindow, "SUPER + mouse:273"),
        } },
        { title = "Window state", icon = "aspect_ratio", binds = {
            B("Floating", vars.kbToggleWindowFloating),
            B("Fullscreen", vars.kbWindowFullscreen),
            B("Maximise", vars.kbWindowBorderedFullscreen),
            B("Pin to all workspaces", vars.kbPinWindow),
            B("Picture in picture", vars.kbWindowPip),
            B("Centre", vars.kbCenterWindow),
            B("Normal size", vars.kbNormalizeWindow),
            B("Narrower", vars.kbWindowDecreaseWidth),
            B("Wider", vars.kbWindowIncreaseWidth),
            B("Shorter", vars.kbWindowDecreaseHeight),
            B("Taller", vars.kbWindowIncreaseHeight),
        } },
        { title = "Groups", icon = "tab", binds = {
            B("Toggle group", vars.kbToggleGroup),
            B("Leave group", vars.kbUngroup),
            B("Lock group", vars.kbGroupLockActive),
            B("Next tab", vars.kbWindowGroupCycleNext),
            B("Previous tab", vars.kbWindowGroupCyclePrev),
        } },
        { title = "Media", icon = "music_note", binds = {
            B("Play/Pause", vars.kbMediaToggle, "XF86AudioPlay", "XF86AudioPause"),
            B("Next track", vars.kbMediaNext, "XF86AudioNext"),
            B("Previous track", vars.kbMediaPrev, "XF86AudioPrev"),
            B("Stop", vars.kbMediaStop, "XF86AudioStop"),
            B("Mute", vars.kbVolumeMute, "XF86AudioMute"),
            B("Mute microphone", "XF86AudioMicMute"),
            B("Volume", "XF86AudioRaiseVolume", "XF86AudioLowerVolume"),
            B("Brightness", "XF86MonBrightnessUp", "XF86MonBrightnessDown"),
        } },
        { title = "Tools", icon = "construction", binds = {
            B("Screenshot", vars.kbScreenshot),
            B("Region, frozen", vars.kbScreenshotFreeze),
            B("Region picker", vars.kbScreenshotRegion),
            B("Record", vars.kbRecord),
            B("Record with sound", vars.kbRecordSound),
            B("Record region", vars.kbRecordRegion),
            B("Colour picker", vars.kbColorPicker),
            B("Clipboard", vars.kbClipboard),
            B("Delete clip", vars.kbClipboardDel),
            B("Type last entry", vars.kbClipboardPasteLatest),
            B("Emoji", vars.kbEmoji),
        } },
    }
end

-- user categories: same title adds to the built-in one, the rest is appended
local function add_extra(categories, extra)
    for _, cat in ipairs(extra or {}) do
        local target
        for _, c in ipairs(categories) do
            if c.title == cat.title then target = c end
        end
        if not target then
            target = { title = cat.title, icon = cat.icon or "keyboard", binds = {} }
            categories[#categories + 1] = target
        end
        for _, b in ipairs(cat.binds or {}) do
            target.binds[#target.binds + 1] = O(b.desc, b.keys)
        end
    end
    return categories
end

-- every key belongs to one entry: own beats Caelestia, then the later one wins
local function resolve_overrides(categories)
    local owner, owner_is_own = {}, {}
    for ci, cat in ipairs(categories) do
        for bi, b in pairs(cat.binds) do
            for _, combo in ipairs(b.match) do
                local n = normalise_combo(combo)
                if b.own or not owner_is_own[n] then
                    owner[n], owner_is_own[n] = ci .. ":" .. bi, b.own or false
                end
            end
        end
    end
    for ci, cat in ipairs(categories) do
        -- RANGE() returns nil for an unset prefix, so the list can have holes
        local kept, last = {}, 0
        for bi in pairs(cat.binds) do
            last = math.max(last, bi)
        end
        for bi = 1, last do
            local b = cat.binds[bi]
            if b then
                local id, match, shown = ci .. ":" .. bi, {}, {}
                for _, combo in ipairs(b.match) do
                    if owner[normalise_combo(combo)] == id then
                        match[#match + 1] = normalise_combo(combo)
                    end
                end
                if b.keys == b.match then
                    for _, combo in ipairs(b.keys) do
                        if owner[normalise_combo(combo)] == id then shown[#shown + 1] = combo end
                    end
                else
                    shown = b.keys
                end
                if #match > 0 then
                    kept[#kept + 1] = { desc = b.desc, keys = shown, match = match }
                end
            end
        end
        cat.binds = kept
    end
    return categories
end

local function json(v)
    if type(v) == "string" then
        return '"' .. v:gsub('[%c"\\]', function(c)
            return ({ ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n" })[c] or ("\\u%04x"):format(c:byte())
        end) .. '"'
    elseif type(v) == "table" then
        local parts = {}
        if v[1] ~= nil or next(v) == nil then
            for _, x in ipairs(v) do parts[#parts + 1] = json(x) end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        for k, x in pairs(v) do parts[#parts + 1] = json(tostring(k)) .. ":" .. json(x) end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return tostring(v)
end

function M.setup(opts)
    opts = opts or {}
    local keys = opts.keys or "SUPER + H"
    local vars = require("variables")

    hl.bind(keys, hl.dsp.global("caelestia:cheatsheet"))

    local categories = resolve_overrides(add_extra(defaults(vars, keys), opts.extra))

    -- write to a temp file first, so the shell never reads half a file
    local file = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/caelestia-cheatsheet.json"
    local tmp = io.open(file .. ".tmp", "w")
    if tmp then
        tmp:write(json({ categories = categories }))
        tmp:close()
        os.rename(file .. ".tmp", file)
    end
end

return M
