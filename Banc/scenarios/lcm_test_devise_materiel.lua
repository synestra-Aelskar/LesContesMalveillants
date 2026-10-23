-- Une monnaie qui a une forme : la case « Matériel » des devises.
--
-- Une devise n'existait qu'en solde de bourse. Cochee « Materiel » dans sa
-- creation, elle peut en sortir en PILE dans un sac — une bourse de pieces, un
-- lingot — et y revenir. Ce qui a une forme se porte, se cache dans un coffre
-- et se donne comme un objet ; ce qui n'en a pas reste un compte.
--
-- Contenu TEMOIN : devises, ressource et sac d'essai, jamais ceux de la
-- campagne.
--
-- Demande du MJ, 19 octobre 2026.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

LCM.Brouillons.Set("devises", { id = "piece_temoin", label = "Pièce témoin", materiel = true })
LCM.Brouillons.Set("devises", { id = "lingot_temoin", label = "Lingot témoin", materiel = true })
LCM.Brouillons.Set("devises", { id = "jeton_temoin", label = "Jeton témoin" })
LCM.Brouillons.Set("ressources", { id = "herbe_temoin", label = "Herbe témoin" })
LCM.Brouillons.Set("ressources", { id = "gemme_temoin", label = "Gemme témoin", pileMax = 1 })
LCM.Brouillons.Set("ressources", { id = "fer_temoin", label = "Fer témoin", pileMax = 5 })
LCM.Brouillons.Set("sacs", { id = "sac_temoin", label = "Sac témoin", places = 4 })
__declencher("PLAYER_LOGIN")
__personnage()

local B, I = LCM.Bourse, LCM.Inventaire
local UI = LCM.UI
local moi = LCM.Entities.Self()
I.Poser(moi, "sacs", 1, "sac_temoin", true)

