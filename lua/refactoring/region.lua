local function get_selection_range()
    -- local _, end_row, _, _ = unpack(vim.fn.getpos("'>"))
    local start_row = vim.fn.line("'<")
    local start_col = vim.fn.col("'<")
    local end_row = vim.fn.line("'>")
    local end_col = vim.fn.col("'>")

    -- end_col :: TS is 0 based, and '> on line selections is char_count + 1
    -- I think - 2 is correct on
    --
    -- end_row : end_row is exclusive in TS, so we don't minus
    return start_row, start_col, end_row, end_col
end

---@class Region
--- The following fields act similar to a cursor
---@field start_row number: The 1-based row
---@field start_col number: The 0-based col
---@field end_row number: The 1-based row
---@field end_col number: The 0-based col
---@field bufnr number: the buffer that the region is from
local Region = {}
Region.__index = Region

--- Get a Region from the current selection
---@return Region
function Region:from_current_selection()
    local start_row, start_col, end_row, end_col = get_selection_range()

    return setmetatable({
        bufnr = vim.fn.bufnr(),
        start_row = start_row,
        start_col = start_col,
        end_row = end_row,
        end_col = end_col,
    }, self)
end

--- Get a region from a Treesitter Node
---@return Region
function Region:from_node(node, bufnr)
    bufnr = bufnr or vim.fn.bufnr()
    local start_line, start_col, end_line, end_col = node:range()

    -- todo: is col correct?
    return setmetatable({
        bufnr = vim.fn.bufnr(bufnr),
        start_row = start_line + 1,
        start_col = start_col + 1,
        end_row = end_line + 1,
        end_col = end_col,
    }, self)
end

function Region:from_lsp_range(lsp_range, bufnr)
    bufnr = bufnr or vim.fn.bufnr()

    -- todo: is col correct?
    return setmetatable({
        bufnr = vim.fn.bufnr(bufnr),
        start_row = lsp_range.start.line + 1,
        start_col = lsp_range.start.character,
        end_row = lsp_range["end"].line + 1,
        end_col = lsp_range["end"].character,
    }, self)
end

--- Convert a region to a vim region
function Region:to_vim()
    return self.start_row, self.start_col, self.end_row, self.end_col
end

--- Convert a region to a tree sitter region
function Region:to_ts()
    -- Need the -2 for end_col to be  correct for `ts_utils.is_in_node_range`
    -- function results when checking scope for languages like python
    return self.start_row - 1,
        self.start_col,
        self.end_row - 1,
        self.end_col - 2
end

function Region:get_text(bufnr)
    local text = vim.api.nvim_buf_get_lines(
        bufnr or 0,
        self.start_row - 1,
        self.end_row,
        false
    )

    local text_length = #text
    local end_col = math.min(#text[text_length], self.end_col)
    local end_idx = vim.str_byteindex(text[text_length], end_col)
    local start_idx = vim.str_byteindex(text[1], self.start_col)

    text[text_length] = text[text_length]:sub(1, end_idx)
    text[1] = text[1]:sub(start_idx)

    return text
end

--- Convert a region to an LSP Range
function Region:to_lsp_range()
    return {
        ["start"] = {
            line = self.start_row - 1,
            character = self.start_col - 1,
        },
        ["end"] = {
            line = self.end_row - 1,
            character = self.end_col,
        },
    }
end

function Region:to_lsp_text_edit(text)
    return {
        range = self:to_lsp_range(),
        newText = text,
    }
end

return Region
