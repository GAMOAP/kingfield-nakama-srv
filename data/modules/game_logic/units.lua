-- modules/game_logic/units.lua
local nk = require("nakama")
local karma = require("game_logic.karma")
local cards = require("game_logic.cards")
local helpers = require("utils.helpers")

local M = {}

-- ============================================
-- CONSTANTES
-- ============================================
local CARD_TYPE = {"0", "1", "2", "3", "4", "5", "6", "7", "8"}
local TEAM = {"side_left", "center_left", "king", "center_right", "side_right"}

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

    local team, err = M.create_units_from_team_data(
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
-- CRÉER UNE UNITÉ
-- ============================================
function M.create_unit(x, y, unit_cards, cards_library)
    local unit = {
        x = x,
        y = y,
        chess_position = helpers.coords_to_chess(x, y),
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
    unit.stats.karma = karma.calculate_karma(unit_cards)
    

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
-- CRÉATION DES UNITÉS D'UNE ÉQUIPE
-- ============================================
function M.create_units_from_team_data(team_data, cards_library, player_index)
    local start_y = (player_index == 1) and 1 or 5
    local team = {}

    for i, unit_name in ipairs(TEAM) do
        local unit_cards = team_data[unit_name]["cards"]

        if not unit_cards then
            return false, string.format("Position manquante: %s", unit_name)
        end

        -- Vérifier que toutes les cartes sont présentes
        for _, card in ipairs(CARD_TYPE) do
            if not unit_cards[card] then
                return false, string.format("Carte manquante: %s slot %s", unit_name, card)
            end
        end

        local x = i
        local unit = M.create_unit(x, start_y, unit_cards, cards_library)

        if not unit then
            return false, string.format("Erreur création unité: %s", unit_name)
        end

        team[unit_name] = unit
    end

    return team, nil
end

-- ============================================
-- CALCUL DU KARMA D'UNE ÉQUIPE
-- ============================================
function M.calculate_team_karma(team_units)
    local all_card_ids = {}

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
-- EXTRACTION DE L'ÉTAT DES UNITÉS
-- ============================================
function M.get_units_state(units, players)
    local board = {
        units = {}
    }

    for player_num = 1, 2 do
        local player_id = players[player_num].id

        if player_id and units[player_num] then
            board.units[player_id] = {}

            for unit_name, unit in pairs(units[player_num]) do
                board.units[player_id][unit_name] = {
                    x = unit.x,
                    y = unit.y,
                    chess_position = unit.chess_position,
                    alive = unit.alive,
                    stats = unit.stats,
                    cards = {}
                }

                for card_type, card_data in pairs(unit.cards) do
                    board.units[player_id][unit_name].cards[card_type] =
                        card_data and card_data.id or nil
                end
            end
        end
    end

    return board
end

return M