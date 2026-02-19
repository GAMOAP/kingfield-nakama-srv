-- modules/match/players.lua
local nk = require("nakama")

local M = {}

-- ============================================
-- JOUEUR A REJOINT
-- ============================================
function M.handle_join(state, dispatcher, presences)
    for _, presence in ipairs(presences) do
        table.insert(state.players, {
            id = presence.user_id,
            name = presence.username,
            session = presence.session_id,
            team_loaded = false
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

        print("[MATCH] " .. #state.players .. "/2 players connected")
    end
    return state
end

-- ============================================
-- JOUEUR A QUITTÉ
-- ============================================
function M.handle_leave(state, dispatcher, presences)
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
                    return nil
                end
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

return M
