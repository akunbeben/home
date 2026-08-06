local M = {
    enabled = true,
    generation = 0,
    history = {},
    previous = {},
}

local namespace = vim.api.nvim_create_namespace("go_debug_visual")
local connector_namespace = vim.api.nvim_create_namespace("go_debug_visual_connector")

local function valid_buffer(buffer)
    return buffer and vim.api.nvim_buf_is_valid(buffer)
end

local function valid_window(window)
    return window and vim.api.nvim_win_is_valid(window)
end

local function close_window()
    if valid_buffer(M.connector_source) then
        vim.api.nvim_buf_clear_namespace(M.connector_source, connector_namespace, 0, -1)
    end
    if valid_window(M.window) then
        vim.api.nvim_win_close(M.window, true)
    end
    if valid_window(M.arrow_window) then
        vim.api.nvim_win_close(M.arrow_window, true)
    end
    if valid_window(M.vertical_window) then
        vim.api.nvim_win_close(M.vertical_window, true)
    end
    M.window = nil
    M.arrow_window = nil
    M.vertical_window = nil
    M.arrow_buffer = nil
    M.vertical_buffer = nil
    M.connector_source = nil
    M.current_frame = nil
end

local function clip(text, width)
    text = tostring(text or "")
    if vim.fn.strdisplaywidth(text) <= width then
        return text
    end

    local clipped = vim.fn.strcharpart(text, 0, math.max(width - 1, 1))
    while vim.fn.strdisplaywidth(clipped .. "…") > width do
        clipped = vim.fn.strcharpart(clipped, 0, math.max(vim.fn.strchars(clipped) - 1, 0))
    end
    return clipped .. "…"
end

local function source_buffer(frame)
    local path = frame.source and frame.source.path
    if not path or path == "" then
        return nil
    end

    local buffer = vim.fn.bufnr(path)
    if buffer == -1 then
        buffer = vim.fn.bufadd(path)
    end
    if buffer > 0 and not vim.api.nvim_buf_is_loaded(buffer) then
        vim.fn.bufload(buffer)
    end
    return buffer > 0 and buffer or nil
end

local function source_window(buffer)
    if buffer then
        for _, window in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            local config = vim.api.nvim_win_get_config(window)
            if config.relative == "" and vim.api.nvim_win_get_buf(window) == buffer then
                return window
            end
        end
    end

    local current = vim.api.nvim_get_current_win()
    if vim.api.nvim_win_get_config(current).relative == "" then
        return current
    end

    for _, window in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_get_config(window).relative == "" then
            return window
        end
    end
end

local function hide_neo_tree()
    if M.neo_tree_state then
        return
    end

    for _, window in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local buffer = vim.api.nvim_win_get_buf(window)
        if vim.bo[buffer].filetype == "neo-tree" then
            M.neo_tree_state = {
                source = vim.b[buffer].neo_tree_source or "filesystem",
                position = vim.b[buffer].neo_tree_position,
            }
            require("neo-tree.command").execute({ action = "close" })
            return
        end
    end
end

local function restore_neo_tree()
    local state = M.neo_tree_state
    M.neo_tree_state = nil
    if not state then
        return
    end

    vim.schedule(function()
        if vim.fn.exists(":Neotree") == 2 then
            require("neo-tree.command").execute({
                action = "show",
                source = state.source,
                position = state.position,
            })
        end
    end)
end

local function current_source_line(frame, buffer)
    if not buffer or not frame.line or frame.line < 1 then
        return ""
    end

    local lines = vim.api.nvim_buf_get_lines(buffer, frame.line - 1, frame.line, false)
    return vim.trim(lines[1] or "")
end

local function define_highlights()
    vim.api.nvim_set_hl(0, "GoDebugVisualTitle", { default = true, link = "DiagnosticWarn" })
    vim.api.nvim_set_hl(0, "GoDebugVisualLocation", { default = true, link = "DiagnosticInfo" })
    vim.api.nvim_set_hl(0, "GoDebugVisualCode", { default = true, link = "String" })
    vim.api.nvim_set_hl(0, "GoDebugVisualChanged", { default = true, link = "DiagnosticOk" })
    vim.api.nvim_set_hl(0, "GoDebugVisualValue", { default = true, link = "Special" })
    vim.api.nvim_set_hl(0, "GoDebugVisualMuted", { default = true, link = "Comment" })
    vim.api.nvim_set_hl(0, "GoDebugVisualArrow", { default = true, link = "Normal" })
    vim.api.nvim_set_hl(0, "GoDebugVisualConnector", { default = true, link = "Normal" })
