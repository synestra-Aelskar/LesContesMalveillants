-- Objets : registre, emplacements, effets cumules avec les traits, fenetre
-- d'equipement.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

-- Des objets crees par le MJ lors d'une seance precedente.
-- Placer / Enlever : les regles d'emplacement, sans les sacs (depuis le
-- 3 octobre 2026, Equiper passe par les sacs : lcm_test_equipement.lua).
local B = LCM.Brouillons
B.Set("objets", { id = "lame_de_givre", label = "Lame de givre", categorie = "arme",
    description = "Une lame qui mord le froid.", bonus = { pen_eau = 2 } })
B.Set("objets", { id = "hache", label = "Hache", categorie = "arme", bonus = { pen_tranchant = 1 } })
B.Set("objets", { id = "amulette", label = "Amulette du guetteur", categorie = "accessoire",
    bonus = { escalade = 1, resi_ombre = 2 }, avantage = { "pistage" } })
for i = 1, 6 do
    B.Set("objets", { id = "anneau_" .. i, label = "Anneau " .. i, categorie = "accessoire", bonus = { vue = 1 } })
end

__declencher("PLAYER_LOGIN")
__personnage()   -- ce scenario joue un personnage : il le dit
local O = LCM.Objets
local moi = LCM.Entities.Self()

