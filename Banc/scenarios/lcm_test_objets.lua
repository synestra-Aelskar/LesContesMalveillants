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
local O = LCM.Objets
local moi = LCM.Entities.Self()

dire("== le registre")
attendu("trois categories", #O.CATEGORIES, 3)
attendu("1 arme", O.Emplacements("arme"), 1)
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
attendu("une arme", O.Equiper(moi, "lame_de_givre"), true)
local refus
ok, refus = O.Equiper(moi, "hache")
attendu("pas de deuxieme arme", ok, false)
dire("     " .. tostring(refus))
ok, refus = O.Equiper(moi, "lame_de_givre")
attendu("pas deux fois le meme", ok, false)
ok, refus = O.Equiper(moi, "inexistant")
attendu("objet inconnu", ok, false)
for i = 1, 5 do O.Equiper(moi, "anneau_" .. i) end
ok, refus = O.Equiper(moi, "anneau_6")
attendu("5 accessoires au plus", ok, false)
dire("     " .. tostring(refus))
attendu("rangement par categorie", #O.Ids(moi, "accessoire"), 5)

dire("== les effets se cumulent avec les traits")
LCM.Traits.Grant(moi, "escalade_jungle")         -- +3 escalade, avantage escalade
O.Desequiper(moi, "anneau_5")
O.Equiper(moi, "amulette")                       -- +1 escalade, +2 resi_ombre, avantage pistage
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
attendu("le texte parle de bonus, pas de trait",
    LCM.Roll.Describe(LCM.Roll.Field(moi, "escalade")):find("bonus %+4") ~= nil, true)

dire("== la fiche montre le bonus d'une stat")
SlashCmdList.LCM("fiche")
local fiche = LCM.UI.Fiche.frame
for _, b in ipairs(fiche.barre.boutons) do if b.ongletId == "resistances" then b:Click() end end
local ombre
for _, l in ipairs(fiche.pages.resistances.lignes) do if l.label:GetText() == "Ombre" then ombre = l end end
attendu("Ombre : valeur + bonus", ombre.valeur:GetText(), "0 +2")
local feu
for _, l in ipairs(fiche.pages.resistances.lignes) do if l.label:GetText() == "Feu" then feu = l end end
attendu("Feu : pas de bonus, pas de signe", feu.valeur:GetText(), "0")
SlashCmdList.LCM("fiche")

dire("== retirer nettoie la sauvegarde")
local test = LCM.Entities.Create("Mannequin", "Mannequin", "npc")
O.Equiper(test, "hache")
attendu("equipe", O.EstEquipe(test, "hache"), true)
attendu("retire", O.Desequiper(test, "hache"), true)
attendu("plus aucune table", test.equipement, nil)
attendu("retirer deux fois ne fait rien", O.Desequiper(test, "hache"), false)

dire("== la fenetre d'equipement")
local R = LCM.UI.Radial
attendu("entree du menu allumee", R.EstLiee("equipement"), true)
R.Trouver("equipement").onClick()
local f = LCM.UI.Equipement.frame
attendu("ouverte", f:IsShown(), true)
local arme, equip, acc = f.groupes[1], f.groupes[2], f.groupes[3]
attendu("groupe Arme", arme.entete.label:GetText(), "ARME")
attendu("arme : 1 / 1", arme.entete.budget:GetText(), "1 / 1")
attendu("arme pleine : pas d'ajout", arme.ajouter:IsShown(), false)
attendu("equipement : 0 / 5", equip.entete.budget:GetText(), "0 / 5")
attendu("equipement vide : dit Aucun", equip.vide:IsShown(), true)
attendu("accessoire : 5 / 5", acc.entete.budget:GetText(), "5 / 5")
attendu("carte de l'arme", __sansCouleur(arme.cartes[1].nom:GetText()):find("^Lame de givre") ~= nil, true)
attendu("ses effets", arme.cartes[1].effets:GetText(), "Eau +2")
attendu("les groupes ne se chevauchent pas",
    select(5, equip.entete:GetPoint(1)) < select(5, arme.cartes[1]:GetPoint(1)), true)

dire("== le MJ retire et equipe depuis la fenetre")
arme.cartes[1].retirer:Click()
attendu("arme retiree", O.EstEquipe(moi, "lame_de_givre"), false)
attendu("arme : 0 / 1", arme.entete.budget:GetText(), "0 / 1")
attendu("bouton d'ajout revenu", arme.ajouter:IsShown(), true)
arme.ajouter:Click()
local proposes = {}
for _, b in ipairs(f.choix.lignes) do if b:IsShown() then proposes[#proposes + 1] = b.choix end end
table.sort(proposes)
attendu("seulement les armes", table.concat(proposes, ","), "hache,lame_de_givre")
for _, b in ipairs(f.choix.lignes) do if b:IsShown() and b.choix == "hache" then b:Click() end end
attendu("hache equipee", O.EstEquipe(moi, "hache"), true)
attendu("affichage suit", arme.entete.budget:GetText(), "1 / 1")

dire("== un objet disparu reste visible")
B.Supprimer("objets", "amulette")
f:Afficher()
local fantome
for _, c in ipairs(acc.cartes) do if c:IsShown() and c.elementId == "amulette" then fantome = c end end
attendu("toujours liste", fantome ~= nil, true)
attendu("marque inconnu", __sansCouleur(fantome.nom:GetText()), "? amulette")
attendu("plus d'effet", LCM.Effets.Bonus(moi, "resi_ombre"), 0)
attendu("mais compte dans les emplacements", acc.entete.budget:GetText(), "5 / 5")
fantome.retirer:Click()
attendu("le MJ peut le retirer", #O.Ids(moi, "accessoire"), 4)

dire("== le joueur voit, ne touche pas")
LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = false
f:Afficher()
attendu("pas d'ajout", equip.ajouter:IsShown(), false)
attendu("pas de retrait", arme.cartes[1].retirer:IsShown(), false)
f:Retirer("hache")
attendu("un appel direct ne retire rien", O.EstEquipe(moi, "hache"), true)
LCM._masterCompanion = true
__addonsCharges["LesContesMalveillants_MJ"] = true

dire("== fermer")
R.Trouver("equipement").onClick()
attendu("fermee", f:IsShown(), false)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
