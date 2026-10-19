-- Recolter quand le MJ n'est pas la (13 octobre 2026).
--
-- Trois statuts : CREE (pose), EN ATTENTE (recolte par un joueur pendant que
-- son MJ etait absent : il a sa part, le point a disparu chez lui), RECOLTE
-- (le MJ l'a note et ne le renvoie plus). Le joueur garde ce qu'il sait dans
-- sa sauvegarde, et dit au MJ ce qu'il a pris des qu'il le croise. Un point en
-- attente n'est jamais recree par une diffusion du MJ qui ne le sait pas
-- encore.
--
-- Contenu TEMOIN : une ressource et un sac d'essai.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

local REF = "ressources/eau_temoin"
local R = LCM.Recolte
local CARTE = R.Carte()

LCM.Brouillons.Set("ressources", { id = "eau_temoin", label = "Eau témoin" })
LCM.Brouillons.Set("sacs", { id = "sac_temoin", label = "Sac témoin", places = 12 })
-- Un point de recolte a NOUS (le MJ local), pose avant la connexion.
LCM.Brouillons.Set("points", {
    id = "puiser_mj", label = "Puiser", nature = "ressource", offres = {},
    recolte = { entree = REF, min = 1, max = 1, dd = 0, rayon = 3 },
})
LCM.EnsureDatabase()
LCM.db.recoltes = { r1 = { def = "puiser_mj", x = 900, y = 900, source = "monde", carte = CARTE, quand = 1 } }
-- Ce que le joueur savait en se deconnectant : les points d'un autre MJ, et un
-- point deja recolte sans lui, pas encore signale.
LCM.db.recolte = {
    definitions = { def_syn = { id = "def_syn", label = "Cueillir", entree = REF, min = 2, max = 2,
        dd = 0, rayon = 4, auteur = "Syn-Apertus" } },
    points = {
        p1 = { id = "p1", def = "def_syn", x = 0, y = 0, source = "monde", carte = CARTE },
        p2 = { id = "p2", def = "def_syn", x = 50, y = 0, source = "monde", carte = CARTE },
    },
    attente = { p0 = { a = "Syn-Apertus", d = "def_syn", q = 1, t = 1 } },
}

__declencher("PLAYER_LOGIN")
__personnage()
local moi = LCM.Entities.Self()
LCM.Inventaire.Poser(moi, "sacs", 1, "sac_temoin", true)
local MOI = LCM.PlayerId()

local function Combien()
    local n = 0
    for _, categorie in ipairs(LCM.Inventaire.categories) do
        for index = 1, LCM.Inventaire.Capacite(categorie.id) do
            local e = LCM.Inventaire.Emplacement(moi, categorie.id, index)
            if e then
                for case = 1, LCM.Inventaire.Cases(e) do
                    local c = LCM.Inventaire.Case(e, case)
                    if c and c.ref == REF then n = n + (tonumber(c.quantite) or 1) end
                end
            end
        end
    end
    return n
end

local function DernierEnvoi(sujet, depuis)
    for i = #__envois, (depuis or 0) + 1, -1 do
        local e = __envois[i]
        local corps = e.message:match("^%d+:%d+:%d+:(.*)$")
        if corps and corps:sub(1, #sujet + 1) == sujet .. "|" then
            return e, LCM.Reseau.Decoder(corps:sub(#sujet + 2))
        end
    end
end

local function Recevoir(expediteur, sujet, donnees)
    return LCM.Reseau.Recevoir(expediteur, "1:1:1:" .. sujet .. "|" .. LCM.Reseau.Encoder(donnees))
end

dire("== ce qu'on savait survit à la déconnexion")
attendu("les points de l'autre MJ sont là", R.points.p1 ~= nil and R.points.p2 ~= nil, true)
attendu("  sans qu'il soit connecté", R.definitions.def_syn.auteur, "Syn-Apertus")
attendu("le point déjà récolté est en attente", R.Statut("p0"), "attente")
attendu("  et n'est pas sur le terrain", R.points.p0, nil)

dire("== son MJ est absent : on récolte quand même")
__groupe({ MOI, "Syn-Apertus" })
-- Syn est dans le groupe, mais deconnecte.
UnitIsConnected = function(unite) return (UnitName(unite)) ~= "Syn" end
attendu("il est vu hors ligne", R.EnLigne("Syn-Apertus"), false)
__position(1, 1, 0)
__avancer(0.3)
local bouton = LCM.UI.Recolte.bouton
attendu("le bouton apparaît", bouton and bouton:IsShown(), true)
local avant = #__envois
bouton:Click()
attendu("rien ne part vers un MJ absent", DernierEnvoi(R.SUJETS.prendre, avant), nil)
attendu("sa part arrive tout de suite", Combien(), 2)
attendu("le point passe en attente", R.Statut("p1"), "attente")
attendu("  et quitte le terrain", R.points.p1, nil)
attendu("  c'est sauvegardé", LCM.db.recolte.attente.p1 ~= nil, true)
attendu("  avec sa quantité", LCM.db.recolte.attente.p1.q, 2)
__avancer(0.3)
attendu("le bouton s'efface", bouton:IsShown(), false)

dire("== son MJ revient : on le lui dit, et il ne recrée rien")
UnitIsConnected = nil
avant = #__envois
-- Il ne sait encore rien : il renvoie p1 avec p2.
Recevoir("Syn-Apertus", R.SUJETS.definition, R.Paquet(R.definitions.def_syn, {
    { id = "p1", x = 0, y = 0, source = "monde", carte = CARTE },
    { id = "p2", x = 50, y = 0, source = "monde", carte = CARTE },
}))
attendu("p1 n'est pas recréé", R.points.p1, nil)
attendu("p2 est toujours là", R.points.p2 ~= nil, true)
local envoi, paquet = DernierEnvoi(R.SUJETS.signaler, avant)
attendu("on lui signale ce qu'on a pris", envoi and envoi.cible, "Syn-Apertus")
attendu("  en chuchotement", envoi and envoi.canal, "WHISPER")
attendu("  les deux points en attente", paquet and paquet.l, "p0,p1")

dire("== seul son MJ efface l'attente")
Recevoir("Claydenn-Apertus", R.SUJETS.accuse, { l = "p0,p1" })
attendu("un autre ne peut pas", R.Statut("p1"), "attente")
Recevoir("Syn-Apertus", R.SUJETS.accuse, { l = "p0,p1" })
attendu("son MJ, si : p1 est récolté", R.Statut("p1"), nil)
attendu("  p0 aussi", R.Statut("p0"), nil)
attendu("  plus rien à dire", R.Signaler("Syn-Apertus"), false)
attendu("  et la sauvegarde l'oublie", next(LCM.db.recolte.attente), nil)

dire("== côté MJ : un joueur signale un point récolté sans nous")
__groupe({ MOI, "Claydenn-Apertus" })
attendu("notre point est créé", LCM.Recoltes.Compte("puiser_mj"), 1)
avant = #__envois
Recevoir("Claydenn-Apertus", R.SUJETS.signaler, { l = "r1,inconnu" })
attendu("il passe à récolté", LCM.db.recoltes.r1.statut, "recolte")
attendu("  par qui l'a pris", LCM.db.recoltes.r1.par, "Claydenn-Apertus")
attendu("  il reste au carnet", #LCM.Recoltes.Carnet("puiser_mj"), 1)
attendu("  mais n'est plus disponible", LCM.Recoltes.Compte("puiser_mj"), 0)
attendu("  ni sur notre terrain", R.points.r1, nil)
local _, retrait = DernierEnvoi(R.SUJETS.retrait, avant)
attendu("le groupe le retire", retrait and retrait.i, "r1")
envoi, paquet = DernierEnvoi(R.SUJETS.accuse, avant)
attendu("on accuse réception au joueur", envoi and envoi.cible, "Claydenn-Apertus")
attendu("  de tout ce qu'il a cité, même l'inconnu", paquet and paquet.l, "r1,inconnu")

dire("== un point récolté n'est plus jamais envoyé")
avant = #__envois
Recevoir("Claydenn-Apertus", R.SUJETS.demande, {})
attendu("rien à envoyer : plus aucun point créé", DernierEnvoi(R.SUJETS.definition, avant), nil)
-- Et le carnet l'affiche comme tel.
LCM.UI.Menu.Trouver("ressources").onClick()
local f = LCM.UI.Recoltes.frame
f:Choisir("puiser_mj")
f:Onglet("placement")
attendu("le carnet dit « Récolté par »", f.placement.lignes[1].texte:GetText():find("Récolté par Claydenn", 1, true) ~= nil, true)
attendu("  et compte à part", f.placement.compte:GetText(), "0 disponible(s), 1 récolté(s)")

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
