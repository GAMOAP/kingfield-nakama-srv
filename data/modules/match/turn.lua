-- modules/match/turn.lua
local nk = require("nakama")
local game_units = require("game_logic.units")
local match_actions = require("match.actions")

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
        return false, {
            type = "error",
            message = "Ce n'est pas votre tour",
            current_player = state.players[state.current_player].id
        }
    end

    -- 2. Vérifie que le numéro de tour correspond
    if action_data.turn ~= state.turn then
        return false, {
            type = "error",
            message = "Numéro de tour invalide",
            expected_turn = state.turn,
            received_turn = action_data.turn
        }
    end

    -- 3. Valide toutes les actions
    local all_actions_valid = true
    local error_message = nil

    for _, action in ipairs(action_data.actions) do

        -- 3.1. Vérifie que l'unité existe
        local unit = state.game_data.units[player_index][action.unit_name]
        if not unit then
            error_message = "Unité introuvable"
            all_actions_valid = false
            goto continue  -- Passe à l'action suivante
        end

        -- 3.2. Vérifie que l'unité possède la carte
        local has_card = false
        for _, card_data in pairs(unit.cards) do
            if card_data["id"] == action.card_id then
                has_card = true
            end
        end

        if not has_card then
            error_message = "L'unité ne possède pas cette carte"
            all_actions_valid = false
            goto continue
        end

        ::continue::
    end

    -- SEULEMENT si toutes les actions sont valides
    if all_actions_valid then

        -- 4. Applique les actions si elles sont valides
        local execution_results = {}
        for _, action in ipairs(action_data.actions) do
            local success, err = match_actions.apply_action(state, player_index, action)
            if not success then
                return false, {
                    type = "turn_error",
                    message = err
                }
            end
        end

        -- 5. Change de tour
        state.current_player = (state.current_player % 2) + 1
        state.turn = state.turn + 1

         -- 5. Retourne les résultats
        return true, {
            type = "turn_processed",
            turn = state.turn,
            next_player = state.players[state.current_player].id,
            actions = action_data.actions
        }
    else
        return false, {
            type = "turn_error",
            message = error_message,
        }
    end

   
end

return M