dire("== le registre")
attendu("trois categories", #O.CATEGORIES, 3)
-- Deux depuis le 5 octobre 2026 : une arme et un bouclier, ou une arme a
-- deux mains qui prend les deux.
attendu("2 armes", O.Emplacements("arme"), 2)
attendu("5 equipements", O.Emplacements("equipement"), 5)
attendu("5 accessoires", O.Emplacements("accessoire"), 5)
attendu("les brouillons sont jouables", O.Get("lame_de_givre") and O.Get("lame_de_givre").brouillon, true)
local ok, err = pcall(O.Construire, { id = "x", categorie = "bouclier" })
attendu("categorie inconnue refusee", ok, false)
dire("     " .. tostring(err))
ok, err = pcall(O.Construire, { id = "x", categorie = "arme", bonus = { force = 2 } })
attendu("primaire permise pour un objet (template)", ok, true)
dire("     " .. tostring(err))

dire("== equiper")
attendu("au depart rien", #O.Equipes(moi), 0)
attendu("rien en sauvegarde", moi.equipement, nil)
attendu("une arme", O.Placer(moi, "lame_de_givre"), true)
local refus
-- Une seconde arme a UNE main tient a cote de la premiere.
attendu("une deuxieme arme tient", O.Placer(moi, "hache"), true)
attendu("les deux emplacements sont pris", O.Occupation(moi, "arme"), 2)
ok, refus = O.Placer(moi, "dague_simple")
attendu("mais pas une troisieme", ok, false)
dire("     " .. tostring(refus))
O.Enlever(moi, "hache")
ok, refus = O.Placer(moi, "lame_de_givre")
attendu("pas deux fois le meme", ok, false)
ok, refus = O.Placer(moi, "inexistant")
attendu("objet inconnu", ok, false)
for i = 1, 5 do O.Placer(moi, "anneau_" .. i) end
ok, refus = O.Placer(moi, "anneau_6")
attendu("5 accessoires au plus", ok, false)
dire("     " .. tostring(refus))
attendu("rangement par categorie", #O.Ids(moi, "accessoire"), 5)

dire("== les effets se cumulent avec les traits")
LCM.Traits.Grant(moi, "escalade_jungle")         -- +3 escalade, avantage escalade
O.Enlever(moi, "anneau_5")
O.Placer(moi, "amulette")                       -- +1 escalade, +2 resi_ombre, avantage pistage
attendu("escalade : trait + objet", LCM.Effets.Bonus(moi, "escalade"), 4)
attendu("vue : quatre anneaux", LCM.Effets.Bonus(moi, "vue"), 4)
local element, source = LCM.Effets.Avantage(moi, "pistage")
attendu("avantage venu d'un objet", source, "objet")
attendu("et nomme", element and element.label, "Amulette du guetteur")
element, source = LCM.Effets.Avantage(moi, "escalade")
attendu("le trait passe avant l'objet", source, "trait")

math.randomseed(3)
local r = LCM.Roll.Field(moi, "pistage", { avantage = true })
attendu("jet avec l'avantage de l'objet", #r.jets, 2)
attendu("le jet nomme l'objet", r.trait.label, "Amulette du guetteur")
dire("   " .. __sansCouleur(LCM.Roll.Describe(r)))
-- 4 octobre 2026 : chaque part du jet est nommee (« Bonus : +4 »).
attendu("le texte parle de bonus, pas de trait",
    LCM.Roll.Describe(LCM.Roll.Field(moi, "escalade")):find("Bonus : %+4") ~= nil, true)

dire("== Penetration & Resistances montre le bonus d'une stat")
local fr = LCM.UI.Vues.Fenetre("penetrations_resistances")
fr:Montrer(moi)
fr:Afficher("resistances")
local ombre
for _, l in ipairs(fr.pages.resistances.lignes) do if l.label:GetText() == "Ombre" then ombre = l end end
-- 5 octobre 2026 : une statistique n'affiche plus que son TOTAL. « 0 +2 »
-- ecrivait deux valeurs dans une colonne prevue pour une, et ca debordait.
-- Le detail est passe dans l'infobulle.
attendu("Ombre : le total", ombre.valeur:GetText(), "2")
attendu("Ombre : plus de second nombre", ombre.bonus:GetText(), "")
-- Le detail est dans l'infobulle : le total, puis chaque source qui y
-- contribue. « D'ou viennent ces +4 ? » est la premiere question devant une
-- fiche, et le total seul n'y repondait pas (5 octobre 2026).
local champOmbre = LCM.Schema.Field(ombre.field.id)
local texte = LCM.UI.Fiche.Decomposition(moi, champOmbre, 0, 0)
attendu("l'infobulle donne le total", texte:find("Total : 2") ~= nil, true)
attendu("et nomme la source", texte:find("Équipement") ~= nil, true)
local feu
for _, l in ipairs(fr.pages.resistances.lignes) do if l.label:GetText() == "Feu" then feu = l end end
attendu("Feu : pas de bonus, pas de signe", feu.valeur:GetText(), "0")
fr:Hide()

dire("== retirer nettoie la sauvegarde")
local test = LCM.Entities.Create("Mannequin", "Mannequin", "npc")
O.Placer(test, "hache")
attendu("equipe", O.EstEquipe(test, "hache"), true)
attendu("retire", O.Enlever(test, "hache"), true)
attendu("plus aucune table", test.equipement, nil)
attendu("retirer deux fois ne fait rien", O.Enlever(test, "hache"), false)

dire("== la fenetre Equipements (vue du template)")
local R = LCM.UI.Menu
attendu("entree du menu allumee", R.EstLiee("equipement"), true)
R.Trouver("equipement").onClick()
local f = LCM.UI.Vues.frames.equipement
attendu("ouverte", f:IsShown(), true)
local noms = {}
for _, b in ipairs(f.barre.boutons) do noms[#noms + 1] = b.label:GetText() end
attendu("trois onglets du template", table.concat(noms, ", "), "Armes, Armures, Accessoires")
attendu("onglet Armes ouvert", f.onglet, "arme")
local armes = f.pages.arme.blocs[1]
attendu("bloc titre", armes.titre:GetText(), "ARMES")
-- Une arme portee, et la case libre qui reste.
attendu("deux emplacements d'arme", #armes.conteneur.emplacements, 2)
attendu("occupation", armes.occupation:GetText(), "1 / 2")
local ligne = armes.conteneur.emplacements[1]
attendu("l'arme portee", __sansCouleur(ligne.nom:GetText()):find("^Lame de givre") ~= nil, true)
attendu("son icone", ligne.icone:GetTexture(), "Interface\\Icons\\INV_Misc_QuestionMark")
attendu("ses effets", ligne.effets:GetText(), "Eau +2")
attendu("bouton retirer (MJ)", ligne.action.label:GetText(), "Retirer")

-- 3 octobre 2026 : la ligne d'un objet porte se lit sans la souris.
attendu("l'icone est doublee", ligne.iconeCote, 32)
attendu("et tient dans sa ligne", ligne.iconeCote <= ligne:GetHeight() - 4, true)
attendu("le nom n'est plus tronque", __sansCouleur(ligne.nom:GetText()):find("^Lame de givre") ~= nil, true)
attendu("la description est sous le nom", ligne.description:GetText() ~= "", true)
-- Clic droit : la fiche de l'objet. C'est un BOUTON, sinon le clic n'existe pas.
attendu("la ligne est cliquable", type(ligne.Click), "function")
local avant = 0
for _, c in ipairs(LCM.UI.Compendium.cartes) do if c:IsShown() then avant = avant + 1 end end
ligne:Click("RightButton")
local apres = 0
for _, c in ipairs(LCM.UI.Compendium.cartes) do if c:IsShown() then apres = apres + 1 end end
attendu("clic droit : la fiche s'ouvre", apres > avant, true)

-- Survol : la carte de l'objet, pas une infobulle de deux lignes.
ligne:GetScript("OnEnter")(ligne)
local survol = LCM.UI.Fiche.carteSurvol
attendu("le survol ouvre une carte", survol ~= nil and survol:IsShown(), true)
attendu("elle nomme l'objet", survol.nom:GetText(), "Lame de givre")
-- Ranges par section de fiche, avec la valeur a part : « Ombre +2 · Perce-
-- armure +1 » melangeait une penetration et une mecanique sur une ligne.
local titres, valeurs = {}, {}
for _, t in ipairs(survol.titres) do if t:IsShown() then titres[#titres + 1] = t:GetText() end end
for _, c in ipairs(survol.cases) do
    if c:IsShown() then valeurs[#valeurs + 1] = c.label:GetText() .. "=" .. c.valeur:GetText() end
end
attendu("les effets sont categorises", #titres > 0, true)
attendu("et chiffres a part", table.concat(valeurs, " "), "Eau=+2")
ligne:GetScript("OnLeave")(ligne)
attendu("elle se retire", survol:IsShown(), false)
-- Une case vide n'a pas de carte : elle garde l'infobulle.
local vide
for _, e in ipairs(armes.conteneur.emplacements) do if not e.elementId then vide = e end end
if vide then
    vide:GetScript("OnEnter")(vide)
    attendu("case vide : pas de carte", survol:IsShown(), false)
    vide:GetScript("OnLeave")(vide)
end

f.barre.boutons[2]:Click()
local armures = f.pages.equipement.blocs[1]
attendu("bloc Armures et vetements", armures.titre:GetText(), "ARMURES ET VÊTEMENTS")
attendu("armure : les cinq cases, meme vides", #armures.conteneur.emplacements, 5)
attendu("la cinquieme est visible", armures.conteneur.emplacements[5]:IsShown(), true)
attendu("vide : Emplacement", armures.conteneur.emplacements[1].nom:GetText(), "Emplacement")
attendu("vide : bouton ajouter", armures.conteneur.emplacements[1].action.label:GetText(), "+  Ajouter")
attendu("occupation 0 / 5", armures.occupation:GetText(), "0 / 5")

dire("== le MJ retire et equipe depuis la fenetre")
-- Depuis le 3 octobre 2026, on equipe depuis les sacs : un sac, et la hache
-- dedans. Retirer la lame la range dans ce sac.
LCM.Inventaire.Poser(moi, "sacs", 1, "gros_sac")
LCM.Inventaire.Ranger(moi, "sacs", 1, 1, "objets/hache", 1)
f.barre.boutons[1]:Click()
ligne.action:Click()
attendu("arme retiree", O.EstEquipe(moi, "lame_de_givre"), false)
attendu("case redevenue vide", ligne.nom:GetText(), "Emplacement")
attendu("occupation 0 / 2", armes.occupation:GetText(), "0 / 2")
ligne.action:Click()
local choix = LCM.UI.Fiche.choixConteneur
local proposes = {}
for _, b in ipairs(choix.lignes) do if b:IsShown() then proposes[#proposes + 1] = b.choix end end
table.sort(proposes)
-- Les armes des sacs, et elles seules : plus tout le compendium.
attendu("seulement les armes des sacs", table.concat(proposes, ","), "hache,lame_de_givre")
attendu("la lame retiree est au sac", O.Possede(moi, "lame_de_givre"), true)
for _, b in ipairs(choix.lignes) do if b:IsShown() and b.choix == "hache" then b:Click() end end
attendu("hache equipee", O.EstEquipe(moi, "hache"), true)
attendu("affichage suit", armes.occupation:GetText(), "1 / 2")

dire("== une arme a deux mains prend les deux emplacements")
-- Le champ « emplacements » d'une arme (5 octobre 2026). Une epee en demande
-- un et laisse la place d'un bouclier ; une arme a deux mains prend tout.
local okDeux = B.Enregistrer("objets", { id = "espadon", label = "Espadon",
    categorie = "arme", taille = 2 }, true)
attendu("une arme a deux mains s'enregistre", okDeux, true)
attendu("sa taille est lue", O.Taille("espadon"), 2)
attendu("une arme ordinaire en vaut un", O.Taille("lame_de_givre"), 1)
-- Une taille hors bornes est une faute de frappe, pas une intention.
attendu("trois emplacements refuses",
    pcall(O.Construire, { id = "y", label = "Y", categorie = "arme", taille = 3 }), false)
attendu("zero aussi",
    pcall(O.Construire, { id = "y", label = "Y", categorie = "arme", taille = 0 }), false)

for _, id in ipairs(O.Ids(moi, "arme")) do O.Enlever(moi, id) end
attendu("les mains sont libres", O.Occupation(moi, "arme"), 0)
attendu("l'espadon s'équipe", O.Placer(moi, "espadon"), true)
attendu("il prend les deux mains", O.Occupation(moi, "arme"), 2)
local okSecond, pourquoi = O.Placer(moi, "hache")
attendu("plus rien ne tient a cote", okSecond, false)
dire("     " .. tostring(pourquoi))
-- Et dans l'autre sens : une main prise, l'espadon ne rentre plus, et on dit
-- combien il lui en faut.
O.Enlever(moi, "espadon")
O.Placer(moi, "hache")
local okEspadon, raisonEspadon = O.Placer(moi, "espadon")
attendu("l'espadon ne rentre pas sur une seule main", okEspadon, false)
attendu("et on dit ce qu'il demande",
    tostring(raisonEspadon):find("en demande 2", 1, true) ~= nil, true)
O.Enlever(moi, "hache")
O.Placer(moi, "espadon")

-- La fenetre compte les PLACES, pas les objets : a cote d'une arme a deux
-- mains il n'y a pas de case libre a montrer.
f.barre.boutons[1]:Click()
attendu("occupation pleine", armes.occupation:GetText(), "2 / 2")
attendu("et aucune case libre en plus", #(function()
    local vus = {}
    for _, ligne in ipairs(armes.conteneur.emplacements) do
        if ligne:IsShown() then vus[#vus + 1] = ligne end
    end
    return vus
end)(), 1)
O.Enlever(moi, "espadon")
O.Placer(moi, "hache")
f:Actualiser()

dire("== un objet disparu reste visible")
f.barre.boutons[3]:Click()
B.Supprimer("objets", "amulette")
f:Actualiser()
local acc = f.pages.accessoire.blocs[1]
local fantome
for _, l in ipairs(acc.conteneur.emplacements) do if l.elementId == "amulette" then fantome = l end end
attendu("toujours liste", fantome ~= nil, true)
attendu("marque inconnu", __sansCouleur(fantome.nom:GetText()), "? amulette")
attendu("plus d'effet", LCM.Effets.Bonus(moi, "resi_ombre"), 0)
attendu("mais compte dans les emplacements", acc.occupation:GetText(), "5 / 5")
fantome.action:Click()
attendu("le MJ peut le retirer", #O.Ids(moi, "accessoire"), 4)
attendu("accessoires : les cinq cases restent affichees", #acc.conteneur.emplacements, 5)
attendu("la case liberee est vide", acc.conteneur.emplacements[5]:IsShown() and acc.conteneur.emplacements[5].elementId == nil, true)

dire("== le joueur voit, ne touche pas")
LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = false
f:Afficher("arme")
attendu("pas de bouton", armes.conteneur.emplacements[1].action:IsShown(), false)
armes.conteneur:Retirer("hache")
attendu("un appel direct ne retire rien", O.EstEquipe(moi, "hache"), true)
LCM._masterCompanion = true
__addonsCharges["LesContesMalveillants_MJ"] = true

dire("== une icone d'objet")
attendu("nom court complete", O.Icone("INV_Sword_05"), "Interface\\Icons\\INV_Sword_05")
attendu("chemin complet garde", O.Icone("Interface\\Icons\\X"), "Interface\\Icons\\X")

dire("== fermer")
R.Trouver("equipement").onClick()
attendu("fermee", f:IsShown(), false)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
