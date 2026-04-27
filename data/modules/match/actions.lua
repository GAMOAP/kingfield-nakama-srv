-- modules/match/actions.lua
local nk = require("nakama")
local game_units = require("game_logic.units")

local M = {}

-- ============================================
-- ENUM DES ACTIONS (correspond à votre enum en GDScript)
-- ============================================
M.ACTION_ID = {
    MOVE = 10,
    STRIKE = 11,
    HEALTH = 12,
    CRYSTAL_BREAK = 13,
    GIVE_XP = 14,
    ATTACK_MORE = 20,
    ATTACK_LESS = 21,
    DEFENSE_MORE = 22,
    DEFENSE_LESS = 23,
    BLOCK = 24,
    SLEEP = 25,
    POISON = 26
}

-- ============================================
-- FONCTIONS D'APPLICATION DES ACTIONS
-- ============================================
-- @param state (table) : État du match
-- @param player_index (number) : Index du joueur (1 ou 2)
-- @param action (table) : Données de l'action (ex: { unit_name = "king", card_id = "560", ... })
-- @return (boolean, string) : (succès, message d'erreur si échec)
function M.apply_action(state, player_index, action)
    local unit = state.game_data.units[player_index][action.unit_name]
    if not unit then
        return false, "Unité introuvable"
    end

    -- Applique l'action en fonction de son type
    if action.action_id == M.ACTION_ID.MOVE then
        return M.apply_move(state, player_index, action)
    elseif action.action_id == M.ACTION_ID.STRIKE then
        return M.apply_strike(state, player_index, action)
    elseif action.action_id == M.ACTION_ID.HEALTH then
        return M.apply_health(state, player_index, action)
    -- Ajoutez d'autres actions ici...
    else
        return false, "Type d'action inconnu"
    end
end

-- ============================================
-- IMPLÉMENTATION DES ACTIONS
-- ============================================
-- Exemple : Déplacement (MOVE)
function M.apply_move(state, player_index, action)
    local unit = state.game_data.units[player_index][action.unit_name]
    local board = state.game_data.board
    local target_block = nil

    -- 1. Vérifie que la case de destination est valide et libre
    for _, col in pairs(board) do
        for _, block in pairs(col) do
            if block.chess_position == action.block_label and block.data.is_occupied == false then
                target_block = action.block_label
                break
            end
        end
    end

    if not target_block then
        return false, "Case de destination invalide"
    end

    -- 3. Déplace l'unité
    unit.position = action.block_label
    return true, "Déplacement effectué"
end

-- Exemple : Attaque (STRIKE)
function M.apply_strike(state, player_index, action)
    local unit = state.game_data.units[player_index][action.unit_name]
    local target_player = (player_index % 2) + 1  -- L'autre joueur
    local target_unit = nil

    -- 1. Trouve l'unité cible (si elle existe)
    for _, u in pairs(state.game_data.units[target_player]) do
        if u.position == action.block_label then
            target_unit = u
            break
        end
    end

    if not target_unit then
        return false, "Aucune unité ennemie sur cette case"
    end

    -- 2. Applique les dégâts (simplifié)
    target_unit.health = target_unit.health - unit.attack
    return true, "Attaque réussie"
end

-- Exemple : Soin (HEALTH)
function M.apply_health(state, player_index, action)
    local unit = state.game_data.units[player_index][action.unit_name]
    unit.health = unit.health + 10  -- Soin de 10 PV (à adapter)
    return true, "Soin appliqué"
end

return M
