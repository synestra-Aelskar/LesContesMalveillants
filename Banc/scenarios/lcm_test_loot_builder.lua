local function verifier(ok, message)
    if not ok then error(message, 0) end
end

__declencher("PLAYER_LOGIN")
__personnage()
local refs = {}
for i = 1, 6 do
    local id = "lot_builder_" .. i
    LCM.Ressources.Add({ id = id, label = "Lot test " .. i })
    refs[#refs + 1] = "ressources/" .. id
end
LCM.Objets.Add({ id = "coeur_builder", label = "Coeur de golem", categorie = "outil" })
local objet = "objets/coeur_builder"

local brouillon = LCM.Creation.NouveauPNJ()
local fenetre = LCM.UI.Creation.OuvrirPNJ(function() return true end, brouillon)
brouillon = fenetre.brouillon
fenetre:Afficher("loot")
local blocs = fenetre.pages.loot.sections
for _, id in ipairs({ "sacs", "naturel", "ventre" }) do
    verifier(blocs[id].lignes[1] and blocs[id].lignes[1].vide, id .. " : case vide absente")
    verifier(blocs[id].lignes[1].plus:IsShown(), id .. " : le + est absent")
    verifier(not blocs[id].lignes[2], id .. " : plus d'une case vide")
end

blocs.naturel.lignes[1]:Click()
local choix = fenetre.choixLoot
verifier(choix and choix:IsShown(), "selecteur naturel absent")
for _, option in ipairs(choix.options) do
    verifier(option.id ~= objet, "le naturel propose un objet non ressource")
end
choix.recherche:Saisir("Lot test")
for _, case in ipairs(choix.cases) do
    if case:IsShown() then case:Click() end
end
choix.valider:Click()
verifier(#brouillon.loot.naturel == 6, "selection multiple non ajoutee")
verifier(blocs.naturel.lignes[7].vide and blocs.naturel.lignes[7]:IsShown(),
    "la septieme case vide manque")
verifier(not blocs.naturel.lignes[8], "une case vide de trop")
verifier(blocs.naturel.lignes[1].quantite:IsShown() and blocs.naturel.lignes[1].retirer:IsShown(),
    "quantite ou retrait absents sur une case remplie")

local compendium = LCM.UI.Compendium.Ouvrir("ressources")
for i = 1, 6 do compendium:Selection()["lot_builder_" .. i] = true end
local rangee = compendium.rangees[1]
rangee.element = LCM.Ressources.Get("lot_builder_1")
rangee:GetScript("OnDragStart")(rangee)
local glisse = LCM.UI.Glisser.objet
verifier(glisse and glisse.refs and #glisse.refs == 6, "glisser multiple depuis le compendium absent")
verifier(blocs.sacs.lignes[1].glisserAccepte(glisse), "la case de sac refuse la selection")
blocs.sacs.lignes[1].glisserDepose(glisse)
verifier(#brouillon.loot.sacs == 6 and blocs.sacs.lignes[7].vide,
    "le depot multiple n'a pas cree six lots et une case vide")
LCM.UI.Glisser.objet = nil
if LCM.UI.Glisser.fantome then LCM.UI.Glisser.fantome:Hide() end

blocs.ventre.lignes[1]:Click()
verifier((function()
    for _, option in ipairs(choix.options) do if option.id == objet then return true end end
end)(), "le ventre ne propose pas tous les objets")
choix.recherche:Saisir("Coeur de golem")
for _, case in ipairs(choix.cases) do if case:IsShown() then case:Click() break end end
choix.valider:Click()
verifier(brouillon.loot.ventre[1].entree == objet, "objet du ventre absent")
verifier(blocs.ventre.lignes[1].dd:IsShown(), "champ DD du ventre absent")
verifier(LCM.Creation.LootPropre(brouillon.loot).ventre[1].dd == nil,
    "DD vide du ventre non conserve")

local pnj = LCM.PNJ.Add({ id = "pnj_loot_builder", label = "PNJ butin test", valeurs = {},
    loot = LCM.Creation.LootPropre(brouillon.loot) })
__position(100, 200, 0)
local id = LCM.CadavresMJ.PoserPNJ(pnj.id)
local lot = LCM.Cadavres.Lots(LCM.Cadavres.connus[id], "ventre")[1]
verifier(lot and LCM.Cadavres.DD(lot) == nil, "le ventre sans DD demande un jet")
local ouverture = LCM.CadavresMJ.Traiter("Joueur-Apertus", { i = id, a = "ouvrir" })
verifier(ouverture.ouvert == 1, "cadavre impossible a ouvrir")
local prise = LCM.CadavresMJ.Traiter("Joueur-Apertus", { i = id, a = "prendre", l = lot.id })
verifier(prise.donne and prise.donne.e == objet, "le ventre sans DD n'est pas prenable directement")

brouillon.loot.ventre[1].dd = 12
verifier(LCM.Creation.LootPropre(brouillon.loot).ventre[1].dd == 12, "DD du ventre non enregistre")
local avecDD = LCM.PNJ.Add({ id = "pnj_loot_dd", label = "PNJ butin DD", valeurs = {},
    loot = LCM.Creation.LootPropre(brouillon.loot) })
local idDD = LCM.CadavresMJ.PoserPNJ(avecDD.id)
local lotDD = LCM.Cadavres.Lots(LCM.Cadavres.connus[idDD], "ventre")[1]
verifier(LCM.Cadavres.DD(lotDD) == 12, "DD du ventre perdu au cadavre")
LCM.CadavresMJ.Traiter("Joueur-Apertus", { i = idDD, a = "ouvrir" })
local rate = LCM.CadavresMJ.Traiter("Joueur-Apertus", { i = idDD, a = "prendre", l = lotDD.id, t = 10 })
verifier(rate.rate == 1, "le DD du ventre n'a pas bloque un jet insuffisant")
local reussi = LCM.CadavresMJ.Traiter("Joueur-Apertus", { i = idDD, a = "prendre", l = lotDD.id, t = 13 })
verifier(reussi.donne and reussi.donne.e == objet, "le DD du ventre bloque un jet reussi")
print("TOUT PASSE")
