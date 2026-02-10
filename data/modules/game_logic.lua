local nk = require("nakama")
local M = {}

-- ============================================
-- CONSTANTES
-- ============================================
local GRID_SIZE = 5
local TEAM= {"side_left", "center_left", "king", "center_right", "side_right"}
local CARD_TYPE = {"0", "1", "2", "3", "4", "5", "6", "7", "8"}

local COLUMNS = {"A", "B", "C", "D", "E"}
local ROWS = {"1", "2", "3", "4", "5"}


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
    local board = {}
    local columns = {"A", "B", "C", "D", "E"}

    -- Calculer les karmas des deux équipes
    local karma_player1 = M.calculate_team_karma(state.game_data.units[1])
    local karma_player2 = M.calculate_team_karma(state.game_data.units[2])

    for x = 1, 5 do
        for y = 1, 5 do
             -- Calcul dynamique des quarts
            local num_karma1 = 5 - y  -- Nombre de quarts pour player1
            local quarters = {}

            -- Remplissage initial
            for i = 1, num_karma1 do quarters[i] = karma_player1 end
            for i = num_karma1 + 1, 4 do quarters[i] = karma_player2 end

            -- Mélange aléatoire
            for i = 4, 2, -1 do
                local j = math.random(i)
                quarters[i], quarters[j] = quarters[j], quarters[i]
            end

            -- Création de la case
            if not board[x] then board[x] = {} end
            board[x][y] = {
                position = {x = x, y = y},
                chess_position = columns[x] .. y,
                data = {
                    quarters = quarters,
                    is_occupied = false,
                    occupant = nil
                }
            }
        end
    end

    -- placer les unités dans la grille
    for player_index, team in pairs(state.game_data.units) do
        for unit_name, unit in pairs(team) do
            local x, y = unit.x, unit.y

            -- Vérifier que la case existe
            if board[x] and board[x][y] then
                board[x][y].data.is_occupied = true
                board[x][y].data.occupant = {
                    unit_id = unit_name,
                    player = player_index
                }
            else
                print(string.format("[GAME_LOGIC] ⚠️ Position invalide pour %s: (%d, %d)", unit_name, x, y))
            end
        end
    end

    return board
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
    -- Conversion des coordonnées en notation échiquéenne
    local chess_position = COLUMNS[x] .. ROWS[y]

    local unit = {
        x = x,
        y = y,
        chess_position = chess_position,
        alive = true,
        
        -- Cartes de l'unité (par type)
        cards = {
            ["0"] = nil,
            ["1"] = nil,
            ["2"] = nil,
            ["3"] = nil,
            ["4"] = nil,
            ["5"] = nil,
            ["6"] = nil,
            ["7"] = nil,
            ["8"] = nil
        },
        
        -- Stats (calculées plus tard)
        stats = {
            karma = 0,
            crystal_blue = 0,
            crystal_red = 0,
            crystals = 0,
            
            heart = 0,
            life = 0,
            
            defense = 0,
            attack = 0,
            xp = 0,
            level = 0
        },
        
        -- État
        effects = {},
        blocked = false
    }
    
    -- Charger chaque carte depuis la bibliothèque
    for card_type, card_id in pairs(unit_cards) do
        
        if card_id then
            -- Récupérer la carte depuis la bibliothèque
            local card_data = cards_library[card_id]
            
            if card_data then
                unit.cards[card_type] = card_data
            else
                print(string.format("[GAME_LOGIC]     ⚠️ Carte inconnue: %s", card_id))
            end
        end
    end
    
    -- Calculer les stats
    unit.stats = M.calculate_unit_stats(unit)

    -- Calculer du karma
    unit.stats.karma = M.calculate_unit_karma(unit_cards)
    

    return unit
end


-- ============================================
-- CALCUL DES ATTRIBUTS
-- ============================================
function M.calculate_unit_stats(unit)
    local stats = {
        karma = 0,
        crystal_blue = 0,
        crystal_red = 0,
        crystals = 0,
        heart = 0,
        life = 0,
        defense = 0,
        attack = 0,
        xp = 0,
        level = 0
    }

    for _, card_type in ipairs(CARD_TYPE) do
        local card = unit.cards[card_type]

        if card and card.data then
            local effects = {
                [1] = "crystal_blue",
                [2] = "crystal_red",
                [3] = "heart",
                [4] = "defense",
                [5] = "attack"
            }

            for i = 1, 3 do
                local value = card.data["slot" .. i]

                if value then
                    local effect = math.floor(value)
                    local attr = effects[effect]

                    if attr then
                        stats[attr] = stats[attr] + 1
                    end
                end
            end
        else
            print(string.format("[GAME_LOGIC] Pas de données pour la carte %s", card_type))
        end
    end

    stats.crystals = stats.crystal_blue + stats.crystal_red
    stats.life = stats.heart

    return stats -- Ajout du retour des attributs calculés
end


-- ============================================
-- CALCUL DU KARMA D'UNE UNITÉ
-- ============================================
function M.calculate_unit_karma(unit_cards)
    return M.calculate_karma(unit_cards)
end


-- ============================================
-- CALCUL DU KARMA D'UNE ÉQUIPE
-- ============================================
function M.calculate_team_karma(team_units)
    local all_card_ids = {}

    -- Collecter toutes les cartes de toutes les unités
    for _, unit in pairs(team_units) do
        for card_type, card_data in pairs(unit.cards) do
            if card_data and card_data.id then
                table.insert(all_card_ids, card_data.id)
            end
        end
    end

    return M.calculate_karma(all_card_ids)
end


-- ============================================
-- CALCUL DU KARMA (GÉNÉRIQUE)
-- ============================================
function M.calculate_karma(card_values)
    -- Tables pour stocker les comptages et valeurs minimales
    local sign_count = {}    -- Compte les occurrences de chaque dizaine
    local min_hundreds = {}  -- Stocke le chiffre des centaines minimal pour chaque dizaine

    -- Parcours de toutes les valeurs fournies
    for _, str_value in pairs(card_values) do
        -- Conversion en nombre (0 si conversion échoue)
        local value = tonumber(str_value) or 0

        -- Extraction des chiffres des centaines et dizaines
        local hundreds = math.floor(value / 100)  -- Chiffre des centaines
        local tens = math.floor((value % 100) / 10)  -- Chiffre des dizaines

        -- Comptage des occurrences de cette dizaine
        sign_count[tens] = (sign_count[tens] or 0) + 1

        -- Mise à jour du chiffre des centaines minimal pour cette dizaine
        if not min_hundreds[tens] or hundreds < min_hundreds[tens] then
            min_hundreds[tens] = hundreds
        end
    end

    -- Détermination de la dizaine dominante (karma)
    local karma = nil
    local max_count = 0

    for tens, count in pairs(sign_count) do
        local hundreds = min_hundreds[tens]

        -- Critères de sélection :
        -- 1. La dizaine avec le plus d'occurrences
        -- 2. En cas d'égalité, celle avec le chiffre des centaines le plus petit
        if count > max_count or
           (count == max_count and (not karma or hundreds < min_hundreds[karma])) then
            max_count = count
            karma = tens
        end
    end

    return karma or 0  -- Retourne 0 si aucun karma trouvé
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


return M