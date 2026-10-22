-- La lanterne et ses cristaux, repris d'OmegaSurvive (22 octobre 2026).
--
-- Ce que ce scenario tient :
--   * les deux categories du compendium et leurs registres, avec le contenu
--     de base de Survive ;
--   * ce que la construction refuse, et pourquoi ;
--   * l'ecoulement : multiplicateur x variateur, la charge gardee par
--     cristal, la decharge, la recharge ;
--   * les auras du serveur et la pause du MJ par phrase ;
--   * le bouton Objets > Outils du menu radial et sa fenetre.
--
-- Le contenu d'essai est TEMOIN (« temoin_* ») : les entrees de base peuvent
-- etre corrigees par le MJ en seance, un test ne s'appuie pas dessus pour
-- ses calculs (CLAUDE.md, « un test ne se pose jamais sur du contenu qui vit »).

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end
local function contient(libelle, texte, morceau)
    local ok = tostring(texte or ""):find(morceau, 1, true) ~= nil
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(texte), ok and "" or ("(attendu « " .. morceau .. " »)"))
end
local function chat(motif)
    for i = #__chats, 1, -1 do if __chats[i].texte:find(motif, 1, true) then return __chats[i] end end
end

__declencher("PLAYER_LOGIN")
__personnage()
LCM.db.settings.modeJoueur = nil
LCM._masterCompanion = true

local C, Ls, Cs, L, B = LCM.Compendium, LCM.Lanternes, LCM.Cristaux, LCM.Lanterne, LCM.Brouillons

dire("== les deux categories")
attendu("Lanternes existe", C.Get("lanternes") ~= nil, true)
attendu("Cristaux existe", C.Get("cristaux") ~= nil, true)
attendu("famille des lanternes resolue", C.FAMILLES.lanternes, "Lanternes")
attendu("famille des cristaux resolue", C.FAMILLES.cristaux, "Cristaux")
attendu("le MJ peut en creer", C.Editable(C.Get("lanternes")), true)

dire("== la base de Survive")
local aspecta = Ls.Get("aspecta")
attendu("la lanterne d'aspecta est la", aspecta and aspecta.label, "Lanterne d'aspecta")
attendu("son multiplicateur", aspecta and aspecta.multiplicateur, 1)
attendu("les Fremas consomment double", Ls.Get("fremas") and Ls.Get("fremas").multiplicateur, 2)
attendu("le cristal d'ancien temps dure 600 min", Cs.Get("ancient") and Cs.Get("ancient").duree, 600)

dire("== ce qui est refuse")
local ok, err = pcall(Ls.Construire, { id = "x", label = "X", multiplicateur = 0 })
attendu("un multiplicateur nul", ok, false)
contient("     raison", err, "au-dessus de zéro")
ok, err = pcall(Cs.Construire, { id = "x", label = "X", duree = 10, verifInventaire = true })
attendu("une verification sans ID", ok, false)
contient("     raison", err, "ID de l'objet")
ok, err = pcall(Cs.Construire, { id = "x", label = "X", duree = 10, aurasPosees = "quand je veux : 123" })
attendu("une condition inconnue", ok, false)
contient("     raison", err, "allumer, eteindre, vide, pause, reprise")
ok, err = pcall(Cs.Construire, { id = "x", label = "X", duree = 10, phrasesPause = "stop" })
attendu("des phrases sans canal", ok, false)
contient("     raison", err, "sans canal")
ok, err = pcall(Cs.Construire, { id = "x", label = "X", duree = 10, canaux = "murmure" })
attendu("un canal inconnu", ok, false)
contient("     raison", err, "canal inconnu")
ok = pcall(Cs.Construire, { id = "x", label = "X", duree = 10, canaux = "alerte, Raid",
    aurasPosees = "Allumer : 1234\npause : .cast 55 : silence" })
attendu("des regles bien ecrites passent", ok, true)

dire("== creee depuis le compendium")
ok, err = B.Enregistrer("lanternes", { id = "temoin_editeur", label = "Lanterne d'atelier", multiplicateur = 3 }, true)
attendu("le MJ l'enregistre", ok, true)
attendu("elle est jouable aussitot", Ls.Get("temoin_editeur") and Ls.Get("temoin_editeur").multiplicateur, 3)
ok, err = B.Enregistrer("cristaux", { id = "temoin_mauvais", label = "Mauvais", duree = -1 }, true)
attendu("un cristal faux est refuse a l'enregistrement", ok, false)

-- Le contenu temoin des calculs.
Ls.Add({ id = "temoin_simple", label = "Témoin x1", multiplicateur = 1,
    aurasPosees = "allumer : 1234", aurasRetirees = "eteindre : 1234\nvide : 1234" })
Ls.Add({ id = "temoin_double", label = "Témoin x2", multiplicateur = 2 })
Cs.Add({ id = "temoin_long", label = "Long", duree = 100 })       -- 6000 s
Cs.Add({ id = "temoin_court", label = "Court", duree = 5 })       -- 300 s
Cs.Add({ id = "temoin_mj", label = "Sous contrôle", duree = 100, canaux = "alerte",
    phrasesPause = "Le temps s'arrête\nTout s'éteint : eteindre", phrasesReprise = "Le temps reprend" })

dire("== allumer")
L.Reinitialiser()
ok, err = L.Allumer()
attendu("sans lanterne ni cristal, refuse", ok, false)
contient("     raison", err, "lanterne et un cristal")
attendu("choisir la lanterne", L.ChoisirLanterne("temoin_simple"), true)
attendu("choisir le cristal", L.ChoisirCristal("temoin_long"), true)
attendu("un cristal neuf arrive plein", L.Charge(), 6000)
local avant = #__chats
attendu("allumer", L.Allumer(), true)
attendu("elle est allumee", L.Allumee(), true)
attendu("l'aura est posee par le serveur", chat(".aura 1234") ~= nil, true)
attendu("l'emote part en /me", chat("allume sa lanterne.") and chat("allume sa lanterne.").canal, "EMOTE")

