-- modules/game_logic/units.lua
local karma = require("game_logic.karma")
local helpers = require("utils.helpers")

local M = {}

-- ============================================
-- CONSTANTES
-- ============================================
local CARD_TYPE = {"0", "1", "2", "3", "4", "5", "6", "7", "8"}

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

return M