end

local function set_scratch_lines(buffer, lines)
    vim.api.nvim_set_option_value("modifiable", true, { buf = buffer })
    vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
    vim.api.nvim_set_option_value("modifiable", false, { buf = buffer })
end

local function close_connector_windows()
    if valid_window(M.arrow_window) then
        vim.api.nvim_win_close(M.arrow_window, true)
    end
    if valid_window(M.vertical_window) then
        vim.api.nvim_win_close(M.vertical_window, true)
    end
    M.arrow_window = nil
    M.vertical_window = nil
    M.arrow_buffer = nil
    M.vertical_buffer = nil
end

local function render_connector(frame, target, window_width, window_height, popup_width, popup_height)
    local line = tonumber(frame.line)
    if not line then
        return
    end

    local first_line = vim.api.nvim_win_call(target, function()
        return vim.fn.line("w0")
    end)
    local row = line - first_line
    local popup_left = math.max(0, window_width - popup_width - 1)
    local col = math.min(window_width - 1, popup_left + math.floor(popup_width * 0.28))
    local source_buffer = vim.api.nvim_win_get_buf(target)

    if valid_buffer(M.connector_source) then
        vim.api.nvim_buf_clear_namespace(M.connector_source, connector_namespace, 0, -1)
    end
    M.connector_source = source_buffer
    close_connector_windows()

    if row < 0 or row >= window_height then
        return
    end

    local source_line = vim.api.nvim_buf_get_lines(source_buffer, line - 1, line, false)[1] or ""
    local target_position = vim.api.nvim_win_get_position(target)
    local eol_position = vim.fn.screenpos(target, line, #source_line + 1)
    local eol_col = eol_position.col - target_position[2] - 1
    local horizontal_width = col - eol_col
    if horizontal_width > 0 then
        local horizontal = string.rep("━", math.max(horizontal_width - 1, 0)) .. "┘"
        vim.api.nvim_buf_set_extmark(source_buffer, connector_namespace, line - 1, 0, {
            virt_text = { { horizontal, "GoDebugVisualConnector" } },
            virt_text_pos = "eol",
            hl_mode = "combine",
        })
    end

    local panel_top = 1
    local panel_bottom = panel_top + popup_height + 1
    local head_row
    local vertical_start
    local vertical_height
    local arrow

    if row > panel_bottom then
        head_row = panel_bottom
        vertical_start = head_row + 1
        vertical_height = row - vertical_start
        arrow = "↑"
    elseif row < panel_top then
        head_row = panel_top
        vertical_start = row + 1
        vertical_height = head_row - vertical_start
        arrow = "↓"
    end

    if not arrow or vertical_height < 1 then
        return
    end

    if not valid_buffer(M.arrow_buffer) then
        M.arrow_buffer = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = M.arrow_buffer })
    end
    set_scratch_lines(M.arrow_buffer, { arrow })

    local arrow_config = {
        relative = "win",
        win = target,
        row = head_row,
        col = col,
        width = 1,
        height = 1,
        style = "minimal",
        focusable = false,
        zindex = 71,
    }

    M.arrow_window = vim.api.nvim_open_win(M.arrow_buffer, false, arrow_config)
    vim.api.nvim_set_option_value("winhighlight", "Normal:GoDebugVisualArrow", { win = M.arrow_window })

    if not valid_buffer(M.vertical_buffer) then
        M.vertical_buffer = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = M.vertical_buffer })
    end
    local vertical_lines = {}
    for index = 1, vertical_height do
        vertical_lines[index] = "│"
    end
    set_scratch_lines(M.vertical_buffer, vertical_lines)

    local vertical_config = {
        relative = "win",
        win = target,
        row = vertical_start,
        col = col,
        width = 1,
        height = vertical_height,
        style = "minimal",
        focusable = false,
        zindex = 71,
    }
    M.vertical_window = vim.api.nvim_open_win(M.vertical_buffer, false, vertical_config)
    vim.api.nvim_set_option_value("winhighlight", "Normal:GoDebugVisualArrow", { win = M.vertical_window })
end

