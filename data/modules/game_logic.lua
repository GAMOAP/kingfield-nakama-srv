local nk = require("nakama")
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
    print("[GAME_LOGIC] Initialisation de l'état du jeu")
    
    return {
        units = {{}, {}},
        teams_loaded = {false, false},
        cards_library = nil  -- Bibliothèque de cartes globale
    }
end

-- ============================================
-- CHARGEMENT DE LA BIBLIOTHÈQUE DE CARTES
-- ============================================

function M.load_cards_library(admin_user_id)
    print("[GAME_LOGIC] Chargement de la bibliothèque de cartes")
    
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
    
    local cards_data = nk.json_decode(cards_library[1].value)
    
    if not cards_data or not cards_data.data then
        print("[GAME_LOGIC] ⚠️ Format de bibliothèque invalide")
        return nil, "Format de bibliothèque invalide"
    end
    
    print("[GAME_LOGIC] ✅ Bibliothèque de cartes chargée")
    return cards_data.data, nil
end

-- ============================================
-- CHARGEMENT D'UNE ÉQUIPE
-- ============================================

function M.load_team(state, player_index, user_id, admin_user_id)
    print(string.format("[GAME_LOGIC] Chargement de l'équipe du joueur %d (user_id: %s)", player_index, user_id))
    
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
    
    local user_team_data = nk.json_decode(user_team[1].value)
    
    if not user_team_data or not user_team_data.data then
        print("[GAME_LOGIC] ⚠️ Format d'équipe invalide")
        return false, "Format d'équipe invalide"
    end
    
    print("[GAME_LOGIC] 📦 Données d'équipe récupérées")
    
    -- Créer les unités
    local success, err = M.create_char_from_team_data(state, player_index, user_team_data.data)
    
    if not success then
        return false, err
    end
    
    -- Marquer l'équipe comme chargée
    state.game_data.teams_loaded[player_index] = true
    
    print(string.format("[GAME_LOGIC] ✅ Équipe du joueur %d chargée avec succès", player_index))
    
    return true, nil
end

-- ============================================
-- CRÉATION DES UNITÉS
-- ============================================

