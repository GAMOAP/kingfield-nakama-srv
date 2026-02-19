-- modules/game_logic/actions.lua
local helpers = require("utils.helpers")

local M = {}

function M.process_player_action(state, player_id, action_data)

    print(string.format("[ACTIONS] action_data = %s", action_data))

    local player_index = nil
    for i, unit_team in ipairs(state.game_data.units) do
        if state.players[i].id == player_id then
            player_index = i
            break
        end
    end

    if not player_index then
        return false, "Joueur non trouvé"
    end

    local unit = state.game_data.units[player_index][action_data.char_name]
    if not unit then
        return false, "Personnage introuvable"
    end

    if not unit.alive then
        return false, "Ce personnage est mort"
    end

    local cell1 = M.get_cell(state, action_data.block_label_1)
    local cell2 = M.get_cell(state, action_data.block_label_2)

    if not cell1 or not cell2 then
        return false, "Case invalide"
    end

    -- Logique de jeu (à compléter)
    return true, {
        unit_moved = action_data.char_name,
        from = action_data.block_label_1,
        to = action_data.block_label_2,
        card_used = action_data.card_id
    }
end

function M.get_cell(state, label)
    local coords = helpers.chess_to_coords(label)
    if coords.x < 1 or coords.x > 5 or coords.y < 1 or coords.y > 5 then
        return nil
    end
    return state.game_data.board[coords.x][coords.y]
end

return M
