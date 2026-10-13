-- Un joueur qui se connecte demande les points de recolte et les marchands,
-- MEME si le jeu ne connait pas encore son groupe (13 octobre 2026).
--
-- Constate en jeu : groupe permanent, joueur qui se reconnecte, rien recu.
-- A la connexion, IsInGroup repond faux un instant ; la demande ne partait
-- pas, et rien ne la relancait. Elle attend maintenant que le groupe se fasse
-- connaitre.
--
-- Joue SANS le compagnon MJ : c'est ce que voit un joueur.
--   lcm.cmd scenarios\lcm_test_recolte_connexion.lua --sans-mj

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

local function Demandes(depuis)
    local n = {}
    for i = (depuis or 0) + 1, #__envois do
        local corps = __envois[i].message:match("^%d+:%d+:%d+:(.*)$") or ""
        local sujet = corps:match("^(.-)|")
        if sujet == "rec?" or sujet == "mar?" then n[sujet] = (n[sujet] or 0) + 1 end
    end
    return n
end

-- Le groupe existe, mais le jeu ne l'a pas encore annonce a la connexion.
__groupe({})
__declencher("PLAYER_LOGIN")
__personnage()
local MJ = LCM.IsMaster()

if MJ then
    -- Avec le compagnon, le MJ ne demande rien : il detient les points.
    attendu("le MJ ne demande rien", Demandes()["rec?"], nil)
else
    attendu("sans groupe connu : rien ne part encore", Demandes()["rec?"], nil)
    attendu("  pour les marchands non plus", Demandes()["mar?"], nil)
    attendu("  mais la demande attend", LCM.Recolte.DemandeEnSuspens(), true)

    dire("== le groupe se fait connaître : la demande part")
    local avant = #__envois
    __groupe({ "Reika-Apertus", "Syn-Apertus" })
    __declencher("GROUP_ROSTER_UPDATE")
    local d = Demandes(avant)
    attendu("les points de récolte sont demandés", d["rec?"], 1)
    attendu("les marchands aussi", d["mar?"], 1)
    attendu("plus rien en suspens", LCM.Recolte.DemandeEnSuspens(), false)

    dire("== et pas à chaque changement du groupe")
    avant = #__envois
    __declencher("GROUP_ROSTER_UPDATE")
    attendu("une seule fois", Demandes(avant)["rec?"], nil)
end

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
