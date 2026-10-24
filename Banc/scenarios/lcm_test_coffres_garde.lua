-- Deux MJ, un meme modele de coffre, et la garde qui passe de l'un a l'autre
-- (le MJ, 21 octobre 2026).
--
-- Le proprietaire etait celui du MODELE : le renvoi d'un MJ (a son /reload, a
-- l'arrivee d'un joueur) effacait les coffres que l'autre avait poses du meme
-- modele. Il est maintenant celui du coffre POSE. Et le contenu d'un coffre ne
-- vit plus seulement chez celui qui l'a pose : les MJ s'en tiennent une copie,
-- et l'un reprend la garde quand l'autre se tait.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

local SYN = "Syn-Apertus"
local sequence = 0
-- Un message de l'autre MJ, tel que le reseau le livrerait.
local function recevoir(sujet, donnees)
    sequence = sequence + 1
    LCM.Reseau.Recevoir(SYN, string.format("%d:1:1:%s|%s", 900 + sequence, sujet,
        LCM.Reseau.Encoder(donnees)), "CHANNEL")
end
local function copie(entree) recevoir("cofg", { c = LCM.Lien.Serialiser(entree) }) end
local function envoisVers(sujet, cible)
    local n = 0
    for _, e in ipairs(__envois) do
        if e.cible == cible and e.message:find(":" .. sujet .. "|", 1, true) then n = n + 1 end
    end
    return n
end

local REF = "objets/contenu_garde"
LCM.Objets.Add({ id = "contenu_garde", label = "Contenu témoin",
    categorie = "accessoire", icone = "inv_misc_key_01", pileMax = 10 })
LCM.Brouillons.Set("points", {
    id = "coffre_commun", label = "Coffre commun", nature = "coffre",
    coffre = { places = 4, rayon = 4, verrous = 0, reset = false,
        objets = { { entree = REF, quantite = 1 } }, expertises = {}, outils = {} },
})
LCM.EnsureDatabase()
local carte = LCM.Recolte.Carte()
-- Pose avant que la garde existe : ni arbitre, ni epoque, ni version.
LCM.db.coffresMJ = {
    coffre_moi = { id = "coffre_moi", def = "coffre_commun",
        x = 10, y = 20, source = "monde", carte = carte, quand = 1,
        objets = { { entree = REF, quantite = 1 } }, verrousRestants = 0,
        verrouille = false, ouvert = true, verrousOuverts = {} },
}

__declencher("PLAYER_LOGIN")
__personnage()
__avancer(1)
-- La seance tient maintenant ses propres coffres en garde — ceux que l'autre
-- MJ a poses, livres par la base commune. Veiller() en reprenait vingt-six de
-- plus que le coffre temoin (24 octobre 2026) : un scenario ne compte que ce
-- qu'il a pose lui-meme.
for id in pairs(LCM.db.coffresGarde or {}) do LCM.db.coffresGarde[id] = nil end
local C, MJ = LCM.Coffres, LCM.CoffresMJ
local MOI = LCM.PlayerId()

dire("== un coffre d'avant la garde devient le mien")
attendu("arbitre", LCM.db.coffresMJ.coffre_moi.auteur, MOI)
attendu("époque", LCM.db.coffresMJ.coffre_moi.epoque, 0)

dire("== l'autre MJ annonce SON coffre du meme modele : le mien reste")
local def = LCM.Copie(LCM.Points.Get("coffre_commun"))
recevoir(C.SUJETS.definition, C.Paquet(def, { { id = "coffre_syn", x = 50, y = 60,
    source = "monde", carte = carte } }))
attendu("son coffre est arrivé", C.points.coffre_syn ~= nil, true)
attendu("mon coffre est toujours là", C.points.coffre_moi ~= nil, true)
attendu("le sien est arbitré par lui", C.Auteur(C.points.coffre_syn), SYN)
attendu("le mien reste arbitré par moi", C.Auteur(C.points.coffre_moi), MOI)
-- Et mon renvoi (un joueur arrive) ne fait pas disparaitre le sien.
MJ.Renvoyer()
attendu("après mon renvoi, le sien est toujours là", C.points.coffre_syn ~= nil, true)
attendu("  toujours à lui", C.Auteur(C.points.coffre_syn), SYN)
-- Ce que je sauvegarde comme joueur : le sien, pas le mien (il est dans le
-- magasin du MJ).
attendu("la sauvegarde joueur retient le sien", LCM.db.coffres.points.coffre_syn ~= nil, true)
attendu("  et pas le mien", LCM.db.coffres.points.coffre_moi, nil)

dire("== un geste sur son coffre part chez lui")
C.edition = nil
C.courant = "coffre_syn"
C.edition = true
local avant = envoisVers("cof!", SYN)
C.Envoyer("ouvrir")
attendu("la demande va à son arbitre", envoisVers("cof!", SYN), avant + 1)
C.courant, C.edition = nil, nil

dire("== il bat : je lui envoie ce que je sais")
local copiesAvant = envoisVers("cofg", SYN)
recevoir("cofg~", { s = "session-1" })
attendu("je lui renvoie un battement", envoisVers("cofg~", SYN) >= 1, true)
attendu("et la copie de mon coffre", envoisVers("cofg", SYN) > copiesAvant, true)