dire("== l'ecoulement")
__avancerTemps(600)
L.Synchroniser()
attendu("600 s a x1", L.Charge(), 5400)
attendu("variateur x2", L.DefinirVariateur(2), true)
__avancerTemps(100)
L.Synchroniser()
attendu("100 s a x2", L.Charge(), 5200)
attendu("eclairage restant", L.Restant(), 2600)
attendu("un variateur hors liste est refuse", (L.DefinirVariateur(7)), false)
L.DefinirVariateur(1)
attendu("le variateur par defaut ne s'ecrit pas", L.Etat().variateur, nil)

dire("== chaque cristal garde sa charge")
L.ChoisirCristal("temoin_court")
attendu("le court arrive plein", L.Charge(), 300)
__avancerTemps(100)
L.Synchroniser()
L.ChoisirCristal("temoin_long")
attendu("le long revient a sa charge", L.Charge(), 5200)
L.ChoisirCristal("temoin_court")
attendu("le court aussi", L.Charge(), 200)

dire("== la decharge")
L.ChoisirLanterne("temoin_double")
__avancerTemps(150)
L.Synchroniser()
attendu("a x2, 200 de charge tiennent 100 s", L.Charge(), 0)
attendu("elle s'eteint", L.Allumee(), false)
ok, err = L.Allumer()
attendu("vide, elle refuse de s'allumer", ok, false)
contient("     raison", err, "déchargée")

dire("== la recharge")
attendu("recharger", (L.Recharger()), true)
attendu("le cristal est plein", L.Charge(), 300)
attendu("et la lanterne eteinte", L.Allumee(), false)
attendu("l'emote de recharge", chat("change le réactif") ~= nil, true)

dire("== l'inventaire du jeu")
Cs.Add({ id = "temoin_objet", label = "Objet", duree = 10, verifInventaire = true, itemId = 999001 })
L.ChoisirCristal("temoin_objet")
ok, err = L.Allumer()
attendu("sans l'objet du jeu, refuse", ok, false)
contient("     raison", err, "999001")

dire("== la pause du MJ")
L.ChoisirLanterne("temoin_simple")
L.ChoisirCristal("temoin_mj")
L.Allumer()
local charge = L.Charge()
__declencher("CHAT_MSG_RAID", "le temps s'arrete !")
attendu("le raid n'est pas un canal de ce cristal", L.EnPauseMJ(), false)
__declencher("CHAT_MSG_RAID_WARNING", "Le temps s'arrête")
attendu("l'alerte du MJ met en pause", L.EnPauseMJ(), true)
attendu("elle reste allumee", L.Allumee(), true)
__avancerTemps(500)
L.Synchroniser()
attendu("le temps ne s'ecoule plus", L.Charge(), charge)
L.Eteindre()
attendu("on peut l'eteindre en pause", L.Allumee(), false)
__declencher("CHAT_MSG_RAID_WARNING", "le temps reprend")
attendu("la reprise leve la pause", L.EnPauseMJ(), false)
attendu("et rend l'etat choisi pendant la pause", L.Allumee(), false)
L.Allumer()
__declencher("CHAT_MSG_RAID_WARNING", "Tout s'éteint")
attendu("« : eteindre » met en pause", L.EnPauseMJ(), true)
attendu("et eteint", L.Allumee(), false)
__declencher("CHAT_MSG_RAID_WARNING", "Le temps reprend")
attendu("qui reste eteinte a la reprise", L.Allumee(), false)

dire("== les emotes")
attendu("/me en minuscule", L.FormaterEmote("Éteint sa lanterne.", "EMOTE"), "éteint sa lanterne.")
attendu("/s entre asterisques", L.FormaterEmote("éteint sa lanterne.", "SAY"), "*Éteint sa lanterne.*")
L.DefinirEmote("on", "souffle sur la mèche.")
attendu("une emote reecrite", L.Emote("on"), "souffle sur la mèche.")
L.DefinirEmote("on", "allume sa lanterne.")
attendu("revenue au defaut, elle s'oublie", L.Etat().emotes, nil)

dire("== Objets > Outils")
local M = LCM.UI.Menu
local objets = M.Trouver("objets")
local present = false
for _, e in ipairs(objets.enfants) do present = present or e.id == "outils_portes" end
attendu("le bouton est dans Objets", present, true)
attendu("il s'appelle Outils", M.Trouver("outils_portes").label, "Outils")
attendu("il est lie a sa fenetre", M.EstLiee("outils_portes"), true)
local nChats = #__chats
M.Trouver("outils_portes").onClick()
local f = LCM.UI.Lanterne.frame
attendu("la fenetre s'ouvre", f and f:IsShown(), true)
attendu("ouvrir se joue en emote", chat("examine sa lanterne.") ~= nil and #__chats > nChats, true)
attendu("le choix est affiche", f.lanterne.label:GetText(), "Témoin x1")
attendu("le bouton propose d'allumer", f.allumer.label:GetText(), "Allumer")
f.allumer:Click()
attendu("et allume", L.Allumee(), true)
attendu("le bouton propose d'eteindre", f.allumer.label:GetText(), "Éteindre")
f.reglages:Click()
attendu("le volet des parametres s'ouvre", f.volet:IsShown(), true)
M.Trouver("outils_portes").onClick()
attendu("la fenetre se referme", f:IsShown(), false)
attendu("ranger se joue en emote", chat("remet sa lanterne") ~= nil, true)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
