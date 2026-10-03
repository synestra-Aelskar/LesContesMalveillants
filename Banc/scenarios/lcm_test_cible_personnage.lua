-- Une action qui vise un JOUEUR arrive sur son PERSONNAGE (4 octobre 2026),
-- meme quand le MJ incarne un PNJ : l'assassin incarne attaque, Blud encaisse
-- avec ses stats a lui. Et la liste des cibles nomme les personnages.
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

__declencher("PLAYER_LOGIN")
local A, E = LCM.Actions, LCM.Entities
local blud = LCM.Personnages.Creer("Blud'Sh'Idah")
E.Set_Value(blud, "constitution", 7)
local moi = LCM.PlayerId()
-- Le groupe compte aussi le joueur lui-meme, comme dans le jeu.
__groupe({ moi, "Nytherah-Apertus", "Claydenn-Apertus" })

dire("== Le MJ incarne l'assassin")
-- Les fenetres ouvertes sur Blud suivent l'incarnation ; celle qui regarde
-- quelqu'un d'autre ne bouge pas.
LCM.UI.Menu.Trouver("statistiques").onClick()
local stats = LCM.UI.Vues.frames.statistiques
attendu("statistiques ouvertes sur Blud", stats.entity == blud, true)
local autre = LCM.Entities.Create("autre_perso", "Autre", "player")
local consult = LCM.UI.Vues.Fenetre("equipement")
consult:Montrer(autre)
local assassin = LCM.Incarnation.Incarner(LCM.PNJ.list[1].id, "Assassin du culte")
attendu("les statistiques passent a l'assassin", stats.entity == assassin, true)
attendu("et son nom en sous-titre", stats.sousTitre:GetText(), assassin.name)
attendu("la fenetre sur un autre ne bouge pas", consult.entity == autre, true)
consult:Hide()
attendu("incarne", E.Self() == assassin, true)
attendu("mais son personnage reste Blud", E.Personnage() == blud, true)

dire("== La liste des cibles : les personnages")
-- Nytherah annonce son personnage ; Claydenn ne s'est pas encore montre.
recevoir("Nytherah-Apertus", "ici", { v = "1", p = "Lothris" })
local joueurs = A.Cibles()
attendu("soi : le personnage, pas l'assassin ni le nom WoW", joueurs[1].nom, "Blud'Sh'Idah")
attendu("marque comme soi", joueurs[1].soi, true)
local fois = 0
for _, j in ipairs(joueurs) do if j.id == moi then fois = fois + 1 end end
attendu("soi une seule fois", fois, 1)
attendu("trois joueurs en tout", #joueurs, 3)
local noms = {}
for _, j in ipairs(joueurs) do noms[j.id] = j.nom end
attendu("un autre : son personnage annonce", noms["Nytherah-Apertus"], "Lothris")
attendu("sans annonce : le nom WoW", noms["Claydenn-Apertus"], "Claydenn-Apertus")
attendu("l'adresse reste le nom WoW", joueurs[2].id ~= nil and noms[joueurs[2].id] ~= nil, true)

dire("== L'annonce porte le personnage, pas l'incarnation")
local avant = #__envois
LCM.Presence.Demander(true)
local texte = ""
for i = avant + 1, #__envois do
    local e = __envois[i]
    for _, v in pairs(e) do texte = texte .. tostring(v) end
end
attendu("le paquet nomme Blud", texte:find("Blud", 1, true) ~= nil, true)
attendu("pas l'assassin", texte:find("Assassin", 1, true) == nil, true)

dire("== Une attaque adressee au joueur : Blud encaisse")
local v = { ["Total Normal"] = "8", ["Total Critique"] = "12", ["Type Physique"] = "Tranchant",
            ["Type Elementaire"] = "?", ["Rand Nom"] = "Adresse", ["Rand Résultat"] = "10",
            ["Perce armure"] = "0", Zones = "#sante" }
recevoir("Nytherah-Apertus", "act", { t = "t1", n = "Attaque", a = "Nytherah-Apertus", rp = "Lothris", v = v })
local recu = A.recus[#A.recus]
attendu("recue", recu ~= nil, true)
attendu("resolue sur Blud", recu and recu.entity == blud, true)
attendu("pas sur l'assassin", recu and recu.entity ~= assassin, true)
attendu("avec la constitution de Blud", recu and E.Get_Value(recu.entity, "constitution"), 7)
local sous = LCM.UI.Resolution.recu and LCM.UI.Resolution.recu.sous:GetText() or ""
attendu("Déclaré par le nom en jeu de l'attaquant", sous:find("Déclaré par Lothris", 1, true) ~= nil, true)
attendu("sans le nom WoW entre parentheses", sous:find("(Nytherah", 1, true) == nil, true)

dire("== On agit sous le nom de la fiche jouee")
attendu("incarne : l'assassin signe", LCM.Identite.NomEnJeu(), "Assassin du culte")
attendu("on repond sous le nom de Blud", LCM.Identite.NomEnJeu(E.Personnage()), "Blud'Sh'Idah")

dire("== Une attaque adressee au PNJ : l'assassin encaisse")
recevoir("Nytherah-Apertus", "act", { t = "t2", n = "Attaque", a = "Nytherah-Apertus", rp = "Lothris", v = v,
    p = assassin.id, pn = "Assassin du culte" })
recu = A.recus[#A.recus]
attendu("resolue sur l'assassin", recu and recu.entity == assassin, true)

dire("== Sans incarnation, rien ne change")
LCM.Incarnation.Relacher()
attendu("reprendre sa place : retour a Blud", stats.entity == blud, true)
stats:Hide()
attendu("Self et Personnage confondus", E.Self() == E.Personnage(), true)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