local function render(frame, records)
    if not M.enabled then
        return
    end

    local buffer = source_buffer(frame)
    local target = source_window(buffer)
    if not target then
        return
    end
    M.current_frame = frame

    local window_width = vim.api.nvim_win_get_width(target)
    local window_height = vim.api.nvim_win_get_height(target)
    local width = math.min(62, math.max(38, math.floor(window_width * 0.44)))
    width = math.min(width, math.max(window_width - 4, 20))

    local path = frame.source and frame.source.path or ""
    local location = string.format("%s:%s", vim.fn.fnamemodify(path, ":t"), frame.line or "?")
    local code = current_source_line(frame, buffer)
    local lines = {
        "▶ " .. clip(frame.name or "Program berhenti", width - 2),
        "  " .. clip(location, width - 2),
        "",
        "  " .. clip(code, width - 2),
        "",
        "NILAI SEKARANG",
    }
    local highlights = {
        [1] = "GoDebugVisualTitle",
        [2] = "GoDebugVisualLocation",
        [4] = "GoDebugVisualCode",
        [6] = "GoDebugVisualTitle",
    }

    if #records == 0 then
        table.insert(lines, "  Data lokal belum tersedia")
        highlights[#lines] = "GoDebugVisualMuted"
    else
        for index, record in ipairs(records) do
            if index > 10 then
                break
            end

            local name = clip(record.name, 20)
            local value
            if record.changed then
                value = string.format("%s → %s", record.old, record.value)
            else
                value = record.value
            end
            local marker = record.changed and "●" or "○"
            table.insert(lines, string.format("%s %-20s %s", marker, name, clip(value, width - 25)))
            highlights[#lines] = record.changed and "GoDebugVisualChanged" or "GoDebugVisualValue"
        end
    end

    table.insert(lines, "")
    table.insert(lines, "PERUBAHAN TERAKHIR")
    highlights[#lines] = "GoDebugVisualTitle"

    if #M.history == 0 then
        table.insert(lines, "  Belum ada perubahan nilai")
        highlights[#lines] = "GoDebugVisualMuted"
    else
        for index, item in ipairs(M.history) do
            if index > 4 then
                break
            end
            local text = string.format("  %s: %s → %s", item.name, item.old, item.new)
            table.insert(lines, clip(text, width))
            highlights[#lines] = "GoDebugVisualChanged"
        end
    end

    table.insert(lines, "")
    table.insert(lines, "  dO step  ·  dc lanjut  ·  dv tutup")
    highlights[#lines] = "GoDebugVisualMuted"

    local height = math.min(#lines, math.max(window_height - 4, 8))
    if #lines > height then
        lines = vim.list_slice(lines, 1, height)
    end

    if not valid_buffer(M.buffer) then
        M.buffer = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = M.buffer })
        vim.api.nvim_set_option_value("filetype", "go-debug-visual", { buf = M.buffer })
    end

    vim.api.nvim_set_option_value("modifiable", true, { buf = M.buffer })
    vim.api.nvim_buf_set_lines(M.buffer, 0, -1, false, lines)
    vim.api.nvim_buf_clear_namespace(M.buffer, namespace, 0, -1)
    for line, highlight in pairs(highlights) do
        if line <= #lines then
            vim.api.nvim_buf_add_highlight(M.buffer, namespace, highlight, line - 1, 0, -1)
        end
    end
    vim.api.nvim_set_option_value("modifiable", false, { buf = M.buffer })

    local config = {
        relative = "win",
        win = target,
        anchor = "NE",
        row = 1,
        col = window_width - 2,
        width = width,
        height = height,
        style = "minimal",
        border = "rounded",
        title = " Go Debug ",
        title_pos = "center",
        focusable = false,
        zindex = 70,
    }

    if valid_window(M.window) then
        vim.api.nvim_win_set_config(M.window, config)
    else
        M.window = vim.api.nvim_open_win(M.buffer, false, config)
        vim.api.nvim_set_option_value("winblend", 4, { win = M.window })
        vim.api.nvim_set_option_value(
            "winhighlight",
            "Normal:NormalFloat,FloatBorder:DiagnosticWarn,FloatTitle:DiagnosticWarn",
            { win = M.window }
        )
    end

    render_connector(frame, target, window_width, window_height, width, height)
end

function M.update_connector()
    if M.updating_connector or not M.enabled or not M.current_frame or not valid_window(M.window) then
        return
    end

    M.updating_connector = true
    pcall(function()
        local buffer = source_buffer(M.current_frame)
        local target = source_window(buffer)
        if not target then
            close_connector_windows()
            return
        end

        local popup = vim.api.nvim_win_get_config(M.window)
        render_connector(
            M.current_frame,
            target,
            vim.api.nvim_win_get_width(target),
            vim.api.nvim_win_get_height(target),
            popup.width,
            popup.height
        )
    end)
    M.updating_connector = false
end

local function preferred_scopes(frame)
    local preferred = {}
    local fallback = {}

    for _, scope in ipairs(frame.scopes or {}) do
        if not scope.expensive and scope.variables then
            table.insert(fallback, scope)
            local hint = scope.presentationHint or ""
            local name = string.lower(scope.name or "")
            if hint == "locals" or hint == "arguments" or name:find("local") or name:find("argument") then
                table.insert(preferred, scope)
            end
        end
    end

    return #preferred > 0 and preferred or fallback
end

local function collect_variables(session, frame, generation, attempt)
    if not M.enabled or generation ~= M.generation then
        return
    end

    local scopes = preferred_scopes(frame)
    if #scopes == 0 and attempt < 12 then
        vim.defer_fn(function()
            collect_variables(session, frame, generation, attempt + 1)
        end, 50)
        return
    end

    local records = {}
    local pending = 0
    local structured = 0

    local function add(variable, parent)
        local name = variable.evaluateName or variable.name or "?"
        if parent and not variable.evaluateName then
            name = parent .. "." .. name
        end
        table.insert(records, {
            key = name,
            name = name,
            value = tostring(variable.value or ""),
        })
        return name
    end

    local function finish()
        if pending > 0 or generation ~= M.generation then
            return
        end

        table.sort(records, function(left, right)
            return left.name < right.name
        end)

        local current = {}
        for _, record in ipairs(records) do
            current[record.key] = record.value
            local old = M.previous[record.key]
            if old ~= nil and old ~= record.value then
                record.changed = true
                record.old = old
                table.insert(M.history, 1, {
                    name = record.name,
                    old = old,
                    new = record.value,
                })
            end
        end

        while #M.history > 8 do
            table.remove(M.history)
        end
        M.previous = current

        table.sort(records, function(left, right)
            if left.changed ~= right.changed then
                return left.changed == true
            end
            return left.name < right.name
        end)
        render(frame, records)
    end

    local function expand(variable, parent, depth)
        local name = add(variable, parent)
        local can_expand = variable.variablesReference
            and variable.variablesReference > 0
            and depth < 2
            and structured < 10
        if not can_expand then
            return
        end

        structured = structured + 1
        pending = pending + 1
        session:request("variables", { variablesReference = variable.variablesReference }, function(err, response)
            if generation ~= M.generation then
                return
            end
            if not err and response then
                for _, child in ipairs(response.variables or {}) do
                    expand(child, name, depth + 1)
                end
            end
            pending = pending - 1
            finish()
        end)
    end

    for _, scope in ipairs(scopes) do
        for _, variable in ipairs(scope.variables or {}) do
            expand(variable, nil, 0)
        end
    end

    finish()
end

function M.refresh()
    if not M.enabled then
        return
    end

    local dap = require("dap")
    local session = dap.session()
    local frame = session and session.current_frame
    if not session or not frame then
        return
    end

    M.generation = M.generation + 1
    collect_variables(session, frame, M.generation, 0)
end

function M.toggle()
    M.enabled = not M.enabled
    if M.enabled then
        M.refresh()
    else
        M.generation = M.generation + 1
        close_window()
    end
    vim.notify("Go debug visual: " .. (M.enabled and "aktif" or "nonaktif"))
end

function M.reset()
    M.generation = M.generation + 1
    M.history = {}
    M.previous = {}
    close_window()
    restore_neo_tree()
end

function M.setup()
    if M.setup_done then
        return
    end
    M.setup_done = true

    define_highlights()
    local dap = require("dap")

    dap.listeners.after.event_initialized["go_debug_visual"] = function()
        M.reset()
        hide_neo_tree()
    end
    dap.listeners.after.event_stopped["go_debug_visual"] = function()
        if M.enabled then
            vim.defer_fn(M.refresh, 120)
        end
    end
    dap.listeners.after.event_continued["go_debug_visual"] = close_window
    dap.listeners.before.event_terminated["go_debug_visual"] = M.reset
    dap.listeners.before.event_exited["go_debug_visual"] = M.reset
    dap.listeners.before.disconnect["go_debug_visual"] = M.reset

    local connector_group = vim.api.nvim_create_augroup("GoDebugVisualConnector", { clear = true })
    vim.api.nvim_create_autocmd({ "WinScrolled", "VimResized" }, {
        group = connector_group,
        callback = function()
            if M.current_frame then
                vim.schedule(M.update_connector)
            end
        end,
    })

    vim.api.nvim_create_user_command("GoDebugVisualToggle", M.toggle, {})
end

return M
