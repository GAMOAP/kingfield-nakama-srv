-- modules/match/turn.lua
local nk = require("nakama")

local M = {}

-- ============================================
-- TRAITEMENT D'UNE ACTION (version simplifiée)
-- ============================================
-- @param state (table) : État du match
-- @param sender (table) : Joueur qui envoie l'action
-- @param action_data (table) : Données de l'action (ex: { type = "move", ... })
-- @return (boolean, table) : (succès, résultat)
function M.process_action(state, sender, action_data)
    -- 1. Vérifie que c'est bien le tour du joueur (très basique)
    local player_index = nil
    for i, player in ipairs(state.players) do
        if player.id == sender.user_id then
            player_index = i
            break
        end
    end

    if not player_index or player_index ~= state.current_player then
        return false, { error = "Not your turn" }
    end

    -- 2. Change de joueur pour le prochain tour
    state.current_player = (state.current_player % 2) + 1
    state.turn = state.turn + 1

    -- 3. Renvoie simplement l'action reçue (sans vérification)
    return true, {
        type = "action_processed",
        action = action_data,
        next_player = state.players[state.current_player].id,
        turn = state.turn
    }
end

return M
