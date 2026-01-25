local nk = require("nakama")
local game_logic = require("game_logic")
local M = {}

-- ID de l'admin (à configurer selon votre setup)
local ADMIN_USER_ID = "3c1485bf-c58c-4f11-b602-1df56fff3076"  -- ⚠️ REMPLACER PAR VOTRE ADMIN ID

-- ============================================
-- INITIALISATION DU MATCH
-- ============================================
function M.match_init(context, params)
    print("[MATCH] Initialisation du match")
    
    local state = {
        players = {},
        current_player = 1,
        turn = 1,
        game_started = false,
        game_data = game_logic.init_game_state()
    }
    
    print("[MATCH] État initial créé")
    return state, 1, "Turn-based game"
end

-- ============================================
-- TENTATIVE DE REJOINDRE
-- ============================================
function M.match_join_attempt(context, dispatcher, tick, state, presence, metadata)
    print("[MATCH] Tentative de connexion de " .. presence.username)
    
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
    
    print("[MATCH] Connexion acceptée")
    return state, true
end

-- ============================================
-- JOUEUR A REJOINT
-- ============================================
function M.match_join(context, dispatcher, tick, state, presences)
    for _, presence in ipairs(presences) do
        print("[MATCH] Joueur rejoint: " .. presence.username)
        
        -- Ajouter le joueur
        table.insert(state.players, {
            id = presence.user_id,
            name = presence.username,
            session = presence.session_id,
            team_loaded = false  -- Nouveau: indicateur d'équipe chargée
        })
        
        -- Notifier tous les joueurs
        local msg = {
            type = "player_joined",
            count = #state.players,
            player = {
                id = presence.user_id,
                username = presence.username
            }
        }
        dispatcher.broadcast_message(1, nk.json_encode(msg))
        
        print("[MATCH] " .. #state.players .. "/2 joueurs connectés")
    end
    
    -- Si 2 joueurs, demander le chargement des équipes
    if #state.players == 2 then
        local function load_team_for_player(player, team_number)
            local success, err = game_logic.load_team(state, team_number, player.id, ADMIN_USER_ID)
            if not success then
                print("[MATCH] ⚠️ Erreur chargement équipe joueur " .. team_number .. ": " .. err)
                local error_msg = { type = "error", message = "Erreur chargement équipe joueur " .. team_number .. ": " .. err }
                dispatcher.broadcast_message(1, nk.json_encode(error_msg))
                return false
            end

            player.team_loaded = true
            print("[MATCH] ✅ Équipe joueur " .. team_number .. " chargée")

            local team_msg = { type = "team_loaded", player = team_number, player_name = player.name }
            dispatcher.broadcast_message(1, nk.json_encode(team_msg))
            return true
        end

        -- Boucle sur tous les joueurs
        for i, player in ipairs(state.players) do
            if not load_team_for_player(player, i) then
                return state
            end
        end
        
        -- Démarrer le jeu
        if game_logic.are_teams_ready(state) then
            print("[MATCH] 🎮 Démarrage du jeu!")
            
            state.game_started = true
            
            local start_msg = {
                type = "game_start",
                current_player = state.players[state.current_player].id,
                current_player_name = state.players[state.current_player].name,
                turn = state.turn,
                board_state = game_logic.get_board_state(state)
            }
            
            dispatcher.broadcast_message(1, nk.json_encode(start_msg))
            print("[MATCH] ✅ Message game_start envoyé")
        end
    end
    
    return state
end

-- ============================================
-- JOUEUR A QUITTÉ
-- ============================================
function M.match_leave(context, dispatcher, tick, state, presences)
    for _, presence in ipairs(presences) do
        print("[MATCH] Joueur quitte: " .. presence.user_id)
        
        for i, player in ipairs(state.players) do
            if player.session == presence.session_id then
                table.remove(state.players, i)
                
                local msg = {
                    type = "player_left",
                    player_id = player.id,
                    player_name = player.name
                }
                dispatcher.broadcast_message(1, nk.json_encode(msg))
                
                -- Si le jeu avait commencé, l'autre joueur gagne
                if state.game_started and #state.players == 1 then
                    print("[MATCH] Victoire par abandon")
                    
                    local winner = state.players[1]
                    local game_over_msg = {
                        type = "game_over",
                        reason = "opponent_left",
                        winner = winner.id,
                        winner_name = winner.name
                    }
                    dispatcher.broadcast_message(1, nk.json_encode(game_over_msg))
                    
                    return nil  -- Terminer le match
                end
                
                break
            end
        end
    end
    
    -- Si plus de joueurs, terminer le match
    if #state.players == 0 then
        print("[MATCH] Plus de joueurs, fermeture du match")
        return nil
    end
    
    return state
end

-- ============================================
-- BOUCLE PRINCIPALE (vide pour l'instant)
-- ============================================
function M.match_loop(context, dispatcher, tick, state, messages)
    -- Pour l'instant, on ne fait rien
    -- On implémentera le chargement des équipes plus tard
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