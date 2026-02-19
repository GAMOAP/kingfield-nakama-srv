-- modules/game_logic/karma.lua
local M = {}

function M.calculate_karma(card_values)
    local sign_count = {}
    local min_hundreds = {}

    for _, str_value in pairs(card_values) do
        local value = tonumber(str_value) or 0
        local hundreds = math.floor(value / 100)
        local tens = math.floor((value % 100) / 10)

        sign_count[tens] = (sign_count[tens] or 0) + 1
        if not min_hundreds[tens] or hundreds < min_hundreds[tens] then
            min_hundreds[tens] = hundreds
        end
    end

    local karma = nil
    local max_count = 0

    for tens, count in pairs(sign_count) do
        if count > max_count or
           (count == max_count and (not karma or min_hundreds[tens] < min_hundreds[karma])) then
            max_count = count
            karma = tens
        end
    end

    return karma or 0
end

return M
