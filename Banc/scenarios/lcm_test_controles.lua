-- Les controles : effets narratifs, etats temporaires, resistance, rounds.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end
local function recevoir(expediteur, sujet, donnees)
    return LCM.Reseau.Recevoir(expediteur, "1:1:1:" .. sujet .. "|" .. LCM.Reseau.Encoder(donnees))
end
local function chatDit(motif)
    for i = #__chats, 1, -1 do if __chats[i].texte:find(motif, 1, true) then return __chats[i] end end
end
local function aDit(motif)
    for i = #__sorties, 1, -1 do if __sansCouleur(__sorties[i]):find(motif, 1, true) then return true end end
    return false
end

__declencher("PLAYER_LOGIN")
local A, E, T = LCM.Actions, LCM.Entities, LCM.EtatsTemporaires
local U = LCM.UI.Resolution
local moi = E.Self()
for _, id in ipairs({ "mystique", "esprit", "meca_immobilisation", "pen_tranchant" }) do E.Set_Value(moi, id, 4) end
E.SetGauge(moi, "pa", 10)

-- Repondre a chaque question du composeur par sa premiere option possible.
local function composer(radial)
    LCM.UI.Radial.Trouver(radial).onClick()
    local f = LCM.UI.Composeur.frame
    for _ = 1, 20 do
        if f.declarer:IsShown() then break end
        local fait = false
        for _, b in ipairs(f.boutons) do
            if b:IsShown() and b:IsEnabled() and not fait then
                if not f.composeur:EstChoisie(f.q, b.o.id) then b:Click() end
                fait = true
            end
        end
        for _, c in ipairs(f.cases) do if c:IsShown() and c:IsEnabled() and not fait then c:Click() fait = true end end
        f.suivant:Click()
    end
    f.declarer:Click()
end

dire("== Immobilisation, de bout en bout, sur soi")
local terrestre = tonumber(E.Get_Value(moi, "depl_terrestre"))
attendu("on court au depart", terrestre > 0, true)
composer("immobilisation")
local C = U.cibles
attendu("le choix des cibles", C:IsShown() and C.mode:GetText(), "monocible")
C.joueurs.lignes[1]:Click()
C.declarer:Click()
attendu("le jet du lanceur est annonce", chatDit("[Rand Esprit] D15") ~= nil, true)
attendu("et le debuff", chatDit("lance un débuff : Immobilisé") ~= nil, true)
local F = U.effet
attendu("la cible doit resister", F:IsShown() and F.titre:GetText(), "Débuff — résistance")
attendu("avec la competence du lanceur", F.boutons[1].label:GetText():find("Résister : Esprit", 1, true) ~= nil, true)
attendu("la duree est dite", F.corps:GetText():find("Durée : 1 round", 1, true) ~= nil, true)
F.dernier:Click()
local etat = T.Liste(moi)[1]
attendu("l'etat est pose", etat and etat.nom, "Immobilisé")
attendu("pour un round", etat and etat.restant, 1)
attendu("on ne bouge plus", tonumber(E.Get_Value(moi, "depl_terrestre")), 0)
attendu("ni a la nage", tonumber(E.Get_Value(moi, "depl_nage")), 0)

