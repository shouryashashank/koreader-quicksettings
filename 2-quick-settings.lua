-- Quick Settings tab for KOReader top menu
-- Adds a new tab at the far left with Wi-Fi, action buttons, and frontlight/warmth sliders.
-- Works in both File Manager and Book Reader views.
-- Additional buttons for the Quick Settings tab.
-- Adds optional buttons for OPDS Catalog, NotionSync, and Reading Streak.
-- OPDS Catalog is included with KOReader and allows browsing OPDS book catalogs.
-- NotionSync plugin by Cezary Pukownik: https://github.com/CezaryPukownik/notionsync.koplugin
-- Reading Streak plugin by advokatb: https://github.com/advokatb/readingstreak.koplugin

local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Event = require("ui/event")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local IconWidget = require("ui/widget/iconwidget")
local LeftContainer = require("ui/widget/container/leftcontainer")
local Math = require("optmath")
local NetworkMgr = require("ui/network/manager")
local Button = require("ui/widget/button")
local ConfirmBox = require("ui/widget/confirmbox")
local ProgressWidget = require("ui/widget/progresswidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local BD = require("ui/bidi")
local _ = require("gettext")
local Screen = Device.screen

local SmoothProgressWidget = ProgressWidget:extend{}

function SmoothProgressWidget:paintTo(bb, x, y)
    local my_size = self:getSize()
    if not self.dimen then
        self.dimen = Geom:new{ x = x, y = y, w = my_size.w, h = my_size.h }
    else
        self.dimen.x = x
        self.dimen.y = y
        self.dimen.w = my_size.w
        self.dimen.h = my_size.h
    end
    if self.dimen.w == 0 or self.dimen.h == 0 then
        return
    end

    local mirrored = BD.mirroredUILayout()
    if self.invert_direction then
        mirrored = not mirrored
    end

    local bar_radius = math.max(0, math.min(self.radius or 0, math.floor(my_size.h / 2), math.floor(my_size.w / 2)))
    bb:paintRoundedRect(x, y, my_size.w, my_size.h, self.bgcolor, bar_radius)
    bb:paintBorder(math.floor(x), math.floor(y), my_size.w, my_size.h, self.bordersize, self.bordercolor, bar_radius)

    local fill_x = x + self.margin_h + self.bordersize
    local fill_y = y + self.margin_v + self.bordersize
    local fill_width = my_size.w - 2 * (self.margin_h + self.bordersize)
    local fill_height = my_size.h - 2 * (self.margin_v + self.bordersize)
    if fill_width <= 0 or fill_height <= 0 then
        return
    end

    if self.percentage and self.percentage >= 0 then
        local perc = math.max(0, math.min(1, self.percentage))
        local inner_w = math.ceil(fill_width * perc)
        if inner_w > 0 then
            local inner_x = fill_x
            if self.fill_from_right or (mirrored and not self.fill_from_right) then
                inner_x = fill_x + (fill_width - inner_w)
            end
            local fill_radius = math.max(0, math.min(math.floor(fill_height / 2), math.floor(inner_w / 2)))
            bb:paintRoundedRect(math.floor(inner_x), math.floor(fill_y), inner_w, fill_height, self.fillcolor, fill_radius)
        end
    end
end

-- ============================================================
-- Configuration
-- ============================================================

local config_default = {
    button_order = { "wifi", "night", "rotate", "usb", "search", "quickrss", "cloud", "zlibrary", "calibre", "notion", "streak", "opds", "restart", "exit", "sleep" },
    show_buttons = {
        wifi = true,
        night = true,
        rotate = true,
        usb = true,
        search = false,
        quickrss = false,
        cloud = false,
        zlibrary = false,
        calibre = false,
        restart = true,
        exit = true,
        sleep = true,
        -- External plugin buttons (disabled by default; enable if plugin is installed)
        notion = false,
        streak = false,
        opds = false,			 
    },
    show_frontlight = true,
    show_warmth = true,
    show_slider_controls = true,
    open_on_start = false,
}

local config

local function loadConfig()
    config = G_reader_settings:readSetting("quick_settings_panel", config_default)
    for k, v in pairs(config_default) do
        if config[k] == nil then
            config[k] = v
        end
    end
    if type(config.show_buttons) == "table" then
        for k, v in pairs(config_default.show_buttons) do
            if config.show_buttons[k] == nil then
                config.show_buttons[k] = v
            end
        end
    else
        config.show_buttons = config_default.show_buttons
    end
    if type(config.button_order) ~= "table" then
        config.button_order = config_default.button_order
    else
        -- Ensure all known buttons are in the order list
        local known = {}
        for _, id in ipairs(config.button_order) do
            known[id] = true
        end
        for _, id in ipairs(config_default.button_order) do
            if not known[id] then
                table.insert(config.button_order, id)
            end
        end
    end
end

local function saveConfig()
    G_reader_settings:saveSetting("quick_settings_panel", config)
end

loadConfig()

-- ============================================================
-- Button definitions (data-driven)
-- ============================================================

local button_defs = {
    wifi = {
        icon = "quick_wifi",
        label = "Wi-Fi",
        label_func = function()
            if NetworkMgr:isWifiOn() then
                local net = NetworkMgr:getCurrentNetwork()
                if net and net.ssid then
                    return net.ssid
                end
            end
            return "Wi-Fi"
        end,
        active_func = function() return NetworkMgr:isWifiOn() end,
        callback = function(touch_menu)
            if NetworkMgr:isWifiOn() then
                NetworkMgr:toggleWifiOff()
            else
                NetworkMgr:toggleWifiOn()
            end
            UIManager:scheduleIn(1, function()
                if touch_menu.item_table and touch_menu.item_table.panel then
                    touch_menu:updateItems(1)
                end
            end)
        end,
    },
    night = {
        icon = "quick_nightmode",
        label = "Night",
        active_func = function() return G_reader_settings:isTrue("night_mode") end,
        callback = function(touch_menu)
            local night_mode = G_reader_settings:isTrue("night_mode")
            Screen:toggleNightMode()
            UIManager:ToggleNightMode(not night_mode)
            G_reader_settings:saveSetting("night_mode", not night_mode)
            touch_menu:updateItems(1)
            UIManager:setDirty("all", "full")
        end,
    },
    rotate = {
        icon = "quick_rotate",
        label = "Rotate",
        callback = function()
            UIManager:broadcastEvent(Event:new("SwapRotation"))
        end,
    },
    usb = {
        icon = "quick_usb",
        label = "USB",
        callback = function()
            if Device:canToggleMassStorage() then
                UIManager:broadcastEvent(Event:new("RequestUSBMS"))
            end
        end,
    },
    restart = {
        icon = "quick_restart",
        label = "Restart",
        callback = function()
            UIManager:show(ConfirmBox:new{
                text = _("Are you sure you want to restart KOReader?"),
                ok_text = _("Restart"),
                ok_callback = function()
                    UIManager:broadcastEvent(Event:new("Restart"))
                end,
            })
        end,
    },
    exit = {
        icon = "quick_exit",
        label = "Exit",
        callback = function()
            UIManager:show(ConfirmBox:new{
                text = _("Are you sure you want to exit KOReader?"),
                ok_text = _("Exit"),
                ok_callback = function()
                    UIManager:broadcastEvent(Event:new("Exit"))
                end,
            })
        end,
    },
    sleep = {
        icon = "quick_sleep",
        label = "Sleep",
        callback = function()
            if Device:canSuspend() then
                UIManager:broadcastEvent(Event:new("RequestSuspend"))
            elseif Device:canPowerOff() then
                UIManager:broadcastEvent(Event:new("RequestPowerOff"))
            end
        end,
    },
    search = {
        icon = "quick_search",
        label = "Search",
        callback = function()
            UIManager:broadcastEvent(Event:new("ShowFileSearch"))
        end,
    },
    quickrss = {
        icon = "quick_quickrss",
        label = "QuickRSS",
        callback = function()
            local ok, QuickRSSUI = pcall(require, "modules/ui/feed_view")
            if ok and QuickRSSUI then
                local view = QuickRSSUI:new{}
                UIManager:show(view)
                view:_fetch()
            else
                local InfoMessage = require("ui/widget/infomessage")
                UIManager:show(InfoMessage:new{
                    text = _("QuickRSS plugin is not installed."),
                })
            end
        end,
    },
    cloud = {
        icon = "quick_cloud",
        label = "Cloud",
        callback = function()
            UIManager:broadcastEvent(Event:new("ShowCloudStorage"))
        end,
    },
    zlibrary = {
        icon = "quick_zlib",
        label = "Z-Lib",
        callback = function()
            UIManager:broadcastEvent(Event:new("ZlibrarySearch"))
        end,
    },
    calibre = {
        icon = "quick_calibre",
        label = "Calibre",
        active_func = function()
            local CW = package.loaded["wireless"]
            return CW ~= nil and CW.calibre_socket ~= nil
        end,
        callback = function(touch_menu)
            local CW = package.loaded["wireless"]
            if CW and CW.calibre_socket ~= nil then
                UIManager:broadcastEvent(Event:new("CloseWirelessConnection"))
            else
                UIManager:broadcastEvent(Event:new("StartWirelessConnection"))
            end
            UIManager:scheduleIn(1, function()
                touch_menu:updateItems(1)
            end)
        end,
    },
	notion = {
        icon = "quick_notion",
        label = "NotionSync",
        callback = function()
            local ok_r, ReaderUI = pcall(require, "apps/reader/readerui")
            local ok_f, FileManager = pcall(require, "apps/filemanager/filemanager")
            local ui = (ok_r and ReaderUI.instance) or (ok_f and FileManager.instance)
            if ui and ui.NotionSync then
                ui.NotionSync:onSyncAllBooksRequested()
            end
        end,
    },
    streak = {
        icon = "quick_streak",
        label = "Streak",
        callback = function()
            UIManager:broadcastEvent(Event:new("ShowReadingStreakCalendar"))
        end,
    },
    opds = {
        icon = "quick_opds",
        label = "OPDS",
        callback = function()
            UIManager:broadcastEvent(Event:new("ShowOPDSCatalog"))
        end,
    },		  
}

-- Display names for the settings menu
local button_display_names = {
    wifi = _("Wi-Fi"),
    night = _("Night mode"),
    rotate = _("Rotate"),
    usb = _("USB"),
    restart = _("Restart"),
    exit = _("Exit"),
    sleep = _("Sleep"),
    search = _("File search"),
    quickrss = _("QuickRSS"),
    cloud = _("Cloud storage"),
    zlibrary = _("Z-Library"),
    calibre = _("Calibre"),
	notion   = _("Notion"),
    streak   = _("Streak"),
    opds     = _("OPDS"),
}

-- ============================================================
-- Panel builder — returns panel widget + refs for tap handling
-- ============================================================

local function createQuickSettingsPanel(touch_menu)
    local panel_width = touch_menu.item_width
    local padding = Screen:scaleBySize(10)
    local inner_width = panel_width - padding * 2
    local powerd = Device:getPowerDevice()

    -- Refs table: stored on touch_menu for gesture handling
    local refs = { buttons = {} }

    -- ----- Top row: action buttons -----

    -- Collect visible buttons in order
    local visible_buttons = {}
    for _, id in ipairs(config.button_order) do
        if config.show_buttons[id] and button_defs[id] then
            table.insert(visible_buttons, { id = id, def = button_defs[id] })
        end
    end

    local num_buttons = #visible_buttons
    local action_btn_size = Screen:scaleBySize(64)
    local icon_size = math.floor(action_btn_size * 0.5)
    local label_font = Font:getFace("xx_smallinfofont")

    -- Active styling
    local normal_border = Screen:scaleBySize(2)

    local function makeActionButton(icon_name, label_text, active)
        local icon = IconWidget:new{
            icon = icon_name,
            width = icon_size,
            height = icon_size,
            alpha = true,
        }
        local circle = FrameContainer:new{
            width = action_btn_size,
            height = action_btn_size,
            radius = math.floor(action_btn_size / 2),
            bordersize = normal_border,
            background = active and Blitbuffer.COLOR_LIGHT_GRAY or Blitbuffer.COLOR_WHITE,
            padding = 0,
            CenterContainer:new{
                dimen = Geom:new{
                    w = action_btn_size - normal_border * 2,
                    h = action_btn_size - normal_border * 2,
                },
                icon,
            },
        }
        local label = TextWidget:new{
            text = label_text,
            face = label_font,
            max_width = action_btn_size + Screen:scaleBySize(4),
        }
        local group = VerticalGroup:new{
            align = "center",
            circle,
            VerticalSpan:new{ width = Screen:scaleBySize(2) },
            label,
        }
        return group, circle
    end

    -- Build button row
    local top_row = HorizontalGroup:new{ align = "center" }

    if num_buttons > 0 then
        local btn_gap = math.floor((inner_width - num_buttons * action_btn_size) / math.max(num_buttons - 1, 1))

        for i, entry in ipairs(visible_buttons) do
            local def = entry.def
            local label_text = def.label
            if def.label_func then
                label_text = def.label_func()
            end
            local active = def.active_func and def.active_func() or false
            local btn_widget, btn_circle = makeActionButton(def.icon, label_text, active)

            table.insert(refs.buttons, {
                widget = btn_circle,
                callback = function()
                    def.callback(touch_menu)
                end,
            })

            table.insert(top_row, btn_widget)
            if i < num_buttons then
                table.insert(top_row, HorizontalSpan:new{ width = btn_gap })
            end
        end
    end

    -- ----- Frontlight section -----

    local slider_label_font = Font:getFace("smallinfofont", 14)
    local small_btn_width = Screen:scaleBySize(40)
    local max_btn_width = Screen:scaleBySize(50)
    local slider_gap = Screen:scaleBySize(4)
    local show_slider_controls = config.show_slider_controls ~= false
    local right_icon_width = max_btn_width
    local left_section_width = inner_width - right_icon_width - slider_gap
    local function sliderTrackWidth()
        if show_slider_controls then
            return left_section_width - 2 * small_btn_width - 2 * slider_gap
        end
        return left_section_width
    end
    local section_span = VerticalSpan:new{ width = Screen:scaleBySize(8) }

    local fl_group = VerticalGroup:new{ align = "center" }

    local function valueToPercentage(state)
        local span = state.max - state.min
        if span <= 0 then
            return 0
        end
        return (state.cur - state.min) / span
    end

    local function makeModernSlider(width, row_height, percentage)
        local slider_height = math.max(Screen:scaleBySize(14), math.floor(row_height * 0.72))
        local slider = SmoothProgressWidget:new{
            width = width,
            height = slider_height,
            percentage = percentage,
            margin_h = Screen:scaleBySize(3),
            margin_v = Screen:scaleBySize(3),
            radius = math.floor(slider_height / 2),
            bordersize = Screen:scaleBySize(1),
            bordercolor = Blitbuffer.COLOR_BLACK,
            fillcolor = Blitbuffer.COLOR_BLACK,
            bgcolor = Blitbuffer.COLOR_WHITE,
        }

        return CenterContainer:new{
            dimen = Geom:new{ w = width, h = row_height },
            slider,
        }, slider
    end

    if config.show_frontlight then
        -- Frontlight state
        local fl = {
            min = powerd.fl_min,
            max = powerd.fl_max,
            cur = powerd:frontlightIntensity(),
        }
        local fl_label = TextWidget:new{
            text = _("Frontlight") .. ": " .. tostring(fl.cur),
            face = slider_label_font,
            max_width = inner_width,
        }
        local fl_label_row = LeftContainer:new{
            dimen = Geom:new{ w = inner_width, h = fl_label:getSize().h },
            fl_label,
        }

        -- Create a probe button to measure target control size
        local fl_probe = Button:new{
            text = "−",
            width = small_btn_width,
            show_parent = touch_menu.show_parent,
            callback = function() end,
        }
        local btn_height = fl_probe:getSize().h
        local slider_row_height = btn_height
        local control_height = math.max(Screen:scaleBySize(26), math.floor(btn_height * 0.74))
        local control_radius = math.floor(control_height / 2)

        local function makeControlButton(text, width, callback)
            return Button:new{
                text = text,
                width = width,
                height = control_height,
                radius = control_radius,
                bordersize = Screen:scaleBySize(1),
                show_parent = touch_menu.show_parent,
                callback = callback,
            }
        end

        local function makeIconControlButton(icon_name, width, callback)
            local icon_size = math.max(Screen:scaleBySize(14), math.floor(slider_row_height * 0.72))
            return Button:new{
                icon = icon_name,
                icon_width = icon_size,
                icon_height = icon_size,
                width = width,
                height = control_height,
                radius = 0,
                bordersize = 0,
                background = Blitbuffer.COLOR_WHITE,
                padding = 0,
                show_parent = touch_menu.show_parent,
                callback = callback,
            }
        end

        local fl_slider_holder, fl_progress = makeModernSlider(
            sliderTrackWidth(),
            slider_row_height,
            valueToPercentage(fl)
        )

        local flGetTriState
        local fl_tri_values
        local fl_tri_icons
        local fl_tri_btn = nil

        flGetTriState = function(cur)
            if cur <= fl.min then
                return 1
            end
            if cur >= fl.max then
                return 3
            end
            return 2
        end

        fl_tri_values = {
            fl.min,
            Math.round((fl.min + fl.max) / 2),
            fl.max,
        }
        fl_tri_icons = {
            "quick_brightness_off",
            "quick_brightness_mid",
            "quick_brightness_max",
        }

        local function updateBrightnessWidgets()
            fl_progress:setPercentage(valueToPercentage(fl))
            fl_label:setText(_("Frontlight") .. ": " .. tostring(fl.cur))
            if fl_tri_btn then
                fl_tri_btn:setIcon(fl_tri_icons[flGetTriState(fl.cur)], max_btn_width)
            end
            UIManager:setDirty(touch_menu.show_parent, "ui")
        end

        local function setBrightness(intensity)
            if intensity ~= fl.min and intensity == fl.cur then return end
            intensity = math.max(fl.min, math.min(fl.max, intensity))
            powerd:setIntensity(intensity)
            fl.cur = powerd:frontlightIntensity()
            updateBrightnessWidgets()
        end

        fl_tri_btn = makeIconControlButton(fl_tri_icons[flGetTriState(fl.cur)], right_icon_width, function()
            local next_state = (flGetTriState(fl.cur) % 3) + 1
            setBrightness(fl_tri_values[next_state])
        end)

        local fl_left_row = HorizontalGroup:new{ align = "center" }
        if show_slider_controls then
            local fl_minus = makeControlButton("−", small_btn_width, function() setBrightness(fl.cur - 1) end)
            local fl_plus = makeControlButton("＋", small_btn_width, function() setBrightness(fl.cur + 1) end)
            table.insert(fl_left_row, fl_minus)
            table.insert(fl_left_row, HorizontalSpan:new{ width = slider_gap })
            table.insert(fl_left_row, fl_slider_holder)
            table.insert(fl_left_row, HorizontalSpan:new{ width = slider_gap })
            table.insert(fl_left_row, fl_plus)
        else
            table.insert(fl_left_row, fl_slider_holder)
        end

        local fl_row = HorizontalGroup:new{
            align = "center",
            fl_tri_btn,
            HorizontalSpan:new{ width = slider_gap },
            LeftContainer:new{
                dimen = Geom:new{ w = left_section_width, h = control_height },
                fl_left_row,
            },
        }

        -- Store progress ref for tap/pan handling
        refs.fl_progress = fl_progress
        refs.fl_state = fl
        refs.setBrightness = setBrightness

        table.insert(fl_group, fl_label_row)
        table.insert(fl_group, section_span)
        table.insert(fl_group, fl_row)
    end

    -- ----- Warmth section (conditional) -----

    local warmth_group = VerticalGroup:new{ align = "center" }
    if config.show_warmth then
        local nl = {
            min = powerd.fl_warmth_min,
            max = powerd.fl_warmth_max,
            cur = powerd:toNativeWarmth(powerd:frontlightWarmth()),
        }

        local warmth_slider_width = sliderTrackWidth()

        local nl_label = TextWidget:new{
            text = _("Warmth") .. ": " .. tostring(nl.cur),
            face = slider_label_font,
            max_width = inner_width,
        }
        local nl_label_row = LeftContainer:new{
            dimen = Geom:new{ w = inner_width, h = nl_label:getSize().h },
            nl_label,
        }

        local nl_probe = Button:new{
            text = "−",
            width = small_btn_width,
            show_parent = touch_menu.show_parent,
            callback = function() end,
        }
        local btn_height = nl_probe:getSize().h
        local slider_row_height = btn_height
        local control_height = math.max(Screen:scaleBySize(26), math.floor(btn_height * 0.74))
        local control_radius = math.floor(control_height / 2)

        local function makeControlButton(text, width, callback)
            return Button:new{
                text = text,
                width = width,
                height = control_height,
                radius = control_radius,
                bordersize = Screen:scaleBySize(1),
                show_parent = touch_menu.show_parent,
                callback = callback,
            }
        end

        local function makeIconControlButton(icon_name, width, callback)
            local icon_size = math.max(Screen:scaleBySize(14), math.floor(slider_row_height * 0.72))
            return Button:new{
                icon = icon_name,
                icon_width = icon_size,
                icon_height = icon_size,
                width = width,
                height = control_height,
                radius = 0,
                bordersize = 0,
                background = Blitbuffer.COLOR_WHITE,
                padding = 0,
                show_parent = touch_menu.show_parent,
                callback = callback,
            }
        end

        local nl_slider_holder, nl_progress = makeModernSlider(
            warmth_slider_width,
            slider_row_height,
            valueToPercentage(nl)
        )

        local nlGetTriState
        local nl_tri_values
        local nl_tri_icons
        local nl_tri_btn = nil

        nlGetTriState = function(cur)
            if cur <= nl.min then
                return 1
            end
            if cur >= nl.max then
                return 3
            end
            return 2
        end

        nl_tri_values = {
            nl.min,
            Math.round((nl.min + nl.max) / 2),
            nl.max,
        }
        nl_tri_icons = {
            "quick_warmth_off",
            "quick_warmth_mid",
            "quick_warmth_max",
        }

        local function setWarmth(warmth)
            if warmth == nl.cur then return end
            warmth = math.max(nl.min, math.min(nl.max, warmth))
            powerd:setWarmth(powerd:fromNativeWarmth(warmth))
            nl.cur = powerd:toNativeWarmth(powerd:frontlightWarmth())
            nl_progress:setPercentage(valueToPercentage(nl))
            nl_label:setText(_("Warmth") .. ": " .. tostring(nl.cur))
            if nl_tri_btn then
                nl_tri_btn:setIcon(nl_tri_icons[nlGetTriState(nl.cur)], max_btn_width)
            end
            UIManager:setDirty(touch_menu.show_parent, "ui")
        end

        nl_tri_btn = makeIconControlButton(nl_tri_icons[nlGetTriState(nl.cur)], right_icon_width, function()
            local next_state = (nlGetTriState(nl.cur) % 3) + 1
            setWarmth(nl_tri_values[next_state])
        end)

        local nl_left_row = HorizontalGroup:new{ align = "center" }
        if show_slider_controls then
            local nl_minus = makeControlButton("−", small_btn_width, function() setWarmth(nl.cur - 1) end)
            local nl_plus = makeControlButton("＋", small_btn_width, function() setWarmth(nl.cur + 1) end)
            table.insert(nl_left_row, nl_minus)
            table.insert(nl_left_row, HorizontalSpan:new{ width = slider_gap })
            table.insert(nl_left_row, nl_slider_holder)
            table.insert(nl_left_row, HorizontalSpan:new{ width = slider_gap })
            table.insert(nl_left_row, nl_plus)
        else
            table.insert(nl_left_row, nl_slider_holder)
        end

        local nl_row = HorizontalGroup:new{
            align = "center",
            nl_tri_btn,
            HorizontalSpan:new{ width = slider_gap },
            LeftContainer:new{
                dimen = Geom:new{ w = left_section_width, h = control_height },
                nl_left_row,
            },
        }

        refs.nl_progress = nl_progress
        refs.nl_state = nl
        refs.setWarmth = setWarmth

        table.insert(warmth_group, VerticalSpan:new{ width = Screen:scaleBySize(14) })
        table.insert(warmth_group, nl_label_row)
        table.insert(warmth_group, section_span)
        table.insert(warmth_group, nl_row)
    end

    -- ----- Assemble panel -----

    local panel = VerticalGroup:new{
        align = "center",
        VerticalSpan:new{ width = Screen:scaleBySize(12) },
    }

    if num_buttons > 0 then
        table.insert(panel, CenterContainer:new{
            dimen = Geom:new{ w = panel_width, h = top_row:getSize().h },
            top_row,
        })
        table.insert(panel, VerticalSpan:new{ width = Screen:scaleBySize(8) })
    end

    if #fl_group > 0 then
        table.insert(panel, fl_group)
    end
    if #warmth_group > 0 then
        table.insert(panel, warmth_group)
    end
    table.insert(panel, VerticalSpan:new{ width = Screen:scaleBySize(8) })

    -- Store refs on the touch_menu for gesture handlers
    touch_menu._qs_refs = refs

    return panel
end

-- ============================================================
-- Gesture handler for panel taps/pans
-- ============================================================

local function handlePanelGesture(touch_menu, ges)
    local refs = touch_menu._qs_refs
    if not refs then return false end

    local function containsGesturePos(widget)
        if not widget or not widget.dimen then
            return false
        end
        local pos = ges.pos
        local start_pos = ges.start_pos
        local end_pos = ges.end_pos
        return (pos and pos:intersectWith(widget.dimen))
            or (start_pos and start_pos:intersectWith(widget.dimen))
            or (end_pos and end_pos:intersectWith(widget.dimen))
    end

    local function sliderPercentageFromGesture(widget)
        if not widget or not widget.dimen then
            return nil
        end

        local candidates = { ges.end_pos, ges.pos, ges.start_pos }
        for _, p in ipairs(candidates) do
            local perc = p and widget:getPercentageFromPosition(p)
            if perc then
                return perc
            end
        end

        local start_pos = ges.start_pos or ges.pos
        local end_pos = ges.end_pos or ges.pos
        if start_pos and end_pos and start_pos:intersectWith(widget.dimen) and end_pos.x then
            local min_x = widget.dimen.x + widget.margin_h
            local max_x = widget.dimen.x + widget.dimen.w - widget.margin_h
            local clamped_pos = {
                x = math.max(min_x, math.min(max_x, end_pos.x)),
                y = end_pos.y,
            }
            return widget:getPercentageFromPosition(clamped_pos)
        end

        return nil
    end

    -- Check frontlight progress bar (tap and swipe)
    if refs.fl_progress and refs.setBrightness and containsGesturePos(refs.fl_progress) then
        local perc = sliderPercentageFromGesture(refs.fl_progress)
        if perc then
            local fl = refs.fl_state
            local new_val = Math.round(fl.min + perc * (fl.max - fl.min))
            refs.setBrightness(new_val)
            return true
        end
    end

    -- Check warmth progress bar (tap and swipe)
    if refs.nl_progress and refs.setWarmth and containsGesturePos(refs.nl_progress) then
        local perc = sliderPercentageFromGesture(refs.nl_progress)
        if perc then
            local nl = refs.nl_state
            local new_val = Math.round(nl.min + perc * (nl.max - nl.min))
            refs.setWarmth(new_val)
            return true
        end
    end

    -- Check buttons
    for _, btn_ref in ipairs(refs.buttons) do
        if btn_ref.widget.dimen and ges.pos:intersectWith(btn_ref.widget.dimen) then
            btn_ref.callback()
            return true
        end
    end

    return false
end

-- ============================================================
-- Hook TouchMenu to support panel tabs
-- ============================================================

local TouchMenu = require("ui/widget/touchmenu")
local FocusManager = require("ui/widget/focusmanager")
local datetime = require("datetime")

-- Hook updateItems for panel rendering
local orig_updateItems = TouchMenu.updateItems

function TouchMenu:updateItems(target_page, target_item_id)
    if not self.item_table or not self.item_table.panel then
        self._qs_refs = nil -- clear refs when switching away from panel tab
        return orig_updateItems(self, target_page, target_item_id)
    end

    -- Custom panel mode: render the panel widget instead of menu items
    self.item_group:clear()
    self.layout = {}
    table.insert(self.item_group, self.bar)
    table.insert(self.layout, self.bar.icon_widgets)

    -- Build panel (also sets self._qs_refs)
    local panel_fn = self.item_table.panel
    local panel = type(panel_fn) == "function" and panel_fn(self) or panel_fn
    table.insert(self.item_group, panel)

    -- Footer (no pagination, just time/battery)
    table.insert(self.item_group, self.footer_top_margin)
    table.insert(self.item_group, self.footer)
    self.page_info_text:setText("")
    self.page_info_left_chev:showHide(false)
    self.page_info_right_chev:showHide(false)

    -- Update time/battery in footer
    local time_info_txt = datetime.secondsToHour(os.time(), G_reader_settings:isTrue("twelve_hour_clock"))
    local powerd = Device:getPowerDevice()
    if Device:hasBattery() then
        local batt_lvl = powerd:getCapacity()
        local batt_symbol = powerd:getBatterySymbol(powerd:isCharged(), powerd:isCharging(), batt_lvl)
        time_info_txt = BD.wrap(time_info_txt) .. " " .. BD.wrap("⌁") .. BD.wrap(batt_symbol) ..  BD.wrap(batt_lvl .. "%")
    end
    self.time_info:setText(time_info_txt)

    -- Recalculate dimen
    local old_dimen = self.dimen:copy()
    self.dimen.w = self.width
    self.dimen.h = self.item_group:getSize().h + self.bordersize * 2 + self.padding
    self:moveFocusTo(self.cur_tab, 1, FocusManager.NOT_FOCUS)

    local keep_bg = old_dimen and self.dimen.h >= old_dimen.h
    UIManager:setDirty((self.is_fresh or keep_bg) and self.show_parent or "all", function()
        local refresh_dimen = old_dimen and old_dimen:combine(self.dimen) or self.dimen
        local refresh_type = "ui"
        if self.is_fresh then
            refresh_type = "flashui"
            self.is_fresh = false
        end
        return refresh_type, refresh_dimen
    end)
end

-- Hook onTapCloseAllMenus to intercept taps on panel widgets
local orig_onTapCloseAllMenus = TouchMenu.onTapCloseAllMenus

function TouchMenu:onTapCloseAllMenus(arg, ges_ev)
    if self._qs_refs and self.item_table and self.item_table.panel then
        if handlePanelGesture(self, ges_ev) then
            return true
        end
    end
    return orig_onTapCloseAllMenus(self, arg, ges_ev)
end

-- Hook switchMenuTab to force quick settings tab on menu open
local orig_switchMenuTab = TouchMenu.switchMenuTab

function TouchMenu:switchMenuTab(tab_num)
    orig_switchMenuTab(self, tab_num)
    -- When "open on start" is enabled, always reset last_index to quick settings tab
    if config.open_on_start then
        self.last_index = 1
    end
end

-- Hook onSwipe to intercept pan/swipe on sliders
local orig_onSwipe = TouchMenu.onSwipe

function TouchMenu:onSwipe(arg, ges_ev)
    if self._qs_refs and self.item_table and self.item_table.panel then
        if handlePanelGesture(self, ges_ev) then
            return true
        end
    end
    if orig_onSwipe then
        return orig_onSwipe(self, arg, ges_ev)
    end
end

-- ============================================================
-- Quick Settings tab definition
-- ============================================================

local quick_settings_tab = {
    icon = "quicksettings",
    remember = false,
    panel = createQuickSettingsPanel,
}

-- ============================================================
-- Settings menu builder
-- ============================================================

local function buildSettingsMenu()
    -- Button toggle sub-items
    local button_toggle_items = {}
    for _, id in ipairs(config_default.button_order) do
        table.insert(button_toggle_items, {
            text = button_display_names[id],
            checked_func = function() return config.show_buttons[id] end,
            callback = function()
                config.show_buttons[id] = not config.show_buttons[id]
                saveConfig()
            end,
        })
    end

    -- Arrange buttons item
    table.insert(button_toggle_items, 1, {
        text = _("Arrange buttons"),
        keep_menu_open = true,
        separator = true,
        callback = function()
            local SortWidget = require("ui/widget/sortwidget")
            local sort_items = {}
            for _, id in ipairs(config.button_order) do
                if button_defs[id] then
                    table.insert(sort_items, {
                        text = button_display_names[id],
                        orig_item = id,
                        dim = not config.show_buttons[id],
                    })
                end
            end
            UIManager:show(SortWidget:new{
                title = _("Arrange quick settings buttons"),
                item_table = sort_items,
                callback = function()
                    for i, item in ipairs(sort_items) do
                        config.button_order[i] = item.orig_item
                    end
                    saveConfig()
                end,
            })
        end,
    })

    return {
        text = _("Quick settings"),
        sub_item_table = {
            {
                text = _("Buttons"),
                sub_item_table = button_toggle_items,
            },
            {
                text = _("Show frontlight slider"),
                checked_func = function() return config.show_frontlight end,
                callback = function()
                    config.show_frontlight = not config.show_frontlight
                    saveConfig()
                end,
            },
            {
                text = _("Show warmth slider"),
                checked_func = function() return config.show_warmth end,
                callback = function()
                    config.show_warmth = not config.show_warmth
                    saveConfig()
                end,
            },
            {
                text = _("Show slider controls (+/−)"),
                checked_func = function() return config.show_slider_controls ~= false end,
                callback = function()
                    config.show_slider_controls = not (config.show_slider_controls ~= false)
                    saveConfig()
                end,
                separator = true,
            },
            {
                text = _("Always open on this tab"),
                checked_func = function() return config.open_on_start end,
                callback = function()
                    config.open_on_start = not config.open_on_start
                    saveConfig()
                end,
            },
        },
    }
end

-- ============================================================
-- Inject tab and settings into both FileManager and Reader menus
-- ============================================================

local FileManagerMenu = require("apps/filemanager/filemanagermenu")
local FileManagerMenuOrder = require("ui/elements/filemanager_menu_order")
local ReaderMenu = require("apps/reader/modules/readermenu")
local ReaderMenuOrder = require("ui/elements/reader_menu_order")

local orig_fm_setUpdateItemTable = FileManagerMenu.setUpdateItemTable

function FileManagerMenu:setUpdateItemTable()
    table.insert(FileManagerMenuOrder.setting, "----------------------------")
    table.insert(FileManagerMenuOrder.setting, "quick_settings_config")
    self.menu_items.quick_settings_config = buildSettingsMenu()
    orig_fm_setUpdateItemTable(self)
    if self.tab_item_table then
        table.insert(self.tab_item_table, 1, quick_settings_tab)
    end
end

local orig_reader_setUpdateItemTable = ReaderMenu.setUpdateItemTable

function ReaderMenu:setUpdateItemTable()
    table.insert(ReaderMenuOrder.setting, "----------------------------")
    table.insert(ReaderMenuOrder.setting, "quick_settings_config")
    self.menu_items.quick_settings_config = buildSettingsMenu()
    orig_reader_setUpdateItemTable(self)
    if self.tab_item_table then
        table.insert(self.tab_item_table, 1, quick_settings_tab)
    end
end
