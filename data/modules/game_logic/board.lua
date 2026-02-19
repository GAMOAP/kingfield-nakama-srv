-- modules/game_logic/board.lua
local karma = require("game_logic.karma")
local helpers = require("utils.helpers")

local M = {}

function M.create_board(state)
    local board = {}
    local karma_player1 = karma.calculate_karma(M.get_all_card_ids(state.game_data.units[1]))
    local karma_player2 = karma.calculate_karma(M.get_all_card_ids(state.game_data.units[2]))

    for x = 1, 5 do
        for y = 1, 5 do
            local num_karma1 = 5 - y
            local quarters = {}
            for i = 1, num_karma1 do quarters[i] = karma_player1 end
            for i = num_karma1 + 1, 4 do quarters[i] = karma_player2 end

            -- Mélange aléatoire
            for i = 4, 2, -1 do
                local j = math.random(i)
                quarters[i], quarters[j] = quarters[j], quarters[i]
            end

            if not board[x] then board[x] = {} end
            board[x][y] = {
                position = {x = x, y = y},
                chess_position = helpers.coords_to_chess(x, y),
                data = {
                    quarters = quarters,
                    is_occupied = false,
                    occupant = nil
                }
            }
        end
    end

    -- Placer les unités
    for player_index, team in pairs(state.game_data.units) do
        for unit_name, unit in pairs(team) do
            local x, y = unit.x, unit.y
            if board[x] and board[x][y] then
                board[x][y].data.is_occupied = true
                board[x][y].data.occupant = {
                    unit_id = unit_name,
                    player = player_index
                }
            end
        end
    end

    return board
end

function M.get_all_card_ids(team_units)
    local card_ids = {}
    for _, unit in pairs(team_units) do
        for _, card_data in pairs(unit.cards) do
            if card_data and card_data.id then
                table.insert(card_ids, card_data.id)
            end
        end
    end
    return card_ids
end

return M
