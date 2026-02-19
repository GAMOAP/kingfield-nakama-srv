-- modules/utils/helpers.lua
local M = {}

function M.chess_to_coords(label)
    local col = string.byte(label:sub(1, 1)) - 64 -- A=1, B=2, etc.
    local row = tonumber(label:sub(2, 2))
    return { x = col, y = row }
end

function M.coords_to_chess(x, y)
    return string.char(64 + x) .. y
end

return M
