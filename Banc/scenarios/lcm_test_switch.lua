-- /lcm switch : un MJ qui joue voit ce que voient ses joueurs.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")

dire("== au depart, le compagnon est la")
attendu("maitre du jeu", LCM.IsMaster(), true)
attendu("pas en mode joueur", LCM.ModeJoueur(), false)
attendu("le compendium lui est reserve et visible",
    LCM.UI.Menu.Trouver("systeme_aelskar").mjSeulement, true)
-- Les branches visibles a TOUTES les profondeurs : les entrees du MJ sont
-- rangees dans des dossiers (« Système », « Interactions », 15-16 octobre
-- 2026), et le premier niveau ne changeait plus — « Système » reste visible
-- grace aux « Règles » (21 octobre 2026).
local function Branches(noeuds)
    local n = 0
    for _, noeud in ipairs(LCM.UI.Menu.Visibles(noeuds)) do
        n = n + 1
        if noeud.enfants then n = n + Branches(noeud.enfants) end
    end
    return n
end
local avant = Branches()

dire("== bascule")
SlashCmdList.LCM("switch")
attendu("plus maitre du jeu", LCM.IsMaster(), false)
attendu("et c'est retenu", LCM.db.settings.modeJoueur, true)
attendu("on le dit", __sansCouleur(__sorties[#__sorties]):find("Mode joueur") ~= nil, true)
attendu("le menu montre moins de choses", Branches() < avant, true)

dire("   les actions du MJ ne repondent plus")
attendu("l'envoi d'experience est refuse", (LCM.Experience.Envoyer("Nytherah-Apertus", 50)), false)
attendu("et la fiche d'un joueur ne se demande plus", (LCM.Fiches.Demander("Nytherah-Apertus")), false)

dire("   une fenetre de MJ ouverte se referme")
LCM._masterCompanion = true
LCM.db.settings.modeJoueur = nil
local compendium = LCM.UI.Compendium.Fenetre()
compendium:Show()
SlashCmdList.LCM("switch")
attendu("le compendium s'est ferme", compendium:IsShown(), false)

dire("== retour")
SlashCmdList.LCM("switch")
attendu("de nouveau maitre du jeu", LCM.IsMaster(), true)
attendu("et rien ne traine en sauvegarde", LCM.db.settings.modeJoueur, nil)
attendu("le menu retrouve ses entrees", Branches(), avant)

dire("== sans le compagnon, il n'y a rien a basculer")
LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = false
local ok, raison = LCM.BasculerModeJoueur(true)
attendu("refus", ok, false)
attendu("et on dit pourquoi", tostring(raison):find("compagnon") ~= nil, true)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
