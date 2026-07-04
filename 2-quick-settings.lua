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
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local IconWidget = require("ui/widget/iconwidget")
local LeftContainer = require("ui/widget/container/leftcontainer")
local ok_right_container, RightContainer = pcall(require, "ui/widget/container/rightcontainer")
local Math = require("optmath")
local NetworkMgr = require("ui/network/manager")
local Button = require("ui/widget/button")
local ConfirmBox = require("ui/widget/confirmbox")
local ProgressWidget = require("ui/widget/progresswidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Widget = require("ui/widget/widget")
local BD = require("ui/bidi")
local _ = require("gettext")
local Screen = Device.screen

local SmoothProgressWidget = ProgressWidget:extend{}
local ShapeIconButtonWidget = Widget:extend{}

local function fillPolygon(bb, points, color)
    if not points or #points < 3 then
        return
    end
    local min_y = points[1].y
    local max_y = points[1].y
    for i = 2, #points do
        min_y = math.min(min_y, points[i].y)
        max_y = math.max(max_y, points[i].y)
    end

    for y = math.floor(min_y), math.ceil(max_y) do
        local intersections = {}
        for i = 1, #points do
            local j = (i % #points) + 1
            local p1 = points[i]
            local p2 = points[j]
            local y1 = p1.y
            local y2 = p2.y
            if (y1 <= y and y2 > y) or (y2 <= y and y1 > y) then
                local t = (y - y1) / (y2 - y1)
                intersections[#intersections + 1] = p1.x + t * (p2.x - p1.x)
            end
        end
        table.sort(intersections)
        for i = 1, #intersections - 1, 2 do
            local x1 = math.ceil(intersections[i])
            local x2 = math.floor(intersections[i + 1])
            if x2 >= x1 then
                bb:paintRect(x1, y, x2 - x1 + 1, 1, color)
            end
        end
    end
end

local function makeScaledPolygon(points, cx, cy, scale)
    local scaled = {}
    for i, p in ipairs(points) do
        scaled[i] = {
            x = cx + (p.x - cx) * scale,
            y = cy + (p.y - cy) * scale,
        }
    end
    return scaled
end

local function makeHexagonPoints(x, y, w, h)
    local cx = x + w / 2
    local cy = y + h / 2
    local r = math.min(w, h) / 2
    local rx = r
    local ry = r
    return {
        { x = cx - 0.50 * rx, y = cy - 0.88 * ry },
        { x = cx + 0.50 * rx, y = cy - 0.88 * ry },
        { x = cx + 0.96 * rx, y = cy },
        { x = cx + 0.50 * rx, y = cy + 0.88 * ry },
        { x = cx - 0.50 * rx, y = cy + 0.88 * ry },
        { x = cx - 0.96 * rx, y = cy },
    }
end

local function makePebblePoints(x, y, w, h)
    local cx = x + w / 2
    local cy = y + h / 2
    local r = math.min(w, h) / 2
    local rx = r
    local ry = r
    local points = {}
    local radii = { 0.86, 1.00, 0.90, 0.98, 1.05, 0.92, 1.02, 0.88, 0.96, 1.03, 0.90, 0.95 }
    for i = 1, #radii do
        local angle = (i - 1) * (2 * math.pi / #radii) - math.pi / 2
        local rr = radii[i]
        points[#points + 1] = {
            x = cx + math.cos(angle) * rx * rr,
            y = cy + math.sin(angle) * ry * rr,
        }
    end
    return points
end

local function makePentagonPoints(x, y, w, h)
    local cx = x + w / 2
    local cy = y + h / 2
    local r = math.min(w, h) / 2
    local rx = r
    local ry = r
    return {
        { x = cx, y = cy - 0.98 * ry },
        { x = cx + 0.93 * rx, y = cy - 0.28 * ry },
        { x = cx + 0.58 * rx, y = cy + 0.88 * ry },
        { x = cx - 0.58 * rx, y = cy + 0.88 * ry },
        { x = cx - 0.93 * rx, y = cy - 0.28 * ry },
    }
end

local function makeTeardropPoints(x, y, w, h)
    local cx = x + w / 2
    local cy = y + h / 2
    local rx = w * 0.43
    local ry = h * 0.46
    local points = {}
    local segments = 28
    for i = 0, segments - 1 do
        local t = (i / segments) * (2 * math.pi)
        local k = 1 - 0.32 * math.cos(t)
        points[#points + 1] = {
            x = cx + math.sin(t) * rx * k,
            y = cy - math.cos(t) * ry,
        }
    end
    return points
end

local function makeFlowerPoints(x, y, w, h)
    local cx = x + w / 2
    local cy = y + h / 2
    local r = math.min(w, h) / 2
    local points = {}
    local petals = 6
    local segments = 48
    for i = 0, segments - 1 do
        local t = (i / segments) * (2 * math.pi)
        local rr = r * (0.78 + 0.20 * math.cos(petals * t))
        points[#points + 1] = {
            x = cx + math.cos(t) * rr,
            y = cy + math.sin(t) * rr,
        }
    end
    return points
end

local function getPolygonShapePoints(shape, x, y, w, h)
    if shape == "hexagon" then
        return makeHexagonPoints(x, y, w, h)
    elseif shape == "pebble" then
        return makePebblePoints(x, y, w, h)
    elseif shape == "pentagon" then
        return makePentagonPoints(x, y, w, h)
    elseif shape == "teardrop" then
        return makeTeardropPoints(x, y, w, h)
    elseif shape == "flower" then
        return makeFlowerPoints(x, y, w, h)
    end
    return nil
end

function ShapeIconButtonWidget:init()
    self.dimen = Geom:new{ w = self.width, h = self.height }
    self.icon_widget = IconWidget:new{
        icon = self.icon,
        width = self.icon_size,
        height = self.icon_size,
        alpha = true,
    }
end

function ShapeIconButtonWidget:getSize()
    return self.dimen
end

function ShapeIconButtonWidget:paintTo(bb, x, y)
    self.dimen.x = x
    self.dimen.y = y
    self.dimen.w = self.width
    self.dimen.h = self.height

    local bg_color = self.active and Blitbuffer.COLOR_LIGHT_GRAY or Blitbuffer.COLOR_WHITE
    local border_size = self.bordersize or 0
    local border_color = self.bordercolor or Blitbuffer.COLOR_BLACK
    local shape = self.shape or "circle"

    if shape == "none" then
        local icon_size = self.icon_widget:getSize()
        local icon_x = x + math.floor((self.width - icon_size.w) / 2)
        local icon_y = y + math.floor((self.height - icon_size.h) / 2)
        self.icon_widget:paintTo(bb, icon_x, icon_y)
        return
    end

    local outer = getPolygonShapePoints(shape, x, y, self.width, self.height)
    if outer then
        fillPolygon(bb, outer, border_color)
        if border_size > 0 then
            local cx = x + self.width / 2
            local cy = y + self.height / 2
            local scale = math.max(0.1, (math.min(self.width, self.height) - 2 * border_size) / math.min(self.width, self.height))
            local inner = makeScaledPolygon(outer, cx, cy, scale)
            fillPolygon(bb, inner, bg_color)
        else
            fillPolygon(bb, outer, bg_color)
        end
    else
        local radius = 0
        if shape == "circle" then
            radius = math.floor(self.width / 2)
        elseif shape == "squircle" then
            radius = math.floor(self.width * 0.24)
        end
        bb:paintRoundedRect(x, y, self.width, self.height, bg_color, radius)
        if border_size > 0 then
            bb:paintBorder(x, y, self.width, self.height, border_size, border_color, radius)
        end
    end

    local icon_size = self.icon_widget:getSize()
    local icon_x = x + math.floor((self.width - icon_size.w) / 2)
    local icon_y = y + math.floor((self.height - icon_size.h) / 2)
    self.icon_widget:paintTo(bb, icon_x, icon_y)
end

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
    button_order = {
        "wifi", "night", "frontlight", "rotate", "usb", "search", "quickrss", "cloud", "zlibrary", "calibre", "notion", "streak", "opds",
        "stats_progress", "stats_calendar", "battery_stats", "localsend", "connections", "puzzle", "crossword", "casualchess", "chess", "kosync", "filebrowserplus", "bookfusion", "focus",
        "restart", "exit", "sleep",
    },
    button_rows = 1,
    button_items_per_row = 8,
    button_show_text = true,
    button_shape = "circle",
    quick_tab_icon = "quicksettings",
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
        frontlight = false,
        stats_progress = false,
        stats_calendar = false,
        battery_stats = false,
        localsend = false,
        connections = false,
        puzzle = false,
        crossword = false,
        casualchess = false,
        chess = false,
        kosync = false,
        filebrowserplus = false,
        bookfusion = false,
        focus = false,
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
    show_clock = true,
    clock_format = "%a, %d %b %H:%M",
    clock_small_format = "%A",
    clock_alignment = "center",
    clock_text_style = "big",
    clock_font_family = "smallinfofont",
    clock_font_style = "regular",
    clock_big_font_size = 24,
    clock_small_font_size = 18,
    clock_header_layout = "stacked",
    clock_two_col_left_content = "clock",
    clock_two_col_right_content = "info",
    clock_two_col_split = 58,
    clock_three_col_left_content = "clock",
    clock_three_col_center_content = "secondary",
    clock_three_col_right_content = "info",
    clock_show_extra_info = false,
    clock_info_items = {
        reading_stats = true,
        page_info = true,
        book_title = false,
        time_left = false,
        battery = false,
        wifi = false,
        frontlight = false,
        warmth = false,
        night_mode = false,
        rotation = false,
    },
    open_on_start = false,
}

local config

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for k, v in pairs(value) do
        copy[k] = deepCopy(v)
    end
    return copy
end

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
    if type(config.clock_info_items) == "table" then
        for k, v in pairs(config_default.clock_info_items) do
            if config.clock_info_items[k] == nil then
                config.clock_info_items[k] = v
            end
        end
    else
        config.clock_info_items = {}
        for k, v in pairs(config_default.clock_info_items) do
            config.clock_info_items[k] = v
        end
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

local function getButtonRows()
    local rows = tonumber(config.button_rows) or config_default.button_rows
    return math.max(1, math.min(3, Math.round(rows)))
end

local function getButtonItemsPerRow()
    local items = tonumber(config.button_items_per_row) or config_default.button_items_per_row
    return math.max(1, math.min(10, Math.round(items)))
end

local function showButtonText()
    return config.button_show_text ~= false
end

local function getButtonShape()
    local shape = config.button_shape
    if shape == "none" or shape == "circle" or shape == "square" or shape == "squircle" or shape == "pebble" or shape == "hexagon" or shape == "pentagon" or shape == "teardrop" or shape == "flower" then
        return shape
    end
    return config_default.button_shape
end

local quick_tab_icon_options = {
    { label = _("Default (quicksettings)"), icon = "quicksettings" },
    { label = "instant mix", icon = "instant_mix" },
    { label = _("Menu"), icon = "menu" },
    { label = "network intelligence", icon = "network_intelligence" },
    { label = "wand star", icon = "wand_star" },
    { label = "rainy snow", icon = "rainy_snow" },
    { label = "tornado", icon = "tornado" },
    { label = "hive", icon = "hive" },
    { label = "widget", icon = "widget" },
}

local quick_tab_icon_set = {}
for _, entry in ipairs(quick_tab_icon_options) do
    quick_tab_icon_set[entry.icon] = true
end

local function getQuickTabIcon()
    local icon = config.quick_tab_icon
    if type(icon) == "string" and quick_tab_icon_set[icon] then
        return icon
    end
    return config_default.quick_tab_icon
end

local function hasPlugin(name)
    if G_reader_settings:isTrue("plugin_" .. name .. "_enabled") then
        return true
    end
    local ok_datastorage, DataStorage = pcall(require, "datastorage")
    local data_dir = ok_datastorage and DataStorage and DataStorage.getDataDir and DataStorage:getDataDir() or nil
    local candidates = {
        "plugins/" .. name .. ".koplugin/main.lua",
    }
    if data_dir then
        table.insert(candidates, data_dir .. "/plugins/" .. name .. ".koplugin/main.lua")
    end
    for _, path in ipairs(candidates) do
        local file = io.open(path, "r")
        if file then
            file:close()
            return true
        end
    end
    return false
end

local function getMainUI()
    local ok_r, ReaderUI = pcall(require, "apps/reader/readerui")
    local ok_f, FileManager = pcall(require, "apps/filemanager/filemanager")
    return (ok_r and ReaderUI.instance) or (ok_f and FileManager.instance)
end

local function showPluginMissingMessage(text)
    local InfoMessage = require("ui/widget/infomessage")
    UIManager:show(InfoMessage:new{ text = text })
end

loadConfig()

local clock_format_presets = {
    {
        label = _("YYYY-MM-DD HH:MM"),
        format = "%Y-%m-%d %H:%M",
    },
    {
        label = _("DD/MM/YYYY HH:MM"),
        format = "%d/%m/%Y %H:%M",
    },
    {
        label = _("MM/DD/YYYY hh:MM AM/PM"),
        format = "%m/%d/%Y %I:%M %p",
    },
    {
        label = _("Weekday, DD Mon hh:MM"),
        format = "%a, %d %b %H:%M",
    },
}

local clock_alignment_presets = {
    {
        label = _("Left"),
        value = "left",
    },
    {
        label = _("Center"),
        value = "center",
    },
    {
        label = _("Right"),
        value = "right",
    },
}

local clock_text_style_presets = {
    {
        label = _("Small"),
        value = "small",
    },
    {
        label = _("Big"),
        value = "big",
    },
    {
        label = _("Big + small"),
        value = "big_small",
    },
}

local clock_header_layout_presets = {
    {
        label = _("Stacked (top/bottom)"),
        value = "stacked",
    },
    {
        label = _("Two columns"),
        value = "two_col",
    },
    {
        label = _("Three columns"),
        value = "three_col",
    },
}

local clock_segment_content_presets = {
    {
        label = _("Clock block"),
        value = "clock",
    },
    {
        label = _("Primary line"),
        value = "primary",
    },
    {
        label = _("Secondary line"),
        value = "secondary",
    },
    {
        label = _("Info line"),
        value = "info",
    },
    {
        label = _("Empty"),
        value = "empty",
    },
}

local clock_font_family_presets = {
    {
        label = _("Small info (default)"),
        value = "smallinfofont",
    },
    {
        label = _("Info font"),
        value = "infofont",
    },
    {
        label = _("XX small info"),
        value = "xx_smallinfofont",
    },
}

local clock_font_style_presets = {
    {
        label = _("Regular"),
        value = "regular",
    },
    {
        label = _("Bold"),
        value = "bold",
    },
    {
        label = _("Italic"),
        value = "italic",
    },
    {
        label = _("Bold italic"),
        value = "bold_italic",
    },
}

local clock_info_item_order = {
    "reading_stats",
    "page_info",
    "book_title",
    "time_left",
    "battery",
    "wifi",
    "frontlight",
    "warmth",
    "night_mode",
    "rotation",
}

local clock_info_item_labels = {
    reading_stats = _("Reading progress"),
    page_info = _("Page position"),
    book_title = _("Book title"),
    time_left = _("Time left"),
    battery = _("Battery"),
    wifi = _("Wi-Fi"),
    frontlight = _("Frontlight"),
    warmth = _("Warmth"),
    night_mode = _("Night mode"),
    rotation = _("Rotation"),
}

local function formatClockText(fmt, fallback)
    if type(fmt) ~= "string" or fmt == "" then
        fmt = fallback
    end
    local ok, txt = pcall(os.date, fmt)
    if ok and txt then
        return txt
    end
    return os.date(fallback)
end

local function getClockTextStyle()
    local style = config.clock_text_style
    if style == "small" or style == "big" or style == "big_small" then
        return style
    end
    return config_default.clock_text_style
end

local function getClockHeaderLayout()
    local layout = config.clock_header_layout
    if layout == "stacked" or layout == "two_col" or layout == "three_col" then
        return layout
    end
    return config_default.clock_header_layout
end

local function getClockSegmentContent(setting_key, default_value)
    local value = config[setting_key]
    if value == "clock" or value == "primary" or value == "secondary" or value == "info" or value == "empty" then
        return value
    end
    return default_value
end

local function getClockTwoColSplit()
    local split = tonumber(config.clock_two_col_split) or config_default.clock_two_col_split
    return math.max(35, math.min(75, Math.round(split)))
end

local function getClockFontStyle()
    local style = config.clock_font_style
    if style == "regular" or style == "bold" or style == "italic" or style == "bold_italic" then
        return style
    end
    return config_default.clock_font_style
end

local function getClockFontSize(kind)
    local key = kind == "small" and "clock_small_font_size" or "clock_big_font_size"
    local default_val = config_default[key]
    local value = tonumber(config[key]) or default_val
    return math.max(10, math.min(80, Math.round(value)))
end

local function getClockFontFamily()
    if type(config.clock_font_family) == "string" and config.clock_font_family ~= "" then
        return config.clock_font_family
    end
    return config_default.clock_font_family
end

local function isClockInfoItemEnabled(item_id)
    if type(config.clock_info_items) == "table" and config.clock_info_items[item_id] ~= nil then
        return config.clock_info_items[item_id]
    end
    return config_default.clock_info_items[item_id]
end

local function safeMethodCall(obj, method_name)
    if not obj or type(obj[method_name]) ~= "function" then
        return nil
    end
    local ok, value = pcall(obj[method_name], obj)
    if ok then
        return value
    end
    return nil
end

local function getReaderUIInstance()
    local ok_reader_ui, ReaderUI = pcall(require, "apps/reader/readerui")
    if not ok_reader_ui or not ReaderUI then
        return nil
    end
    return ReaderUI.instance
end

local function getReaderObjects(ui)
    if not ui then
        return {}
    end
    return {
        ui,
        ui.view,
        ui.paging,
        ui.statistics,
        ui.reading_progress,
        ui.rolling,
        ui.document,
    }
end

local function firstNumericValue(objects, method_names)
    for _, obj in ipairs(objects) do
        for _, method_name in ipairs(method_names) do
            local value = safeMethodCall(obj, method_name)
            if type(value) == "number" then
                return value
            end
        end
    end
    return nil
end

local function firstNonEmptyStringValue(objects, method_names)
    for _, obj in ipairs(objects) do
        for _, method_name in ipairs(method_names) do
            local value = safeMethodCall(obj, method_name)
            if type(value) == "string" and value ~= "" then
                return value
            end
        end
    end
    return nil
end

local function getReadingPositionStats()
    local ui = getReaderUIInstance()
    if not ui then
        return nil, nil, nil
    end

    local objects = getReaderObjects(ui)
    local current_page = firstNumericValue(objects, {
        "getCurrentPage",
        "getPage",
        "getCurrentPos",
    })
    local total_pages = firstNumericValue(objects, {
        "getPageCount",
        "getTotalPages",
        "getNumberOfPages",
    })

    if type(current_page) == "number" and current_page < 1 then
        current_page = current_page + 1
    end

    local percent = nil
    if type(current_page) == "number" and type(total_pages) == "number" and total_pages > 0 then
        percent = Math.round((current_page / total_pages) * 100)
    else
        percent = firstNumericValue(objects, {
            "getPercentFinished",
            "getProgress",
            "getPercentComplete",
        })
        if type(percent) == "number" then
            if percent >= 0 and percent <= 1 then
                percent = percent * 100
            end
            percent = Math.round(percent)
        end
    end

    if type(percent) == "number" then
        percent = math.max(0, math.min(100, percent))
    end

    return current_page, total_pages, percent
end

local function getReadingProgressInfo()
    local _, _, percent = getReadingPositionStats()
    if type(percent) == "number" then
        return _("Reading") .. ": " .. tostring(percent) .. "%"
    end
    return nil
end

local function getReadingPageInfo()
    local current_page, total_pages = getReadingPositionStats()
    if type(current_page) == "number" and type(total_pages) == "number" and total_pages > 0 then
        return _("Page") .. ": " .. tostring(current_page) .. "/" .. tostring(total_pages)
    end
    return nil
end

local function getBookTitleInfo()
    local ui = getReaderUIInstance()
    if not ui then
        return nil
    end

    local objects = getReaderObjects(ui)
    local title = firstNonEmptyStringValue(objects, {
        "getTitle",
        "getBookTitle",
        "getDocTitle",
    })

    if not title and ui.document then
        local props = safeMethodCall(ui.document, "getProps")
        if type(props) == "table" and type(props.title) == "string" and props.title ~= "" then
            title = props.title
        end
    end

    if not title and ui.document then
        local path = safeMethodCall(ui.document, "getFilePath")
            or safeMethodCall(ui.document, "getFileName")
            or ui.document.file
        if type(path) == "string" and path ~= "" then
            local normalized_path = path:gsub("\\", "/")
            title = normalized_path:match("([^/]+)$") or normalized_path
        end
    end

    if type(title) == "string" and title ~= "" then
        return _("Book") .. ": " .. title
    end
    return nil
end

local function formatTimeLeft(value)
    if type(value) == "string" and value ~= "" then
        return value
    end
    if type(value) ~= "number" then
        return nil
    end

    local minutes
    if value > 3600 then
        minutes = Math.round(value / 60)
    elseif value > 100 then
        minutes = Math.round(value)
    else
        minutes = Math.round(value)
    end
    minutes = math.max(0, minutes)

    if minutes < 60 then
        return tostring(minutes) .. "m"
    end
    local hours = math.floor(minutes / 60)
    local rem = minutes % 60
    if rem == 0 then
        return tostring(hours) .. "h"
    end
    return tostring(hours) .. "h " .. tostring(rem) .. "m"
end

local function getTimeLeftInfo()
    local ui = getReaderUIInstance()
    if not ui then
        return nil
    end

    local objects = getReaderObjects(ui)
    local raw_value = nil
    for _, obj in ipairs(objects) do
        if raw_value == nil then
            raw_value = safeMethodCall(obj, "getEstimatedTimeToEnd")
        end
        if raw_value == nil then
            raw_value = safeMethodCall(obj, "getTimeLeft")
        end
        if raw_value == nil then
            raw_value = safeMethodCall(obj, "getTimeToRead")
        end
        if raw_value == nil then
            raw_value = safeMethodCall(obj, "getEstimatedTimeToFinish")
        end
    end

    local formatted = formatTimeLeft(raw_value)
    if formatted then
        return _("Left") .. ": " .. formatted
    end
    return nil
end

local function getClockExtraInfoText()
    if not (config.clock_show_extra_info ~= false) then
        return nil
    end

    local parts = {}
    local powerd = Device:getPowerDevice()

    if isClockInfoItemEnabled("reading_stats") then
        local reading_info = getReadingProgressInfo()
        if reading_info then
            table.insert(parts, reading_info)
        end
    end

    if isClockInfoItemEnabled("page_info") then
        local page_info = getReadingPageInfo()
        if page_info then
            table.insert(parts, page_info)
        end
    end

    if isClockInfoItemEnabled("book_title") then
        local book_title = getBookTitleInfo()
        if book_title then
            table.insert(parts, book_title)
        end
    end

    if isClockInfoItemEnabled("time_left") then
        local time_left = getTimeLeftInfo()
        if time_left then
            table.insert(parts, time_left)
        end
    end

    if isClockInfoItemEnabled("battery") and Device:hasBattery() then
        local batt_lvl = powerd:getCapacity()
        if batt_lvl ~= nil then
            table.insert(parts, _("Battery") .. ": " .. tostring(batt_lvl) .. "%")
        end
    end

    if isClockInfoItemEnabled("wifi") then
        local wifi_info = _("Off")
        if NetworkMgr:isWifiOn() then
            wifi_info = _("On")
            local net = NetworkMgr:getCurrentNetwork()
            if net and net.ssid and net.ssid ~= "" then
                wifi_info = net.ssid
            end
        end
        table.insert(parts, _("Wi-Fi") .. ": " .. wifi_info)
    end

    if isClockInfoItemEnabled("frontlight") and powerd and powerd.fl_min ~= nil and powerd.fl_max ~= nil then
        table.insert(parts, _("Frontlight") .. ": " .. tostring(powerd:frontlightIntensity()))
    end

    if isClockInfoItemEnabled("warmth") and powerd and powerd.fl_warmth_min ~= nil and powerd.fl_warmth_max ~= nil then
        local native_warmth = powerd:toNativeWarmth(powerd:frontlightWarmth())
        table.insert(parts, _("Warmth") .. ": " .. tostring(native_warmth))
    end

    if isClockInfoItemEnabled("night_mode") then
        local night_mode_text = G_reader_settings:isTrue("night_mode") and _("On") or _("Off")
        table.insert(parts, _("Night") .. ": " .. night_mode_text)
    end

    if isClockInfoItemEnabled("rotation") then
        local rotation_mode = safeMethodCall(Screen, "getRotationMode") or safeMethodCall(Screen, "getRotation")
        if rotation_mode ~= nil then
            table.insert(parts, _("Rotation") .. ": " .. tostring(rotation_mode))
        end
    end

    if #parts == 0 then
        return nil
    end
    return table.concat(parts, " | ")
end

local function getClockFace(size)
    local family = getClockFontFamily()
    local style = getClockFontStyle()

    local function styleSuffixes(font_style)
        if font_style == "bold" then
            return { "-Bold", " Bold", "_Bold", "-bold", " bold" }
        elseif font_style == "italic" then
            return { "-Italic", " Italic", "_Italic", "-Oblique", " Oblique", "-italic", " italic" }
        elseif font_style == "bold_italic" then
            return {
                "-BoldItalic", " Bold Italic", "_BoldItalic", "-BoldOblique", " Bold Oblique",
                "-bolditalic", " bold italic",
            }
        end
        return {}
    end

    local try_names = { family }
    for _, suffix in ipairs(styleSuffixes(style)) do
        table.insert(try_names, family .. suffix)
    end

    for _, name in ipairs(try_names) do
        local ok, face = pcall(Font.getFace, Font, name, Screen:scaleBySize(size))
        if ok and face then
            return face
        end
    end

    return Font:getFace("smallinfofont", Screen:scaleBySize(size))
end

local function getClockAlignment()
    local alignment = config.clock_alignment
    if alignment == "left" or alignment == "center" or alignment == "right" then
        return alignment
    end
    return config_default.clock_alignment
end

local function clockUsesSeconds()
    local function hasSeconds(fmt)
        return type(fmt) == "string" and fmt:find("%%S") ~= nil
    end
    if hasSeconds(config.clock_format) then
        return true
    end
    if getClockTextStyle() == "big_small" and hasSeconds(config.clock_small_format) then
        return true
    end
    return false
end

local function getClockTexts()
    local primary_text = formatClockText(config.clock_format, config_default.clock_format)
    if getClockTextStyle() == "big_small" then
        local secondary_text = formatClockText(config.clock_small_format, config_default.clock_small_format)
        return primary_text, secondary_text
    end
    return primary_text, nil
end

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
    frontlight = {
        icon = "lightbulb",
        label = "Frontlight",
        visible_func = function() return Device:hasFrontlight() end,
        active_func = function()
            local powerd = Device:getPowerDevice()
            return powerd and powerd.isFrontlightOn and powerd:isFrontlightOn() or false
        end,
        callback = function(touch_menu)
            local powerd = Device:getPowerDevice()
            if powerd and powerd.toggleFrontlight then
                powerd:toggleFrontlight()
                touch_menu:updateItems(1)
            end
        end,
    },
    stats_progress = {
        icon = "quick_stats_progress",
        label = "Progress",
        visible_func = function() return hasPlugin("statistics") end,
        callback = function(touch_menu)
            touch_menu:closeMenu()
            UIManager:broadcastEvent(Event:new("ShowReaderProgress"))
        end,
    },
    stats_calendar = {
        icon = "quick_stats_calendar",
        label = "Calendar",
        visible_func = function() return hasPlugin("statistics") end,
        callback = function(touch_menu)
            touch_menu:closeMenu()
            UIManager:broadcastEvent(Event:new("ShowCalendarView"))
        end,
    },
    battery_stats = {
        icon = "quick_battery",
        label = "Battery",
        visible_func = function() return hasPlugin("batterystat") end,
        callback = function(touch_menu)
            touch_menu:closeMenu()
            UIManager:broadcastEvent(Event:new("ShowBatteryStatistics"))
        end,
    },
    localsend = {
        icon = "quick_localsend",
        label = "LocalSend",
        visible_func = function() return hasPlugin("localsend") end,
        callback = function(touch_menu)
            UIManager:broadcastEvent(Event:new("ToggleLocalSend"))
            UIManager:scheduleIn(1.5, function()
                if touch_menu.item_table and touch_menu.item_table.panel then
                    touch_menu:updateItems(1)
                end
            end)
        end,
    },
    connections = {
        icon = "quick_connections",
        label = "Connections",
        visible_func = function() return hasPlugin("connections") end,
        callback = function(touch_menu)
            touch_menu:closeMenu()
            local ui = getMainUI()
            if ui and ui.nytconnections then
                local items = {}
                ui.nytconnections:addToMainMenu(items)
                if items.nytconnections and items.nytconnections.callback then
                    items.nytconnections.callback()
                    return
                end
            end
            showPluginMissingMessage(_("Connections plugin is not installed."))
        end,
    },
    puzzle = {
        icon = "quick_puzzle",
        label = "Puzzle",
        visible_func = function() return hasPlugin("slidepuzzle") end,
        callback = function(touch_menu)
            touch_menu:closeMenu()
            UIManager:broadcastEvent(Event:new("SlidePuzzleOpen"))
        end,
    },
    crossword = {
        icon = "quick_crossword",
        label = "Crossword",
        visible_func = function() return hasPlugin("crossword") end,
        callback = function(touch_menu)
            touch_menu:closeMenu()
            UIManager:broadcastEvent(Event:new("CrosswordMenu"))
        end,
    },
    casualchess = {
        icon = "quick_casualchess",
        label = "Casual Chess",
        visible_func = function() return hasPlugin("casualkochess") end,
        callback = function(touch_menu)
            touch_menu:closeMenu()
            UIManager:broadcastEvent(Event:new("CasualChessStart"))
        end,
    },
    chess = {
        icon = "quick_chess",
        label = "Chess",
        visible_func = function() return hasPlugin("casualkochess") end,
        callback = function(touch_menu)
            touch_menu:closeMenu()
            UIManager:broadcastEvent(Event:new("CasualChessStart"))
        end,
    },
    kosync = {
        icon = "quick_sync",
        label = "Sync",
        visible_func = function() return hasPlugin("kosync") end,
        callback = function(touch_menu)
            touch_menu:closeMenu()
            local ui = getMainUI()
            if ui and ui.kosync then
                NetworkMgr:runWhenOnline(function()
                    if ui.kosync.onSyncBookProgress then
                        ui.kosync:onSyncBookProgress()
                    elseif ui.kosync.onPushProgress then
                        ui.kosync:onPushProgress()
                    end
                end)
                return
            end
            showPluginMissingMessage(_("KOSync plugin is not available."))
        end,
    },
    filebrowserplus = {
        icon = "quick_filebrowser",
        label = "FileBrowser+",
        visible_func = function() return hasPlugin("filebrowserplus") end,
        callback = function(touch_menu)
            UIManager:broadcastEvent(Event:new("ToggleFilebrowserPlusServer"))
            UIManager:scheduleIn(1.5, function()
                if touch_menu.item_table and touch_menu.item_table.panel then
                    touch_menu:updateItems(1)
                end
            end)
        end,
    },
    bookfusion = {
        icon = "quick_bookfusion",
        label = "BookFusion",
        visible_func = function() return hasPlugin("bookfusion") end,
        callback = function(touch_menu)
            touch_menu:closeMenu()
            local ui = getMainUI()
            if ui and ui.bookfusion then
                if ui.bookfusion.bf_settings and ui.bookfusion.bf_settings.isLoggedIn and ui.bookfusion.bf_settings:isLoggedIn() then
                    ui.bookfusion:onSearchBooks()
                else
                    ui.bookfusion:onLinkDevice()
                end
                return
            end
            showPluginMissingMessage(_("BookFusion plugin is not installed."))
        end,
    },
    focus = {
        icon = "quick_focus",
        label = "Focus",
        callback = function()
            showPluginMissingMessage(_("Focus mode control is available in the quicksettings plugin build."))
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
    frontlight = _("Frontlight"),
    stats_progress = _("Reading progress"),
    stats_calendar = _("Reading calendar"),
    battery_stats = _("Battery stats"),
    localsend = _("LocalSend"),
    connections = _("Connections"),
    puzzle = _("Puzzle"),
    crossword = _("Crossword"),
    casualchess = _("Casual Chess"),
    chess = _("Chess"),
    kosync = _("KOSync"),
    filebrowserplus = _("FileBrowser+"),
    bookfusion = _("BookFusion"),
    focus = _("Focus"),
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
        local def = button_defs[id]
        local can_show = def and (def.visible_func == nil or def.visible_func())
        if config.show_buttons[id] and can_show then
            table.insert(visible_buttons, { id = id, def = button_defs[id] })
        end
    end

    local num_buttons = #visible_buttons
    local action_btn_size_default = Screen:scaleBySize(64)
    local action_btn_size_min = Screen:scaleBySize(40)
    local label_font = Font:getFace("xx_smallinfofont")
    local button_show_text = showButtonText()
    local button_shape = getButtonShape()

    -- Active styling
    local normal_border = Screen:scaleBySize(2)

    local function makeActionButton(icon_name, label_text, active, btn_size)
        local icon_size = math.floor(btn_size * 0.5)
        local shape_widget = ShapeIconButtonWidget:new{
            icon = icon_name,
            width = btn_size,
            height = btn_size,
            icon_size = icon_size,
            shape = button_shape,
            active = active,
            bordersize = normal_border,
            bordercolor = Blitbuffer.COLOR_BLACK,
        }
        local group = VerticalGroup:new{ align = "center" }
        table.insert(group, shape_widget)
        if button_show_text then
            local label = TextWidget:new{
                text = label_text,
                face = label_font,
                max_width = btn_size + Screen:scaleBySize(4),
            }
            table.insert(group, VerticalSpan:new{ width = Screen:scaleBySize(2) })
            table.insert(group, label)
        end
        return group, shape_widget
    end

    -- Build button row(s)
    local top_buttons_group = VerticalGroup:new{ align = "center" }

    if num_buttons > 0 then
        local target_rows = math.min(getButtonRows(), num_buttons)
        local target_per_row = getButtonItemsPerRow()
        local min_gap = Screen:scaleBySize(4)
        local max_fit_per_row = math.max(1, math.floor((inner_width + min_gap) / (action_btn_size_min + min_gap)))
        local effective_per_row = math.max(target_per_row, math.ceil(num_buttons / target_rows))
        effective_per_row = math.min(effective_per_row, max_fit_per_row)
        local row_gap = Screen:scaleBySize(8)

        local row_index = 1
        while row_index <= num_buttons do
            local row_entries = {}
            local row_end = math.min(num_buttons, row_index + effective_per_row - 1)
            for i = row_index, row_end do
                table.insert(row_entries, visible_buttons[i])
            end

            local row_count = #row_entries
            local max_btn_size_for_row = math.floor((inner_width - min_gap * math.max(row_count - 1, 0)) / row_count)
            local row_btn_size = math.max(action_btn_size_min, math.min(action_btn_size_default, max_btn_size_for_row))
            local btn_gap = math.max(0, math.floor((inner_width - row_count * row_btn_size) / math.max(row_count - 1, 1)))

            local row_widget = HorizontalGroup:new{ align = "center" }
            for i, entry in ipairs(row_entries) do
                local def = entry.def
                local label_text = def.label
                if def.label_func then
                    label_text = def.label_func()
                end
                local active = def.active_func and def.active_func() or false
                local btn_widget, btn_circle = makeActionButton(def.icon, label_text, active, row_btn_size)

                table.insert(refs.buttons, {
                    widget = btn_circle,
                    callback = function()
                        def.callback(touch_menu)
                    end,
                })

                table.insert(row_widget, btn_widget)
                if i < row_count then
                    table.insert(row_widget, HorizontalSpan:new{ width = btn_gap })
                end
            end

            table.insert(top_buttons_group, row_widget)
            if row_end < num_buttons then
                table.insert(top_buttons_group, VerticalSpan:new{ width = row_gap })
            end
            row_index = row_end + 1
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
    if config.show_warmth and Device:hasNaturalLight() then
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

    if config.show_clock then
        local alignment = getClockAlignment()
        local header_layout = getClockHeaderLayout()
        local text_style = getClockTextStyle()
        local primary_clock_text, secondary_clock_text = getClockTexts()
        local extra_info_text = getClockExtraInfoText()
        local big_clock_face = getClockFace(getClockFontSize("big"))
        local small_clock_face = getClockFace(getClockFontSize("small"))
        local info_clock_face = getClockFace(math.max(10, getClockFontSize("small") - 2))

        local function makeClockLine(text, face, line_width, line_alignment)
            local line_text = TextWidget:new{
                text = text,
                face = face,
                max_width = line_width,
            }
            local line_height = line_text:getSize().h
            if line_alignment == "left" then
                return LeftContainer:new{
                    dimen = Geom:new{ w = line_width, h = line_height },
                    line_text,
                }
            end
            if line_alignment == "right" and ok_right_container and RightContainer then
                return RightContainer:new{
                    dimen = Geom:new{ w = line_width, h = line_height },
                    line_text,
                }
            end
            return CenterContainer:new{
                dimen = Geom:new{ w = line_width, h = line_height },
                line_text,
            }
        end

        local function makeClockBlock(block_width, block_alignment)
            local block = VerticalGroup:new{ align = "center" }
            if text_style == "small" then
                table.insert(block, makeClockLine(primary_clock_text, small_clock_face, block_width, block_alignment))
            elseif text_style == "big" then
                table.insert(block, makeClockLine(primary_clock_text, big_clock_face, block_width, block_alignment))
            else
                table.insert(block, makeClockLine(primary_clock_text, big_clock_face, block_width, block_alignment))
                table.insert(block, VerticalSpan:new{ width = Screen:scaleBySize(2) })
                if secondary_clock_text and secondary_clock_text ~= "" then
                    table.insert(block, makeClockLine(secondary_clock_text, small_clock_face, block_width, block_alignment))
                end
            end
            return block
        end

        local function makeTextBlock(text, face, block_width, block_alignment)
            if not text or text == "" then
                return nil
            end
            return makeClockLine(text, face, block_width, block_alignment)
        end

        local function makeEmptyBlock(block_width)
            local empty_text = TextWidget:new{
                text = "",
                face = small_clock_face,
                max_width = block_width,
            }
            return CenterContainer:new{
                dimen = Geom:new{ w = block_width, h = empty_text:getSize().h },
                empty_text,
            }
        end

        local function makeSegmentBlock(kind, block_width, block_alignment)
            if kind == "clock" then
                return makeClockBlock(block_width, block_alignment)
            elseif kind == "primary" then
                local face = text_style == "small" and small_clock_face or big_clock_face
                return makeTextBlock(primary_clock_text, face, block_width, block_alignment)
            elseif kind == "secondary" then
                return makeTextBlock(secondary_clock_text, small_clock_face, block_width, block_alignment)
            elseif kind == "info" then
                return makeTextBlock(extra_info_text, info_clock_face, block_width, block_alignment)
            end
            return nil
        end

        if header_layout == "stacked" then
            table.insert(panel, makeClockBlock(panel_width, alignment))
            if extra_info_text and extra_info_text ~= "" then
                table.insert(panel, VerticalSpan:new{ width = Screen:scaleBySize(2) })
                table.insert(panel, makeClockLine(extra_info_text, info_clock_face, panel_width, alignment))
            end
        else
            local col_gap = Screen:scaleBySize(8)
            local header_row = HorizontalGroup:new{ align = "center" }

            if header_layout == "two_col" then
                local split = getClockTwoColSplit()
                local total = panel_width - col_gap
                local left_w = math.floor(total * split / 100)
                local right_w = total - left_w

                local left_kind = getClockSegmentContent("clock_two_col_left_content", config_default.clock_two_col_left_content)
                local right_kind = getClockSegmentContent("clock_two_col_right_content", config_default.clock_two_col_right_content)

                table.insert(header_row, makeSegmentBlock(left_kind, left_w, "left") or makeEmptyBlock(left_w))
                table.insert(header_row, HorizontalSpan:new{ width = col_gap })
                table.insert(header_row, makeSegmentBlock(right_kind, right_w, "right") or makeEmptyBlock(right_w))
            else
                local total = panel_width - col_gap * 2
                local left_w = math.floor(total / 3)
                local center_w = math.floor(total / 3)
                local right_w = total - left_w - center_w

                local left_kind = getClockSegmentContent("clock_three_col_left_content", config_default.clock_three_col_left_content)
                local center_kind = getClockSegmentContent("clock_three_col_center_content", config_default.clock_three_col_center_content)
                local right_kind = getClockSegmentContent("clock_three_col_right_content", config_default.clock_three_col_right_content)

                table.insert(header_row, makeSegmentBlock(left_kind, left_w, "left") or makeEmptyBlock(left_w))
                table.insert(header_row, HorizontalSpan:new{ width = col_gap })
                table.insert(header_row, makeSegmentBlock(center_kind, center_w, "center") or makeEmptyBlock(center_w))
                table.insert(header_row, HorizontalSpan:new{ width = col_gap })
                table.insert(header_row, makeSegmentBlock(right_kind, right_w, "right") or makeEmptyBlock(right_w))
            end

            table.insert(panel, CenterContainer:new{
                dimen = Geom:new{ w = panel_width, h = header_row:getSize().h },
                header_row,
            })
        end

        table.insert(panel, VerticalSpan:new{ width = Screen:scaleBySize(8) })
    end

    if num_buttons > 0 then
        table.insert(panel, CenterContainer:new{
            dimen = Geom:new{ w = panel_width, h = top_buttons_group:getSize().h },
            top_buttons_group,
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

local function scheduleClockUpdate(touch_menu)
    if not config.show_clock then
        return
    end
    local token = (touch_menu._qs_clock_token or 0) + 1
    touch_menu._qs_clock_token = token
    local wait
    if clockUsesSeconds() then
        wait = 1
    else
        wait = 60 - (os.time() % 60)
        if wait <= 0 then
            wait = 1
        end
    end
    UIManager:scheduleIn(wait, function()
        if touch_menu._qs_clock_token ~= token then
            return
        end
        if touch_menu.item_table and touch_menu.item_table.panel then
            touch_menu:updateItems(1)
        end
    end)
end

-- Hook updateItems for panel rendering
local orig_updateItems = TouchMenu.updateItems

function TouchMenu:updateItems(target_page, target_item_id)
    if not self.item_table or not self.item_table.panel then
        self._qs_refs = nil -- clear refs when switching away from panel tab
        self._qs_clock_token = (self._qs_clock_token or 0) + 1
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

    scheduleClockUpdate(self)
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
    icon = getQuickTabIcon(),
    remember = false,
    panel = createQuickSettingsPanel,
}

-- ============================================================
-- Settings menu builder
-- ============================================================

local function buildSettingsMenu()
    local quick_tab_icon_items = {}
    for _, option in ipairs(quick_tab_icon_options) do
        table.insert(quick_tab_icon_items, {
            text = option.label,
            checked_func = function() return getQuickTabIcon() == option.icon end,
            callback = function()
                config.quick_tab_icon = option.icon
                saveConfig()
            end,
        })
    end

    local function showInputDialog(opts)
        local ok_input_dialog, InputDialog = pcall(require, "ui/widget/inputdialog")
        if not ok_input_dialog or not InputDialog then
            local InfoMessage = require("ui/widget/infomessage")
            UIManager:show(InfoMessage:new{
                text = _("Cannot open editor on this build."),
            })
            return
        end

        local dialog
        local function closeDialog()
            if dialog then
                UIManager:close(dialog)
            end
        end

        dialog = InputDialog:new{
            title = opts.title,
            input = opts.input,
            description = opts.description,
            buttons = {
                {
                    {
                        text = _("Cancel"),
                        callback = function()
                            closeDialog()
                        end,
                    },
                    {
                        text = _("Reset"),
                        callback = function()
                            if opts.on_reset then
                                opts.on_reset()
                            end
                            closeDialog()
                        end,
                    },
                    {
                        text = _("Save"),
                        is_enter_default = true,
                        callback = function()
                            local new_value
                            if dialog.getInputText then
                                new_value = dialog:getInputText()
                            elseif dialog.getInputValue then
                                new_value = dialog:getInputValue()
                            end
                            if opts.on_save then
                                opts.on_save(new_value)
                            end
                            closeDialog()
                        end,
                    },
                },
            },
        }

        UIManager:show(dialog)
        if dialog.onShowKeyboard then
            dialog:onShowKeyboard()
        end
    end

    local function showClockFormatInput(setting_key, default_value, title)
        showInputDialog{
            title = title,
            input = config[setting_key] or default_value,
            description = _("Use os.date format tokens, e.g. %Y-%m-%d %H:%M"),
            on_reset = function()
                config[setting_key] = default_value
                saveConfig()
            end,
            on_save = function(new_value)
                if type(new_value) ~= "string" or new_value == "" then
                    new_value = default_value
                end
                config[setting_key] = new_value
                saveConfig()
            end,
        }
    end

    local function showClockFontFamilyInput()
        showInputDialog{
            title = _("Clock font family"),
            input = getClockFontFamily(),
            description = _("Enter any KOReader font family name."),
            on_reset = function()
                config.clock_font_family = config_default.clock_font_family
                saveConfig()
            end,
            on_save = function(new_value)
                if type(new_value) ~= "string" or new_value == "" then
                    new_value = config_default.clock_font_family
                end
                config.clock_font_family = new_value
                saveConfig()
            end,
        }
    end

    local function showClockFontSizeInput(setting_key, default_value, title)
        showInputDialog{
            title = title,
            input = tostring(config[setting_key] or default_value),
            description = _("Set font size (10-80)."),
            on_reset = function()
                config[setting_key] = default_value
                saveConfig()
            end,
            on_save = function(new_value)
                local parsed = tonumber(new_value)
                if not parsed then
                    parsed = default_value
                end
                config[setting_key] = math.max(10, math.min(80, Math.round(parsed)))
                saveConfig()
            end,
        }
    end

    local function showClockSplitInput()
        showInputDialog{
            title = _("Two-column split"),
            input = tostring(getClockTwoColSplit()),
            description = _("Set left column width percentage (35-75)."),
            on_reset = function()
                config.clock_two_col_split = config_default.clock_two_col_split
                saveConfig()
            end,
            on_save = function(new_value)
                local parsed = tonumber(new_value)
                if not parsed then
                    parsed = config_default.clock_two_col_split
                end
                config.clock_two_col_split = math.max(35, math.min(75, Math.round(parsed)))
                saveConfig()
            end,
        }
    end

    local function showButtonGridInput(setting_key, default_value, title, min_value, max_value)
        showInputDialog{
            title = title,
            input = tostring(config[setting_key] or default_value),
            description = _("Set value from ") .. tostring(min_value) .. _(" to ") .. tostring(max_value) .. ".",
            on_reset = function()
                config[setting_key] = default_value
                saveConfig()
            end,
            on_save = function(new_value)
                local parsed = tonumber(new_value)
                if not parsed then
                    parsed = default_value
                end
                config[setting_key] = math.max(min_value, math.min(max_value, Math.round(parsed)))
                saveConfig()
            end,
        }
    end

    local function resetClockSettingsDefaults()
        config.show_clock = config_default.show_clock
        config.clock_format = config_default.clock_format
        config.clock_small_format = config_default.clock_small_format
        config.clock_alignment = config_default.clock_alignment
        config.clock_text_style = config_default.clock_text_style
        config.clock_font_family = config_default.clock_font_family
        config.clock_font_style = config_default.clock_font_style
        config.clock_big_font_size = config_default.clock_big_font_size
        config.clock_small_font_size = config_default.clock_small_font_size
        config.clock_header_layout = config_default.clock_header_layout
        config.clock_two_col_left_content = config_default.clock_two_col_left_content
        config.clock_two_col_right_content = config_default.clock_two_col_right_content
        config.clock_two_col_split = config_default.clock_two_col_split
        config.clock_three_col_left_content = config_default.clock_three_col_left_content
        config.clock_three_col_center_content = config_default.clock_three_col_center_content
        config.clock_three_col_right_content = config_default.clock_three_col_right_content
        config.clock_show_extra_info = config_default.clock_show_extra_info
        config.clock_info_items = deepCopy(config_default.clock_info_items)
        saveConfig()
    end

    local function resetButtonSettingsDefaults()
        config.button_order = deepCopy(config_default.button_order)
        config.button_rows = config_default.button_rows
        config.button_items_per_row = config_default.button_items_per_row
        config.button_show_text = config_default.button_show_text
        config.button_shape = config_default.button_shape
        config.show_buttons = deepCopy(config_default.show_buttons)
        saveConfig()
    end

    local clock_format_items = {}
    for _, preset in ipairs(clock_format_presets) do
        table.insert(clock_format_items, {
            text = preset.label,
            checked_func = function()
                return (config.clock_format or config_default.clock_format) == preset.format
            end,
            callback = function()
                config.clock_format = preset.format
                saveConfig()
            end,
        })
    end
    table.insert(clock_format_items, {
        text = _("Custom format..."),
        separator = true,
        callback = function()
            showClockFormatInput("clock_format", config_default.clock_format, _("Primary clock format"))
        end,
    })

    local clock_small_format_items = {
        {
            text = _("Custom format..."),
            callback = function()
                showClockFormatInput("clock_small_format", config_default.clock_small_format, _("Secondary clock format"))
            end,
        },
        {
            text = _("Use weekday name"),
            checked_func = function()
                return (config.clock_small_format or config_default.clock_small_format) == "%A"
            end,
            callback = function()
                config.clock_small_format = "%A"
                saveConfig()
            end,
        },
        {
            text = _("Use day + month"),
            checked_func = function()
                return (config.clock_small_format or config_default.clock_small_format) == "%d %b"
            end,
            callback = function()
                config.clock_small_format = "%d %b"
                saveConfig()
            end,
        },
    }

    local clock_alignment_items = {}
    for _, preset in ipairs(clock_alignment_presets) do
        table.insert(clock_alignment_items, {
            text = preset.label,
            checked_func = function()
                return getClockAlignment() == preset.value
            end,
            callback = function()
                config.clock_alignment = preset.value
                saveConfig()
            end,
        })
    end

    local clock_text_style_items = {}
    for _, preset in ipairs(clock_text_style_presets) do
        table.insert(clock_text_style_items, {
            text = preset.label,
            checked_func = function()
                return getClockTextStyle() == preset.value
            end,
            callback = function()
                config.clock_text_style = preset.value
                saveConfig()
            end,
        })
    end

    local clock_font_family_items = {}
    for _, preset in ipairs(clock_font_family_presets) do
        table.insert(clock_font_family_items, {
            text = preset.label,
            checked_func = function()
                return getClockFontFamily() == preset.value
            end,
            callback = function()
                config.clock_font_family = preset.value
                saveConfig()
            end,
        })
    end
    table.insert(clock_font_family_items, {
        text = _("Custom font..."),
        separator = true,
        callback = function()
            showClockFontFamilyInput()
        end,
    })

    local clock_font_style_items = {}
    for _, preset in ipairs(clock_font_style_presets) do
        table.insert(clock_font_style_items, {
            text = preset.label,
            checked_func = function()
                return getClockFontStyle() == preset.value
            end,
            callback = function()
                config.clock_font_style = preset.value
                saveConfig()
            end,
        })
    end

    local clock_big_size_items = {
        {
            text = _("Small (18)"),
            checked_func = function() return getClockFontSize("big") == 18 end,
            callback = function()
                config.clock_big_font_size = 18
                saveConfig()
            end,
        },
        {
            text = _("Medium (24)"),
            checked_func = function() return getClockFontSize("big") == 24 end,
            callback = function()
                config.clock_big_font_size = 24
                saveConfig()
            end,
        },
        {
            text = _("Large (30)"),
            checked_func = function() return getClockFontSize("big") == 30 end,
            callback = function()
                config.clock_big_font_size = 30
                saveConfig()
            end,
        },
        {
            text = _("Extra large (36)"),
            checked_func = function() return getClockFontSize("big") == 36 end,
            callback = function()
                config.clock_big_font_size = 36
                saveConfig()
            end,
        },
        {
            text = _("Custom size..."),
            separator = true,
            callback = function()
                showClockFontSizeInput("clock_big_font_size", config_default.clock_big_font_size, _("Big text font size"))
            end,
        },
    }

    local clock_small_size_items = {
        {
            text = _("Tiny (12)"),
            checked_func = function() return getClockFontSize("small") == 12 end,
            callback = function()
                config.clock_small_font_size = 12
                saveConfig()
            end,
        },
        {
            text = _("Small (16)"),
            checked_func = function() return getClockFontSize("small") == 16 end,
            callback = function()
                config.clock_small_font_size = 16
                saveConfig()
            end,
        },
        {
            text = _("Medium (18)"),
            checked_func = function() return getClockFontSize("small") == 18 end,
            callback = function()
                config.clock_small_font_size = 18
                saveConfig()
            end,
        },
        {
            text = _("Large (22)"),
            checked_func = function() return getClockFontSize("small") == 22 end,
            callback = function()
                config.clock_small_font_size = 22
                saveConfig()
            end,
        },
        {
            text = _("Custom size..."),
            separator = true,
            callback = function()
                showClockFontSizeInput("clock_small_font_size", config_default.clock_small_font_size, _("Small text font size"))
            end,
        },
    }

    local clock_info_toggle_items = {}
    for _, item_id in ipairs(clock_info_item_order) do
        table.insert(clock_info_toggle_items, {
            text = clock_info_item_labels[item_id],
            checked_func = function()
                return isClockInfoItemEnabled(item_id)
            end,
            callback = function()
                if type(config.clock_info_items) ~= "table" then
                    config.clock_info_items = {}
                end
                config.clock_info_items[item_id] = not isClockInfoItemEnabled(item_id)
                saveConfig()
            end,
        })
    end

    local clock_header_layout_items = {}
    for _, preset in ipairs(clock_header_layout_presets) do
        table.insert(clock_header_layout_items, {
            text = preset.label,
            checked_func = function()
                return getClockHeaderLayout() == preset.value
            end,
            callback = function()
                config.clock_header_layout = preset.value
                saveConfig()
            end,
        })
    end

    local function buildSegmentContentItems(setting_key, default_value)
        local items = {}
        for _, preset in ipairs(clock_segment_content_presets) do
            table.insert(items, {
                text = preset.label,
                checked_func = function()
                    return getClockSegmentContent(setting_key, default_value) == preset.value
                end,
                callback = function()
                    config[setting_key] = preset.value
                    saveConfig()
                end,
            })
        end
        return items
    end

    local clock_two_col_left_items = buildSegmentContentItems("clock_two_col_left_content", config_default.clock_two_col_left_content)
    local clock_two_col_right_items = buildSegmentContentItems("clock_two_col_right_content", config_default.clock_two_col_right_content)
    local clock_three_col_left_items = buildSegmentContentItems("clock_three_col_left_content", config_default.clock_three_col_left_content)
    local clock_three_col_center_items = buildSegmentContentItems("clock_three_col_center_content", config_default.clock_three_col_center_content)
    local clock_three_col_right_items = buildSegmentContentItems("clock_three_col_right_content", config_default.clock_three_col_right_content)

    local clock_two_col_split_items = {
        {
            text = _("50 / 50"),
            checked_func = function() return getClockTwoColSplit() == 50 end,
            callback = function()
                config.clock_two_col_split = 50
                saveConfig()
            end,
        },
        {
            text = _("58 / 42 (default)"),
            checked_func = function() return getClockTwoColSplit() == 58 end,
            callback = function()
                config.clock_two_col_split = 58
                saveConfig()
            end,
        },
        {
            text = _("66 / 34"),
            checked_func = function() return getClockTwoColSplit() == 66 end,
            callback = function()
                config.clock_two_col_split = 66
                saveConfig()
            end,
        },
        {
            text = _("Custom split..."),
            separator = true,
            callback = function()
                showClockSplitInput()
            end,
        },
    }

    local clock_two_col_layout_items = {
        {
            text = _("Left segment content"),
            sub_item_table = clock_two_col_left_items,
        },
        {
            text = _("Right segment content"),
            sub_item_table = clock_two_col_right_items,
        },
        {
            text = _("Column width split"),
            sub_item_table = clock_two_col_split_items,
        },
    }

    local clock_three_col_layout_items = {
        {
            text = _("Left segment content"),
            sub_item_table = clock_three_col_left_items,
        },
        {
            text = _("Center segment content"),
            sub_item_table = clock_three_col_center_items,
        },
        {
            text = _("Right segment content"),
            sub_item_table = clock_three_col_right_items,
        },
    }

    local clock_settings_items = {
        {
            text = _("Show clock at top"),
            checked_func = function() return config.show_clock ~= false end,
            callback = function()
                config.show_clock = not (config.show_clock ~= false)
                saveConfig()
            end,
        },
        {
            text = _("Clock format"),
            sub_item_table = clock_format_items,
        },
        {
            text = _("Header layout"),
            sub_item_table = clock_header_layout_items,
        },
        {
            text = _("Two-column layout"),
            sub_item_table = clock_two_col_layout_items,
        },
        {
            text = _("Three-column layout"),
            sub_item_table = clock_three_col_layout_items,
        },
        {
            text = _("Clock alignment"),
            sub_item_table = clock_alignment_items,
        },
        {
            text = _("Clock text layout"),
            sub_item_table = clock_text_style_items,
        },
        {
            text = _("Clock font"),
            sub_item_table = clock_font_family_items,
        },
        {
            text = _("Clock font style"),
            sub_item_table = clock_font_style_items,
        },
        {
            text = _("Show info line"),
            checked_func = function() return config.clock_show_extra_info ~= false end,
            callback = function()
                config.clock_show_extra_info = not (config.clock_show_extra_info ~= false)
                saveConfig()
            end,
        },
        {
            text = _("Info items"),
            sub_item_table = clock_info_toggle_items,
        },
        {
            text = _("Big text size"),
            sub_item_table = clock_big_size_items,
        },
        {
            text = _("Small text format"),
            sub_item_table = clock_small_format_items,
        },
        {
            text = _("Small text size"),
            sub_item_table = clock_small_size_items,
        },
        {
            text = _("Reset clock defaults"),
            callback = function()
                resetClockSettingsDefaults()
            end,
            separator = true,
        },
    }

    local button_rows_items = {
        {
            text = _("1 row"),
            checked_func = function() return getButtonRows() == 1 end,
            callback = function()
                config.button_rows = 1
                saveConfig()
            end,
        },
        {
            text = _("2 rows"),
            checked_func = function() return getButtonRows() == 2 end,
            callback = function()
                config.button_rows = 2
                saveConfig()
            end,
        },
        {
            text = _("3 rows"),
            checked_func = function() return getButtonRows() == 3 end,
            callback = function()
                config.button_rows = 3
                saveConfig()
            end,
        },
        {
            text = _("Custom rows..."),
            separator = true,
            callback = function()
                showButtonGridInput("button_rows", config_default.button_rows, _("Quick button rows"), 1, 3)
            end,
        },
    }

    local button_items_per_row_items = {}
    for i = 1, 10 do
        local row_items = i
        table.insert(button_items_per_row_items, {
            text = tostring(row_items),
            checked_func = function() return getButtonItemsPerRow() == row_items end,
            callback = function()
                config.button_items_per_row = row_items
                saveConfig()
            end,
        })
    end
    table.insert(button_items_per_row_items, {
        text = _("Custom items..."),
        separator = true,
        callback = function()
            showButtonGridInput("button_items_per_row", config_default.button_items_per_row, _("Quick items per row"), 1, 10)
        end,
    })

    local button_shape_items = {
        {
            text = _("No shape"),
            checked_func = function() return getButtonShape() == "none" end,
            callback = function()
                config.button_shape = "none"
                saveConfig()
            end,
        },
        {
            text = _("Circle"),
            checked_func = function() return getButtonShape() == "circle" end,
            callback = function()
                config.button_shape = "circle"
                saveConfig()
            end,
        },
        {
            text = _("Square"),
            checked_func = function() return getButtonShape() == "square" end,
            callback = function()
                config.button_shape = "square"
                saveConfig()
            end,
        },
        {
            text = _("Squircle"),
            checked_func = function() return getButtonShape() == "squircle" end,
            callback = function()
                config.button_shape = "squircle"
                saveConfig()
            end,
        },
        {
            text = _("Pebble"),
            checked_func = function() return getButtonShape() == "pebble" end,
            callback = function()
                config.button_shape = "pebble"
                saveConfig()
            end,
        },
        {
            text = _("Hexagon (approx)"),
            checked_func = function() return getButtonShape() == "hexagon" end,
            callback = function()
                config.button_shape = "hexagon"
                saveConfig()
            end,
        },
        {
            text = _("Pentagon"),
            checked_func = function() return getButtonShape() == "pentagon" end,
            callback = function()
                config.button_shape = "pentagon"
                saveConfig()
            end,
        },
        {
            text = _("Teardrop"),
            checked_func = function() return getButtonShape() == "teardrop" end,
            callback = function()
                config.button_shape = "teardrop"
                saveConfig()
            end,
        },
        {
            text = _("Flower"),
            checked_func = function() return getButtonShape() == "flower" end,
            callback = function()
                config.button_shape = "flower"
                saveConfig()
            end,
        },
    }

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
    table.insert(button_toggle_items, 2, {
        text = _("Rows"),
        sub_item_table = button_rows_items,
    })
    table.insert(button_toggle_items, 3, {
        text = _("Items per row"),
        sub_item_table = button_items_per_row_items,
    })
    table.insert(button_toggle_items, 4, {
        text = _("Show text labels"),
        checked_func = function() return showButtonText() end,
        callback = function()
            config.button_show_text = not showButtonText()
            saveConfig()
        end,
    })
    table.insert(button_toggle_items, 5, {
        text = _("Button shape"),
        sub_item_table = button_shape_items,
    })
    table.insert(button_toggle_items, 6, {
        text = _("Reset button defaults"),
        callback = function()
            resetButtonSettingsDefaults()
        end,
        separator = true,
    })

    return {
        text = _("Quick settings"),
        sub_item_table = {
            {
                text = _("Tab icon (requires restart)"),
                sub_item_table = quick_tab_icon_items,
            },
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
                text = _("Info bar settings"),
                sub_item_table = clock_settings_items,
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
    quick_settings_tab.icon = getQuickTabIcon()
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
    quick_settings_tab.icon = getQuickTabIcon()
    table.insert(ReaderMenuOrder.setting, "----------------------------")
    table.insert(ReaderMenuOrder.setting, "quick_settings_config")
    self.menu_items.quick_settings_config = buildSettingsMenu()
    orig_reader_setUpdateItemTable(self)
    if self.tab_item_table then
        table.insert(self.tab_item_table, 1, quick_settings_tab)
    end
end