local function Case(n) return I.Case(I.Emplacement(moi, "sacs", 1), n) end
local function Piles(ref)
    local out = {}
    for case = 1, 4 do
        local c = Case(case)
        if c and c.ref == ref then out[#out + 1] = tostring(c.quantite) end
    end
    return table.concat(out, ",")
end

dire("== la case cochee voyage de la creation au registre")
attendu("la pièce a une forme", LCM.Devises.Get("piece_temoin").materiel, true)
attendu("le jeton n'en a pas", LCM.Devises.Get("jeton_temoin").materiel, nil)
-- On ne regarde pas les monnaies de la campagne : le MJ a coche les Ecus le
-- 20 octobre 2026, et il les decochera peut-etre. Les temoins suffisent a dire
-- qu'une case cochee se retient et qu'une case vide ne pose rien.
attendu("la bourse le sait", B.EstMateriel("piece_temoin"), true)
attendu("  et pour le jeton", B.EstMateriel("jeton_temoin"), false)
attendu("  et pour une devise inventée", B.EstMateriel("berlingots"), false)
local champ
for _, c in ipairs(LCM.Compendium.Get("devises").champs or {}) do
    if c.cle == "materiel" then champ = c end
end
attendu("l'éditeur en fait une case à cocher", champ and champ.type, "case")
attendu("  nommée pour le MJ", champ and champ.label, "Matériel")

dire("== une case de sac accepte la pièce, pas le jeton")
local e = I.Emplacement(moi, "sacs", 1)
attendu("la pièce se range", (I.Accepte(e, 1, "devises/piece_temoin")), true)
local ok, raison = I.Accepte(e, 1, "devises/jeton_temoin")
attendu("le jeton, non", ok, false)
attendu("  et on dit où il vit", tostring(raison):find("bourse", 1, true) ~= nil, true)
attendu("une ressource se range aussi", (I.Accepte(e, 1, "ressources/herbe_temoin")), true)

dire("== matérialiser : le solde devient une pile")
B.Crediter(moi, "piece_temoin", 50)
attendu("un montant nul : refus", (B.Materialiser(moi, "piece_temoin", 0)), false)
attendu("plus que le solde : refus", (B.Materialiser(moi, "piece_temoin", 51)), false)
attendu("une monnaie sans forme : refus", (B.Materialiser(moi, "jeton_temoin", 1)), false)
attendu("une devise inconnue : refus", (B.Materialiser(moi, "berlingots", 1)), false)
attendu("le solde n'a pas bougé", B.Solde(moi, "piece_temoin"), 50)
attendu("on en sort vingt", (B.Materialiser(moi, "piece_temoin", 20)), true)
attendu("le solde baisse", B.Solde(moi, "piece_temoin"), 30)
attendu("la pile est dans le sac", Piles("devises/piece_temoin"), "20")
attendu("et la bourse ne la compte plus", B.Solde(moi, "piece_temoin"), 30)
attendu("mais on sait ce qu'on porte", B.EnPiles(moi, "piece_temoin"), 20)

dire("== plus de place : le solde revient, rien ne se perd")
-- Le solde doit revenir entier : manquer de place ne coute pas d'argent. Une
-- ceinture donne toujours ses cases de base, meme a qui n'a pas de sac — on
-- les remplit toutes pour que la pile n'ait vraiment nulle part ou aller.
local gueux = { id = "gueux_temoin", name = "Gueux témoin" }
for _, categorie in ipairs(I.categories) do
    for index = 1, I.Capacite(categorie.id) do
        local emplacement = I.Emplacement(gueux, categorie.id, index)
        for case = 1, (emplacement and I.Cases(emplacement) or 0) do
            I.Ranger(gueux, categorie.id, index, case, "ressources/herbe_temoin", 1)
        end
    end
end
B.Crediter(gueux, "lingot_temoin", 3)
local ok2, raison2 = B.Materialiser(gueux, "lingot_temoin", 3)
attendu("refusé", ok2, false)
attendu("  faute de place", tostring(raison2):find("place", 1, true) ~= nil, true)
attendu("le solde est intact", B.Solde(gueux, "lingot_temoin"), 3)
attendu("et rien n'a été créé", B.EnPiles(gueux, "lingot_temoin"), 0)

dire("== remettre en bourse : CETTE pile, pas celle d'à côté")
-- Deux piles de la meme monnaie : la seconde est posee a la main, puisque
-- materialiser complete la premiere.
I.Ranger(moi, "sacs", 1, 2, "devises/piece_temoin", 7)
I.Ranger(moi, "sacs", 1, 3, "ressources/herbe_temoin", 1)
I.Ranger(moi, "sacs", 1, 4, "ressources/herbe_temoin", 1)
local pile2 = { onglet = "sacs", index = 1, case = 2 }
attendu("trois de la seconde pile", (B.Encaisser(moi, "piece_temoin", 3, pile2)), true)
attendu("elle descend à quatre", Case(2).quantite, 4)
attendu("la première n'a pas bougé", Case(1).quantite, 20)
attendu("le solde remonte", B.Solde(moi, "piece_temoin"), 33)
local ok3, raison3 = B.Encaisser(moi, "piece_temoin", 9, pile2)
attendu("plus que la pile : refus", ok3, false)
attendu("  et on dit ce qu'elle a", tostring(raison3):find("que 4", 1, true) ~= nil, true)
attendu("la vider libère la case", (B.Encaisser(moi, "piece_temoin", 4, pile2)), true)
attendu("  la case est vide", Case(2), nil)
attendu("  et le solde a tout", B.Solde(moi, "piece_temoin"), 37)
-- Sans pile designee (un appel de code, pas un clic) : la premiere trouvee.
attendu("sans place : la première pile", (B.Encaisser(moi, "piece_temoin", 20)), true)
attendu("elle a disparu", Piles("devises/piece_temoin"), "")
attendu("tout est revenu", B.Solde(moi, "piece_temoin"), 57)
attendu("on n'encaisse pas ce qu'on ne porte pas", (B.Encaisser(moi, "piece_temoin", 1)), false)
attendu("ni une monnaie sans forme", (B.Encaisser(moi, "jeton_temoin", 1)), false)

dire("== ce qu'un coffre accueille (le MJ, 19 octobre 2026)")
-- La regle vit dans Core/Coffres.lua : la fenetre du joueur, l'atelier du MJ
-- et l'arbitrage du proprietaire la lisent au meme endroit.
local A = LCM.Coffres.Accepte
attendu("un objet", (A("objets/dague_d_assassin_du_culte")), true)
attendu("un livre", (A("livres/journal_d_un_eveille")) ~= nil, true)
attendu("une ressource", (A("ressources/herbe_temoin")), true)
attendu("une monnaie matérielle", (A("devises/piece_temoin")), true)
local ok4, raison4 = A("devises/jeton_temoin")
attendu("un simple compte, non", ok4, false)
attendu("  et on dit pourquoi", tostring(raison4):find("bourse", 1, true) ~= nil, true)
attendu("un PNJ non plus", (A("pnj/assassin_du_culte")), false)
attendu("une entrée inconnue non plus", (A("objets/ceci_n_existe_pas")), false)
attendu("et rien du tout non plus", (A(nil)), false)

dire("== la bourse : « Matérialiser » n'apparaît que là où elle a un sens")
local f = UI.Bourse.Basculer()
local menu = UI.MenuContexte()
local function libelles()
    local t = {}
    for _, l in ipairs(menu.lignes) do if l:IsShown() then t[#t + 1] = l.texte:GetText() end end
    return table.concat(t, ",")
end
local function cliquer(libelle)
    for _, l in ipairs(menu.lignes) do
        if l:IsShown() and l.texte:GetText() == libelle then l:Click() return true end
    end
    return false
end
local function LigneDe(deviseId)
    for _, l in ipairs(f.lignes) do
        if l:IsShown() and l.deviseId == deviseId then return l end
    end
end
local ligne = LigneDe("piece_temoin")
attendu("la pièce est dans la bourse", ligne ~= nil, true)
ligne:Click("RightButton")
attendu("son menu", libelles(), "Échanger,Matérialiser,Détruire")
cliquer("Matérialiser")
local d = LCM_Demande
attendu("on demande combien", d:IsShown(), true)
d.saisie:SetText("99")
d.valider:Click()
attendu("pas plus qu'on n'a", (d.message:GetText() or ""):find("que 57", 1, true) ~= nil, true)
d.saisie:SetText("10")
d.valider:Click()
attendu("dix en main", B.EnPiles(moi, "piece_temoin"), 10)
attendu("et le solde baisse", B.Solde(moi, "piece_temoin"), 47)
attendu("la bourse se réaffiche", LigneDe("piece_temoin").solde:GetText(), "47")

B.Crediter(moi, "jeton_temoin", 5)
f:Afficher()
LigneDe("jeton_temoin"):Click("RightButton")
attendu("un simple compte n'a pas l'entrée", libelles(), "Échanger,Détruire")
menu:Hide()

dire("== la pile, au clic droit : « Mettre en bourse »")
UI.Menu.Trouver("inventaires").onClick()
local inv = UI.Inventaires.frame
inv:CarteDe("sacs", 1):Click("LeftButton")
attendu("la pile est la première case", (Case(1) or {}).ref, "devises/piece_temoin")
inv.lignes[1]:Click("RightButton")
attendu("l'entrée est là", libelles():find("Mettre en bourse", 1, true) ~= nil, true)
cliquer("Mettre en bourse")
d.saisie:SetText("4")
d.valider:Click()
attendu("quatre reviennent", B.Solde(moi, "piece_temoin"), 51)
attendu("la pile en garde six", Case(1).quantite, 6)
inv.lignes[3]:Click("RightButton")
attendu("une ressource ne va pas en bourse", libelles():find("Mettre en bourse", 1, true), nil)
menu:Hide()

dire("== un emplacement de coffre tient toute une pile")
-- Une entree SANS pile maximale n'occupe qu'un emplacement, quelle qu'en soit
-- la quantite. Le compte en prenait un PAR UNITE : cinquante ecus remplissaient
-- cinquante emplacements, une poignee d'herbes autant — alors que la fenetre,
-- elle, n'en montrait qu'une pile (le MJ, 19 octobre 2026).
local P = LCM.Coffres.Places
attendu("la pièce n'a pas de pile maximale", LCM.Coffres.Pile("devises/piece_temoin"), nil)
attendu("cinquante pièces : un emplacement", P("devises/piece_temoin", 50), 1)
attendu("une seule aussi", P("devises/piece_temoin", 1), 1)
attendu("rien n'occupe rien", P("devises/piece_temoin", 0), 0)
attendu("quarante herbes : un emplacement", P("ressources/herbe_temoin", 40), 1)
-- Ce qui a une pile maximale garde son compte par piles : la regle ne dit pas
-- qu'un emplacement est sans fond, elle dit qu'une pile sans borne en est une.
attendu("la gemme s'empile par une", LCM.Coffres.Pile("ressources/gemme_temoin"), 1)
attendu("  donc trois gemmes, trois emplacements", P("ressources/gemme_temoin", 3), 3)
attendu("le fer s'empile par cinq", LCM.Coffres.Pile("ressources/fer_temoin"), 5)
attendu("  donc douze fers, trois emplacements", P("ressources/fer_temoin", 12), 3)

dire("== glisser une monnaie de la bourse vers un sac")
-- Le fantome d'un glissement de bourse ne portait pas de reference : la case
-- demandait au compendium ce qu'etait « nil », et repondait « entrée inconnue
-- du compendium » (le MJ, 19 octobre 2026).
local ligneP = LigneDe("piece_temoin")
ligneP:GetScript("OnDragStart")(ligneP)
local porte = UI.Glisser.objet
attendu("le fantôme porte sa référence", porte and porte.ref, "devises/piece_temoin")
attendu("  et se dit venu de la bourse", porte and porte.origine and porte.origine.bourse, true)
attendu("  ce n'est donc pas une fabrication", porte.origine ~= nil, true)
-- Un simple compte ne se pose pas dans un sac, meme glisse.
local jeton = { ref = "devises/jeton_temoin", nom = "Jeton témoin",
    origine = { bourse = true, devise = "jeton_temoin" } }
local okJ, raisonJ = inv.lignes[2].glisserAccepte(jeton)
attendu("un jeton de compte est refusé", okJ, false)
attendu("  et on dit où il vit", tostring(raisonJ):find("bourse", 1, true) ~= nil, true)
attendu("la case libre accepte la pièce", (inv.lignes[2].glisserAccepte(porte)), true)
inv.lignes[2].glisserDepose(porte)
attendu("on demande le montant", d:IsShown(), true)
d.saisie:SetText("11")
d.valider:Click()
attendu("onze pièces dans la case visée", Case(2).quantite, 11)
attendu("  et le solde baisse", B.Solde(moi, "piece_temoin"), 40)
attendu("une case prise par une herbe refuse", (inv.lignes[3].glisserAccepte(porte)), false)
-- Une case qui porte deja la meme monnaie l'absorbe : on ne refuse pas une
-- bourse parce qu'il y en a deja une.
attendu("la case de pièces l'absorbe", (inv.lignes[1].glisserAccepte(porte)), true)
inv.lignes[1].glisserDepose(porte)
d.saisie:SetText("4")
d.valider:Click()
attendu("la pile monte", Case(1).quantite, 10)
attendu("  et le solde baisse encore", B.Solde(moi, "piece_temoin"), 36)
UI.Glisser.objet = nil
if UI.Glisser.fantome then UI.Glisser.fantome:Hide() end

dire("== reposer la pile sur sa ligne de bourse")
-- L'inverse etait impossible : la bourse n'etait une cible de rien.
local pileSac = { ref = "devises/piece_temoin", nom = "Pièce témoin",
    quantite = Case(1).quantite, origine = { onglet = "sacs", index = 1, case = 1 } }
attendu("la ligne des pièces l'accepte", (LigneDe("piece_temoin").glisserAccepte(pileSac)), true)
local okL, raisonL = LigneDe("jeton_temoin").glisserAccepte(pileSac)
attendu("celle du jeton, non", okL, false)
attendu("  et elle dit laquelle est la sienne",
    tostring(raisonL):find("la ligne des", 1, true) ~= nil, true)
local herbeSac = { ref = "ressources/herbe_temoin", quantite = 1,
    origine = { onglet = "sacs", index = 1, case = 3 } }
attendu("une herbe ne va pas en bourse",
    (LigneDe("piece_temoin").glisserAccepte(herbeSac)), false)
-- Et reposer sur la bourse ce qu'on venait d'y prendre : un geste qu'on
-- annule, pas une erreur.
attendu("le glissement qu'on annule est accepté",
    (LigneDe("piece_temoin").glisserAccepte({ ref = "devises/piece_temoin",
        origine = { bourse = true, devise = "piece_temoin" } })), true)
LigneDe("piece_temoin").glisserDepose(pileSac)
attendu("on demande combien", d:IsShown(), true)
d.saisie:SetText("99")
d.valider:Click()
attendu("pas plus que la pile", (d.message:GetText() or ""):find("que 10", 1, true) ~= nil, true)
d.saisie:SetText("10")
d.valider:Click()
attendu("la case est vidée", Case(1), nil)
attendu("et le solde a tout reçu", B.Solde(moi, "piece_temoin"), 46)
attendu("l'autre pile n'a pas bougé", Case(2).quantite, 11)

dire("== lâcher sa monnaie sur la carte d'un sac")
-- La carte d'un emplacement « transvase » dans le sac qu'elle porte tout ce
-- qui a une reference et vient d'ailleurs. Une monnaie de bourse en a une
-- depuis ce soir : sans garde-fou, lachee sur un sac elle s'y serait rangee
-- SANS QUITTER la bourse — un ecu fabrique a chaque glissement.
local carteSac = inv:CarteDe("sacs", 1)
local ligneQ = LigneDe("piece_temoin")
ligneQ:GetScript("OnDragStart")(ligneQ)
local porte2 = UI.Glisser.objet
local avoir = B.Solde(moi, "piece_temoin") + B.EnPiles(moi, "piece_temoin")
attendu("un simple compte y est refusé", (carteSac.glisserAccepte(jeton)), false)
attendu("la carte du sac accepte la pièce", (carteSac.glisserAccepte(porte2)), true)
carteSac.glisserDepose(porte2)
attendu("elle demande le montant", d:IsShown(), true)
d.saisie:SetText("6")
d.valider:Click()
attendu("la bourse est débitée", B.Solde(moi, "piece_temoin"), 40)
-- Le sac porte deja une pile de pieces : elle l'absorbe, plutot que d'ouvrir
-- une case de plus a cote.
attendu("et la pile du sac l'absorbe", Case(2).quantite, 17)
attendu("rien n'a été fabriqué",
    B.Solde(moi, "piece_temoin") + B.EnPiles(moi, "piece_temoin"), avoir)
UI.Glisser.objet = nil
if UI.Glisser.fantome then UI.Glisser.fantome:Hide() end

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
