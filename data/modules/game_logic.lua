local nk = require("nakama")
local board = require("game_logic.board")
local units = require("game_logic.units")
local cards = require("game_logic.cards")
local karma = require("game_logic.karma")
local actions = require("game_logic.actions")

local M = {}

-- ============================================
-- CONSTANTES
-- ============================================
local GRID_SIZE = 5

-- ============================================
-- INITIALISATION
-- ============================================
function M.init_game_state()
    print("[GAME_LOGIC] Init game state")

    return {
        units = {{}, {}},
        teams_loaded = {false, false},
        board = nil,
        cards_library = nil,
    }
end

-- ============================================
-- CHARGEMENT D'UNE ÉQUIPE
-- ============================================
function M.load_team(state, player_index, user_id, admin_user_id)
    if state.game_data.teams_loaded[player_index] then
        print("[GAME_LOGIC] ⚠️ Équipe déjà chargée")
        return false, "Équipe déjà chargée"
    end

    if not state.game_data.cards_library then
        local cards_lib, err = cards.load_cards_library(admin_user_id)
        if err then return false, err end
        state.game_data.cards_library = cards_lib
    end

    local user_team = nk.storage_read({
        {collection = "player_data", key = "team", user_id = user_id}
    })

    if not user_team or #user_team == 0 then
        return false, "Équipe non trouvée dans le storage"
    end

    local user_team_data = user_team[1].value
    if not user_team_data or not user_team_data.data then
        return false, "Format d'équipe invalide"
    end

    local team, err = units.create_units_from_team_data(
        user_team_data.data,
        state.game_data.cards_library,
        player_index
    )

    if not team then return false, err end

    -- Placer les unités sur le plateau
    if state.game_data.board then
        for unit_name, unit in pairs(team) do
            state.game_data.board[unit.x][unit.y].data.is_occupied = true
            state.game_data.board[unit.x][unit.y].data.occupant = {
                unit_id = unit_name,
                player = player_index
            }
        end
    end

    state.game_data.units[player_index] = team
    state.game_data.teams_loaded[player_index] = true

    return true, nil
end

-- ============================================
-- VÉRIFICATIONS
-- ============================================
function M.are_teams_ready(state)
    local ready = state.game_data.teams_loaded[1] and state.game_data.teams_loaded[2]
    print("[GAME_LOGIC] Teams ready: " .. tostring(ready))
    return ready
end

-- ============================================
-- ÉTAT DES UNITÉS
-- ============================================
function M.get_units_state(state)
    return units.get_units_state(state.game_data.units, state.players)
end

-- ============================================
-- ÉTAT DE LA GRILLE
-- ============================================
function M.get_board_state(state)
    if not state.game_data.board then return nil end

    local board_state = {}

    for x = 1, GRID_SIZE do
        board_state[x] = {}
        for y = 1, GRID_SIZE do
            local cell = state.game_data.board[x][y]
            board_state[x][y] = {
                position = cell.position,
                chess_position = cell.chess_position,
                quarters = cell.data.quarters,
                is_occupied = cell.data.is_occupied,
            }

            if cell.data.is_occupied and cell.data.occupant then
                board_state[x][y].occupant = {
                    unit_id = cell.data.occupant.unit_id,
                    player = cell.data.occupant.player,
                }
            end
        end
    end

    return board_state
end

-- ============================================
-- TRAITEMENT DES ACTIONS JOUEUR
-- ============================================
function M.process_player_action(state, player_id, action_data)
    return actions.process_player_action(state, player_id, action_data)
end

return M