dire("== il me confie la copie de son coffre")
copie({ id = "coffre_syn", def = "coffre_commun", x = 50, y = 60, source = "monde",
    carte = carte, objets = { { entree = REF, quantite = 7 } }, verrousRestants = 0,
    verrouille = false, ouvert = false, verrousOuverts = {},
    auteur = SYN, epoque = 0, version = 4 })
attendu("je la garde", LCM.db.coffresGarde.coffre_syn ~= nil, true)
attendu("  avec son contenu", LCM.db.coffresGarde.coffre_syn.objets[1].quantite, 7)
attendu("  sans le prendre dans mon magasin", LCM.db.coffresMJ.coffre_syn, nil)
attendu("tant qu'il bat, je ne reprends rien", MJ.Veiller(), 0)

dire("== il se tait : je reprends la garde")
__avancerTemps(MJ.ABSENCE + 1)
local repris = MJ.Veiller()
attendu("un coffre repris", repris, 1)
local garde = LCM.db.coffresMJ.coffre_syn
attendu("il est dans mon magasin", garde ~= nil, true)
attendu("  le contenu a survécu", garde and garde.objets[1].quantite, 7)
attendu("  je l'arbitre", garde and garde.auteur, MOI)
attendu("  à une nouvelle époque", garde and garde.epoque, 1)
attendu("plus en copie de garde", LCM.db.coffresGarde.coffre_syn, nil)
attendu("les joueurs s'adressent à moi", C.Auteur(C.points.coffre_syn), MOI)

dire("== il revient avec sa vieille copie : la mienne l'emporte")
-- Il a recharge : nouvelle session, et il bat avant tout le reste.
local corrections = envoisVers("cofg", SYN)
recevoir("cofg~", { s = "session-2" })
attendu("son retour lui vaut ce que je sais", envoisVers("cofg", SYN) > corrections, true)
corrections = envoisVers("cofg", SYN)
copie({ id = "coffre_syn", def = "coffre_commun", x = 50, y = 60, source = "monde",
    carte = carte, objets = { { entree = REF, quantite = 2 } }, verrousRestants = 0,
    verrouille = false, ouvert = false, verrousOuverts = {},
    auteur = SYN, epoque = 0, version = 9 })
attendu("je garde la garde", LCM.db.coffresMJ.coffre_syn ~= nil, true)
attendu("  et mon contenu", LCM.db.coffresMJ.coffre_syn.objets[1].quantite, 7)
attendu("je le corrige", envoisVers("cofg", SYN) > corrections, true)

dire("== il a repris le mien pendant MON absence : je le lui laisse, sans rien perdre")
copie({ id = "coffre_moi", def = "coffre_commun", x = 10, y = 20, source = "monde",
    carte = carte, objets = { { entree = REF, quantite = 3 } }, verrousRestants = 0,
    verrouille = false, ouvert = false, verrousOuverts = {},
    auteur = SYN, epoque = 1, version = 2 })
attendu("il sort de mon magasin", LCM.db.coffresMJ.coffre_moi, nil)
attendu("  et reste en copie de garde", LCM.db.coffresGarde.coffre_moi ~= nil, true)
attendu("  avec son contenu à lui", LCM.db.coffresGarde.coffre_moi.objets[1].quantite, 3)
attendu("le coffre reste visible", C.points.coffre_moi ~= nil, true)
attendu("  et s'adresse à lui", C.Auteur(C.points.coffre_moi), SYN)

dire("== une copie de garde de MON coffre me le rend (sauvegarde perdue)")
copie({ id = "coffre_rendu", def = "coffre_commun", x = 70, y = 80, source = "monde",
    carte = carte, objets = { { entree = REF, quantite = 5 } }, verrousRestants = 0,
    verrouille = false, ouvert = false, verrousOuverts = {},
    auteur = MOI, epoque = 0, version = 6 })
attendu("il revient dans mon magasin", LCM.db.coffresMJ.coffre_rendu ~= nil, true)
attendu("  avec son contenu", LCM.db.coffresMJ.coffre_rendu.objets[1].quantite, 5)
attendu("  et chez les joueurs", C.Auteur(C.points.coffre_rendu), MOI)

dire("== un coffre retire ne revient pas d'une vieille copie")
local copieAncienne = LCM.Copie(LCM.db.coffresMJ.coffre_syn)
attendu("retrait accepté", MJ.Retirer("coffre_syn"), true)
attendu("une tombe est posée", LCM.db.coffresRetires.coffre_syn ~= nil, true)
attendu("elle part chez lui", envoisVers("cofg-", SYN) >= 1, true)
copie(copieAncienne)
attendu("la vieille copie ne le ressuscite pas", LCM.db.coffresMJ.coffre_syn, nil)
attendu("  ni en garde", LCM.db.coffresGarde.coffre_syn, nil)
attendu("  ni chez les joueurs", C.points.coffre_syn, nil)

dire("== il retire un coffre dont je tiens la copie")
recevoir("cofg-", { i = "coffre_moi", e = 1, v = 3, a = SYN })
attendu("la copie de garde s'en va", LCM.db.coffresGarde.coffre_moi, nil)

if ko > 0 then dire(tostring(ko) .. " ECHEC(S)") else dire("TOUT PASSE") end
