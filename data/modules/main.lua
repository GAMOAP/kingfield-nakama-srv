local nk = require("nakama")

-- Match manuel
nk.register_rpc(function(context, payload)
    local match_id = nk.match_create("match_handler", {})
    return nk.json_encode({match_id = match_id})
end, "create_match")

-- Matchmaking automatique
nk.register_matchmaker_matched(function(context, matched_users)
    local match_id = nk.match_create("match_handler", {
        matched_users = matched_users
    })
    
    -- Nakama retourne cet ID aux 2 joueurs
    return match_id
end)