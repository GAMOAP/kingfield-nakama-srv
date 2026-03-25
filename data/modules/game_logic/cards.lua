-- modules/game_logic/cards.lua
local nk = require("nakama")
local helpers = require("utils.helpers")

local M = {}

-- ============================================
-- CHARGEMENT DE LA BIBLIOTHÈQUE DE CARTES
-- ============================================
function M.load_cards_library(admin_user_id)
    if not admin_user_id then
        return nil, "Admin user ID is required"
    end

    local library_ids = {
        {
            collection = "global_data",
            key = "cards",
            user_id = admin_user_id
        }
    }

    local cards_library = nk.storage_read(library_ids)

    if not cards_library or #cards_library == 0 then
        print("[GAME_LOGIC] ⚠️ Bibliothèque de cartes introuvable")
        return nil, "Cards library not found in storage"
    end

    local cards_data = cards_library[1].value

    if not cards_data or not cards_data.data then
        print("[GAME_LOGIC] ⚠️ Format de bibliothèque invalide")
        return nil, "Invalid cards library format"
    end

    print("[GAME_LOGIC] Library loaded")
    return cards_data.data, nil
end

-- ============================================
-- RÉCUPÉRATION D'UNE CARTE
-- ============================================
function M.get_card(card_id, cards_library)
    if not card_id or not cards_library then
        return nil
    end

    return cards_library[card_id]
end

-- ============================================
-- VALIDATION D'UNE CARTE
-- ============================================
function M.is_card_valid_for_action(card_id, cards_library, action_type)
    local card = M.get_card(card_id, cards_library)
    if not card then
        return false, "Card not found"
    end

    -- Exemple : Vérifier que la carte est une compétence pour une action de type "skill"
    if action_type == "skill" and card.type ~= M.CARD_TYPES.SKILL then
        return false, "This card is not a skill"
    end

    -- Autres validations selon le type d'action...
    return true, nil
end

return M