-- match_handler.lua
local nk = require("nakama")
local game_board = require("game_logic.board")
local game_units = require("game_logic.units")
local match_players = require("match.players")
local match_turn = require("match.turn")
local M = {}

local ADMIN_USER_ID = "319f9d0f-06fc-4805-a900-be0d22a09b21"

-- ============================================
-- INITIALISATION DU MATCH
-- ============================================
function M.match_init(context, params)
    local state = {
        players = {},
        current_player = 1,
        turn = 1,
        game_started = false,
        game_data = {
            units = {{}, {}},
            teams_loaded = {false, false},
            board = nil,
            cards_library = nil,
        }
    }

    return state, 1, "Kingfield Match"
end

-- ============================================
-- TENTATIVE DE REJOINDRE
-- ============================================
function M.match_join_attempt(context, dispatcher, tick, state, presence, metadata) 
    -- Refuser si le jeu a déjà commencé
    if state.game_started then
        print("[MATCH] Refusé: Partie déjà commencée")
        return state, false, "Game already started"
    end
    
    -- Refuser si déjà 2 joueurs
    if #state.players >= 2 then
        print("[MATCH] Refusé: Match complet")
        return state, false, "Match full"
    end
    
    return state, true
end

-- ============================================
-- JOUEUR A REJOINT
-- ============================================
function M.match_join(context, dispatcher, tick, state, presences)
    state = match_players.handle_join(state, dispatcher, presences) 

    -- Si 2 joueurs, demander le chargement des équipes
    if #state.players == 2 then
        local function load_team_for_player(player, team_number)
            local success, err = game_units.load_team(state, team_number, player.id, ADMIN_USER_ID)
            if not success then
                print("[MATCH] ⚠️ Erreur chargement équipe joueur " .. team_number .. ": " .. err)
                local error_msg = {
                    type = "error",
                    message = "Erreur chargement équipe joueur " .. team_number .. ": " .. err
                }
                dispatcher.broadcast_message(1, nk.json_encode(error_msg))
                return false
            end

            player.team_loaded = true

            -- Vérifier si les deux équipes sont chargées
            if state.game_data.teams_loaded[1] and state.game_data.teams_loaded[2] then
                print("[MATCH] Teams ready : true")
                -- Créer la grille avec les karmas des équipes
                state.game_data.board = game_board.create_board(state)

                -- Démarrer le jeu
                state.game_started = true

                local start_msg = {
                    type = "game_start",
                    current_player = state.players[state.current_player].id,
                    current_player_name = state.players[state.current_player].name,
                    turn = state.turn,
                    units_state = game_units.get_units_state(state.game_data.units, state.players),
                    board_state = game_board.get_board_state(state),  -- Ajout de l'état du board
                    karma_value = {
                        [1] = game_units.calculate_team_karma(state.game_data.units[1]),
                        [2] = game_units.calculate_team_karma(state.game_data.units[2])
                    }
                }

                dispatcher.broadcast_message(1, nk.json_encode(start_msg))
                print("[MATCH] 🎮 Game_start message sended with board state")
            end

            return true
        end

        -- Boucle sur tous les joueurs
        for i, player in ipairs(state.players) do
            if not load_team_for_player(player, i) then
                return state
            end
        end
    end

    return state
end

-- ============================================
-- JOUEUR A QUITTÉ
-- ============================================
function M.match_leave(context, dispatcher, tick, state, presences)
    return match_players.handle_leave(state, dispatcher, presences)
end

-- ============================================
-- BOUCLE PRINCIPALE (vide pour l'instant)
-- ============================================
function M.match_loop(context, dispatcher, tick, state, messages)
    for _, message in ipairs(messages) do
        local decoded = nk.json_decode(message.data)
        
        if decoded.type == "action" then
            print("[MATCH] Action reçue pour le tour", decoded.turn)
            local success, result = match_turn.process_action(state, message.sender, decoded)

             if success then
                -- Envoie le résultat à tous les joueurs
                dispatcher.broadcast_message(1, nk.json_encode(result))
            else
                dispatcher.broadcast_message(1, nk.json_encode(result), { message.sender })
            end

        end
    end
    return state
end

-- ============================================
-- FIN DU MATCH
-- ============================================
function M.match_terminate(context, dispatcher, tick, state, grace_seconds)
    print("[MATCH] Match terminé")
    return state
end

-- ============================================
-- SIGNAUX EXTERNES
-- ============================================
function M.match_signal(context, dispatcher, tick, state, data)
    return state, ""
end

return M