function M.create_char_from_team_data(state, player_index, team_data)
    print(string.format("[GAME_LOGIC] Création des unités pour le joueur %d", player_index))
    
    -- Position Y de départ selon le joueur
    local start_y = (player_index == 1) and 0 or 4
    
    local team = {}
    
    -- Parcourir chaque character (side_left, center_left, king, etc.)
    for i, char_name in ipairs(TEAM) do
        local char_cards = team_data[char_name]
        
        if not char_cards then
            print(string.format("[GAME_LOGIC] ⚠️ Position manquante: %s", char_name))
            return false, string.format("Position manquante: %s", char_name)
        end
        
        -- Vérifier que toutes les cartes sont présentes (0-8)
        for _, card in ipairs(CARD_TYPE) do
            if not char_cards[card] then
                print(string.format("[GAME_LOGIC] ⚠️ Carte manquante: %s slot %s", char_name, card))
                return false, string.format("Carte manquante: %s slot %s", char_name, card)
            end
        end
        
        -- Créer l'unité
        local char = M.create_char(i, start_y, char_name, char_cards, state.game_data.cards_library)
        
        if not char then
            return false, string.format("Erreur création unité: %s", char_name)
        end
        
        team[char_name] = char
        
        print(string.format("[GAME_LOGIC]   ✓ Unité créée: %s à (%d, %d)", char_name, i, start_y))
    end
    
    -- Enregistrer les unités
    state.game_data.units[player_index] = team
    
    print(string.format("[GAME_LOGIC] ✅ %d unités créées", #TEAM))
    
    return true, nil
end

-- ============================================
-- CRÉER UNE UNITÉ
-- ============================================

function M.create_char(x, y, char_name, char_cards, cards_library)
    local char = {
        x = x,
        y = y,
        position_name = char_name,
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
        attributes = {
            Karma = 0,
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
        blocked = false,
        sleeping = 0
    }
    
    -- Charger chaque carte depuis la bibliothèque
    for card_type, card_id in pairs(char_cards) do
        
        if card_id then
            -- Récupérer la carte depuis la bibliothèque
            local card_data = cards_library[card_id]
            
            if card_data then
                char.cards[card_type] = card_data
                print(string.format("[GAME_LOGIC]     Carte %s (%s): %s", card_type, card_id, card_data.name or "sans nom"))
            else
                print(string.format("[GAME_LOGIC]     ⚠️ Carte inconnue: %s", card_id))
            end
        end
    end
    
    -- Calculer les stats
    char.attributes = M.calculate_unit_stats(char)
    
    return char
end

-- ============================================
-- CALCUL DES ATTRIBUTS
-- ============================================

function M.calculate_unit_stats(char)
    local attributes = {
        Karma = 0,
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
        local card = char.cards[card_type]
        
        if card.data then

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
                        attributes[attr] = attributes[attr] + 1
                    end
                end
            end
        end
    end
    
    attributes.crystals = attributes.crystal_blue + attributes.crystal_red
    
    attributes.life = attributes.heart
    
    
end

-- ============================================
-- CALCUL DU KARMA
-- ============================================

function M.get_karma(_char_data)
    local sign_count = {}
    local min_hundreds = {}

    -- Parcours de toutes les valeurs
    for _, str_value in pairs(_char_data) do
        local value = tonumber(str_value) or 0
        local hundreds = math.floor(value / 100)
        local tens = math.floor((value % 100) / 10)

        -- Compte des dizaines
        sign_count[tens] = (sign_count[tens] or 0) + 1

        -- Garde le plus petit chiffre des centaines pour cette dizaine
        if min_hundreds[tens] == nil or hundreds < min_hundreds[tens] then
            min_hundreds[tens] = hundreds
        end
    end

    -- Détermine la "dizaine gagnante" (karma)
    local karma = nil
    local max_count = 0
    for tens, count in pairs(sign_count) do
        local hundreds = min_hundreds[tens]
        if count > max_count or (count == max_count and (karma == nil or hundreds < min_hundreds[karma])) then
            max_count = count
            karma = tens
        end
    end

    return karma
end


-- ============================================
-- VÉRIFICATIONS
-- ============================================

function M.are_teams_ready(state)
    local ready = state.game_data.teams_loaded[1] and state.game_data.teams_loaded[2]
    print("[GAME_LOGIC] Équipes prêtes: " .. tostring(ready))
    return ready
end

-- ============================================
-- ÉTAT DU PLATEAU
-- ============================================

function M.get_board_state(state)
    print("[GAME_LOGIC] Récupération de l'état du plateau")
    
    local board = {
        units = {
            player1 = {},
            player2 = {}
        }
    }
    
    for unit_name, unit in pairs(state.game_data.units[1]) do
        board.units.player1[unit_name] = {
            x = unit.x,
            y = unit.y,
            position_name = unit.position_name,
            alive = unit.alive,
            stats = unit.stats,
            cards = {
                breed = unit.cards.breed and unit.cards.breed.name or nil,
                job = unit.cards.job and unit.cards.job.name or nil,
                helmet = unit.cards.helmet and unit.cards.helmet.name or nil,
                item = unit.cards.item and unit.cards.item.name or nil,
                armor = unit.cards.armor and unit.cards.armor.name or nil,
                move = unit.cards.move and unit.cards.move.name or nil,
                spell = unit.cards.spell and unit.cards.spell.name or nil,
                weapon = unit.cards.weapon and unit.cards.weapon.name or nil,
                object = unit.cards.object and unit.cards.object.name or nil
            }
        }
    end
    
    for unit_name, unit in pairs(state.game_data.units[2]) do
        board.units.player2[unit_name] = {
            x = unit.x,
            y = unit.y,
            position_name = unit.position_name,
            alive = unit.alive,
            stats = unit.stats,
            cards = {
                breed = unit.cards.breed and unit.cards.breed.name or nil,
                job = unit.cards.job and unit.cards.job.name or nil,
                helmet = unit.cards.helmet and unit.cards.helmet.name or nil,
                item = unit.cards.item and unit.cards.item.name or nil,
                armor = unit.cards.armor and unit.cards.armor.name or nil,
                move = unit.cards.move and unit.cards.move.name or nil,
                spell = unit.cards.spell and unit.cards.spell.name or nil,
                weapon = unit.cards.weapon and unit.cards.weapon.name or nil,
                object = unit.cards.object and unit.cards.object.name or nil
            }
        }
    end
    
    return board
end

return M