dire("== les rounds du combat l'eteignent")
local garde = LCM.Incarnation.Instancier(LCM.PNJ.list[1].id, "Garde")
__groupe({})
LCM.Combat.Inviter({ pnj = { garde.id } })
LCM.Combat.Avancer(1)
attendu("encore la au milieu du round", #T.Liste(moi), 1)
LCM.Combat.Avancer(1)
attendu("fini au round suivant", #T.Liste(moi), 0)
attendu("on le dit", aDit("« Immobilisé » prend fin."), true)
attendu("on court de nouveau", tonumber(E.Get_Value(moi, "depl_terrestre")), terrestre)
LCM.Combat.Terminer()
-- Le combat a pu finir sur le tour du garde : le MJ l'incarne encore, et ce
-- qui vise « soi » irait au garde. On reprend sa place.
LCM.Incarnation.Relacher()

dire("== Repulsion recue : un effet narratif")
__groupe({ "Reika-Apertus", "Nytherah-Apertus" })
local repousse = { t = "r1", a = "Nytherah-Apertus", rp = "Nytherah", nom = "Répulsion", deb = 1, nar = 1,
                   txt = "{target} est repoussé(e) de {amount} m par {caster}.", mt = 6, u = "m",
                   js = "Esprit", jr = 99, ce = 10, cf = 2 }
recevoir("Nytherah-Apertus", "etat", repousse)
attendu("resister ou subir", F:IsShown(), true)
attendu("pas de duree pour un effet narratif", F.corps:GetText():find("Durée", 1, true), nil)
F.boutons[1]:Click()
attendu("la resistance echoue de 10 ou plus : critique", chatDit("repoussé(e) de 12 m par Nytherah. (critique)") ~= nil, true)
attendu("aucun etat pour un narratif", #T.Liste(moi), 0)

dire("== resister a un debuff")
local immo = { t = "i1", a = "Nytherah-Apertus", rp = "Nytherah", nom = "Immobilisé", deb = 1, r = 2,
               js = "Esprit", jr = 0, ce = 10, cf = 2, d = { terreste = "-100%Terrestre" } }
local n = #__envois
recevoir("Nytherah-Apertus", "etat", immo)
F.boutons[1]:Click()
attendu("on resiste (jet contre 0)", #T.Liste(moi), 0)
attendu("le lanceur l'apprend", __envois[n + 1] and __envois[n + 1].message:find("résiste", 1, true) ~= nil, true)

dire("== un echec critique double la duree")
immo.t, immo.jr = "i2", 99
recevoir("Nytherah-Apertus", "etat", immo)
F.boutons[1]:Click()
attendu("deux rounds deviennent quatre", T.Liste(moi)[1] and T.Liste(moi)[1].restant, 4)
T.Retirer(moi, "Immobilisé")

dire("== un buff : accepter ou refuser")
local lev = { t = "l1", a = "Nytherah-Apertus", rp = "Nytherah", nom = "En lévitation", r = 3,
              desc = "En lévitation : flotte au-dessus du sol." }
recevoir("Nytherah-Apertus", "etat", lev)
attendu("un buff ne se resiste pas", F.titre:GetText(), "Buff reçu")
attendu("on peut refuser", F.dernier.label:GetText(), "Refuser")
F.dernier:Click()
attendu("refuse : rien", #T.Liste(moi), 0)
lev.t = "l2"
recevoir("Nytherah-Apertus", "etat", lev)
F.boutons[1]:Click()
attendu("accepte : pose", T.Liste(moi)[1] and T.Liste(moi)[1].nom, "En lévitation")

dire("== /lcm etats")
SlashCmdList["LCM"]("etats")
attendu("la liste", aDit("En lévitation (3 rounds)"), true)
SlashCmdList["LCM"]("etats retirer En lévitation")
attendu("retire", #T.Liste(moi), 0)
attendu("la sauvegarde ne garde pas de liste vide", moi.etatsTemporaires, nil)

dire("== un PNJ vise : le MJ le resout sur sa fiche")
immo.t, immo.p, immo.pn = "i3", garde.id, "Garde"
recevoir("Nytherah-Apertus", "etat", immo)
attendu("le PNJ est nomme", F.sous:GetText():find("[PNJ : Garde]", 1, true) ~= nil, true)
F.dernier:Click()
attendu("le garde est immobilise", T.Liste(garde)[1] and T.Liste(garde)[1].nom, "Immobilisé")
attendu("pas moi", #T.Liste(moi), 0)

dire("== les etats temporaires dans Sante")
T.Poser(moi, { nom = "Ralenti", id = "s1", rounds = 2, bonus = { depl_terrestre = -2 }, debuff = true })
local V = LCM.UI.Vues.Basculer("sante")
V:Afficher("etats")
local page = V.pages.etats
local bloc
for _, l in ipairs(page.lignes) do if l.vide then bloc = l end end
attendu("le bloc existe", bloc ~= nil, true)
attendu("l'etat y est", bloc.lignes[1] and bloc.lignes[1]:IsShown() and bloc.lignes[1].nom:GetText(), "Ralenti")
attendu("avec ses effets et sa duree", bloc.lignes[1].effets:GetText():find("Terrestre -2", 1, true) ~= nil
    and bloc.lignes[1].effets:GetText():find("2 rounds", 1, true) ~= nil, true)
attendu("le MJ peut le retirer", bloc.lignes[1].action:IsShown() and bloc.lignes[1].action.label:GetText(), "Retirer")
bloc.lignes[1].action:Click()
attendu("retire, la vue suit", bloc.vide:IsShown(), true)

dire("== un etat qui se guerit par un jet")
T.Poser(moi, { nom = "Maudit", id = "g1", guerison = { mode = "rand", competence = "Esprit", dc = 0 } })
LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = false
V:Actualiser()
attendu("le joueur peut tenter", bloc.lignes[1].action.label:GetText(), "Guérir (Esprit)")
bloc.lignes[1].action:Click()
attendu("DC 0 : gueri", #T.Liste(moi), 0)
attendu("annonce", chatDit("guérison de « Maudit » (DC 0) : réussie") ~= nil, true)
T.Poser(moi, { nom = "Narré", id = "g2" })
V:Actualiser()
attendu("sans jet de guerison : un joueur n'y touche pas", bloc.lignes[1].action:IsShown(), false)
LCM._masterCompanion = true
__addonsCharges["LesContesMalveillants_MJ"] = true
T.Retirer(moi, "Narré")
V:Hide()

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
