local nk = require("nakama")
local board = require("game_logic.board")
local units = require("game_logic.units")
local karma = require("game_logic.karma")
local actions = require("game_logic.actions")
local M = {}

-- ============================================
-- CONSTANTES
-- ============================================
local GRID_SIZE = 5
local TEAM= {"side_left", "center_left", "king", "center_right", "side_right"}
local CARD_TYPE = {"0", "1", "2", "3", "4", "5", "6", "7", "8"}


-- ============================================
-- INITIALISATION
-- ============================================
function M.init_game_state()
    print("[GAME_LOGIC] Init game state")
    
    return {
        units = {{}, {}},
        teams_loaded = {false, false},
        board = nil, -- Grille de jeu
        cards_library = nil,  -- Bibliothèque de cartes globale
    }
end


-- ============================================
-- CHARGEMENT DE LA GRILLE
-- ============================================
function M.create_board(state)
    return board.create_board(state)
end

-- ============================================
-- CHARGEMENT DE LA BIBLIOTHÈQUE DE CARTES
-- ============================================
function M.load_cards_library(admin_user_id)
    -- Lire depuis le storage
    local library_Ids = {
        {
            collection = "global_data",
            key = "cards",
            user_id = admin_user_id
        }
    }
    
    local cards_library = nk.storage_read(library_Ids)
    
    if not cards_library or #cards_library == 0 then
        print("[GAME_LOGIC] ⚠️ Bibliothèque de cartes introuvable")
        return nil, "Bibliothèque de cartes non trouvée"
    end
    
    local cards_data = cards_library[1].value
    
    if not cards_data or not cards_data.data then
        print("[GAME_LOGIC] ⚠️ Format de bibliothèque invalide")
        return nil, "Format de bibliothèque invalide"
    end
    
    print("[GAME_LOGIC] Library loaded")
    return cards_data.data, nil
end


-- ============================================
-- CHARGEMENT D'UNE ÉQUIPE
-- ============================================
function M.load_team(state, player_index, user_id, admin_user_id)
    
    -- Vérifier si l'équipe n'est pas déjà chargée
    if state.game_data.teams_loaded[player_index] then
        print("[GAME_LOGIC] ⚠️ Équipe déjà chargée")
        return false, "Équipe déjà chargée"
    end
    
    -- Charger la bibliothèque de cartes si pas encore fait
    if not state.game_data.cards_library then
        local cards_lib, err = M.load_cards_library(admin_user_id)
        if err then
            return false, err
        end
        state.game_data.cards_library = cards_lib
    end
    
    -- Lire la composition de l'équipe depuis le storage
    local user_team_Ids = {
        {
            collection = "player_data",
            key = "team",
            user_id = user_id
        }
    }
    
    local user_team = nk.storage_read(user_team_Ids)
    
    if not user_team or #user_team == 0 then
        print("[GAME_LOGIC] ⚠️ Équipe non trouvée pour " .. user_id)
        return false, "Équipe non trouvée dans le storage"
    end
    
    local user_team_data = user_team[1].value
    
    if not user_team_data or not user_team_data.data then
        print("[GAME_LOGIC] ⚠️ Format d'équipe invalide")
        return false, "Format d'équipe invalide"
    end
    
    -- Créer les unités
    local success, err = M.create_units_from_team_data(state, player_index, user_team_data.data)
    
    if not success then
         print(string.format("[GAME_LOGIC] ⚠️ Erreur chargement de l'équipe ; %s", err))
        return false, err
    end

    -- Marquer l'équipe comme chargée
    state.game_data.teams_loaded[player_index] = true
    
    return true, nil
end


-- ============================================
-- CRÉATION DES UNITÉS
-- ============================================
function M.create_units_from_team_data(state, player_index, team_data)
    
    -- Position Y de départ selon le joueur
    local start_y = (player_index == 1) and 1 or 5
    
    local team = {}
    
    -- Parcourir chaque character (side_left, center_left, king, etc.)
    for i, unit_name in ipairs(TEAM) do
        local unit_cards = team_data[unit_name]["cards"]
        
        if not unit_cards then
            print(string.format("[GAME_LOGIC] ⚠️ Position manquante: %s", unit_name))
            return false, string.format("Position manquante: %s", unit_name)
        end
        
        -- Vérifier que toutes les cartes sont présentes (0-8)
        for _, card in ipairs(CARD_TYPE) do
            if not unit_cards[card] then
                print(string.format("[GAME_LOGIC] ⚠️ Carte manquante: %s slot %s", unit_name, card))
                return false, string.format("Carte manquante: %s slot %s", unit_name, card)
            end
        end
        
        -- Calculer la position X (1-5 selon l'ordre dans TEAM)
        local x = i

        -- Créer l'unité
        local unit = M.create_unit(x, start_y, unit_cards, state.game_data.cards_library)
        
        if not unit then
            return false, string.format("Erreur création unité: %s", unit_name)
        end

         -- Placer l'unité sur le plateau (après création de la grille)
        if state.game_data.board then
            state.game_data.board[x][start_y].data.is_occupied = true
            state.game_data.board[x][start_y].data.occupant = {
                unit_id = unit_name,
                player = player_index
            }
        end

        
        team[unit_name] = unit
    end
    
    -- Enregistrer les unités
    state.game_data.units[player_index] = team
    
    return true, nil
end


-- ============================================
-- CRÉER UNE UNITÉ
-- ============================================
function M.create_unit(x, y, unit_cards, cards_library)
    return units.create_unit(x, y, unit_cards, cards_library)
end


-- ============================================
-- CALCUL DU KARMA D'UNE UNITÉ
-- ============================================
function M.calculate_unit_karma(unit_cards)
    return karma.calculate_karma(unit_cards)
end


-- ============================================
-- CALCUL DU KARMA D'UNE ÉQUIPE
-- ============================================
function M.calculate_team_karma(team_units)
    local all_card_ids = {}

    -- Collecter toutes les cartes de toutes les unités
    for _, unit in pairs(team_units) do
        for _, card_data in pairs(unit.cards) do
            if card_data and card_data.id then
                table.insert(all_card_ids, card_data.id)
            end
        end
    end

    return karma.calculate_karma(all_card_ids)
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
    local board = {
        units = {}
    }

    -- Boucle sur les deux joueurs (1 et 2)
    for player_num = 1, 2 do
        -- Récupère l'ID réel du joueur
        local player_id = state.players[player_num].id

        -- Vérifie que les unités du joueur existent dans game_data
        if player_id and state.game_data.units[player_num] then
            -- Initialise la table des unités pour ce joueur
            board.units[player_id] = {}

            -- Boucle sur les unités du joueur
            for unit_name, unit in pairs(state.game_data.units[player_num]) do
                -- Initialise la structure de l'unité
                board.units[player_id][unit_name] = {
                    x = unit.x,
                    y = unit.y,
                    chess_position = unit.chess_position,
                    alive = unit.alive,
                    stats = unit.stats,
                    cards = {}
                }

                -- Boucle sur les cartes de l'unité
                for card_type, card_data in pairs(unit.cards) do
                    board.units[player_id][unit_name].cards[card_type] =
                        card_data and card_data.id or nil
                end
            end
        end
    end
    
    return board
end

-- ============================================
-- ÉTAT DE LA GRILLE
-- ============================================
function M.get_board_state(state)
    if not state.game_data.board then
        return nil
    end

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

            -- Si la case est occupée, ajouter les infos de l'unité
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