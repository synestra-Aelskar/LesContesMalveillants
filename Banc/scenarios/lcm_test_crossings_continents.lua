-- Crossings : les CONTINENTS (3 novembre 2026).
--
-- Un cran de plus au-dessus du pays : un continent range des pays comme un
-- pays range des regions. Il n'a ni trace, ni aura, ni banniere — pas de
-- geographie a lui, seulement celle de ce qu'il contient.
--
-- Ce qu'on verifie :
--
--   * le rangement : creer, renommer, deplacer un pays, supprimer sans rien
--     perdre — les pays d'un continent supprime restent, sans continent ;
--   * l'arbre du panneau : le continent au-dessus de ses pays, et les pays
--     sans continent la ou ils ont toujours ete ;
--   * la carte M : un menu de plus, un niveau « continent » qui montre les
--     regions de TOUS ses pays, et un nom qui s'apprend comme celui d'un
--     pays — on ne devine pas sur quelle terre on marche ;
--   * et la serialisation, sinon rien n'arriverait au binome.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end
local function essai(libelle, fn)
    local ok, err = pcall(fn)
    attendu(libelle, ok and "ok" or tostring(err), "ok")
end

__declencher("PLAYER_LOGIN")
__personnage()
LCM.db.settings.modeJoueur = nil
LCM._masterCompanion = true

local ZG = LCM.Crossings
local panneau = LCMCrossingsPanel
local function Poser(x, y) __position(y, x, 0) end
local function Tracer(sub, points)
    for _, p in ipairs(points) do
        Poser(p[1], p[2])
        ZG:AddRegionPoint(sub.id)
    end
    return sub
end
local function ZoneDuLieu(place) return ZG:GetPlaceAreas(place.id)[1].sub end
local function Joueur() LCM.db.settings.modeJoueur = true; LCM._masterCompanion = nil end
local function Maitre() LCM.db.settings.modeJoueur = nil; LCM._masterCompanion = true end

local perso = __personnage()
LCM.Personnages.Choisir(perso.id)

dire("== un continent range des pays")
local terre = ZG:CreateContinent("Aelskar")
attendu("le continent est cree", terre ~= nil, true)
attendu("  il porte son nom", terre.name, "Aelskar")
attendu("  et il se liste", #ZG:GetContinentList(), 1)

local nord = ZG:CreateCountry("Le Royaume du Nord", terre.id)
local sud = ZG:CreateCountry("Les Marches du Sud", terre.id)
local ailleurs = ZG:CreateCountry("L'Archipel")
attendu("deux pays y sont ranges", #ZG:GetCountryList(terre.id), 2)
attendu("  le troisieme n'en a pas", ailleurs.continentId, nil)
-- La seance peut deja contenir des pays : on ne compte pas, on cherche.
local function Dans(liste, id)
    for _, e in ipairs(liste) do if e.id == id then return true end end
    return false
end
attendu("  et il se liste parmi les sans-continent", Dans(ZG:GetCountryList(""), ailleurs.id), true)
attendu("  mais pas parmi ceux du continent", Dans(ZG:GetCountryList(terre.id), ailleurs.id), false)
attendu("sans argument, tous les pays", Dans(ZG:GetCountryList(), nord.id)
    and Dans(ZG:GetCountryList(), ailleurs.id), true)

-- On deplace un pays d'un continent a l'autre, et on l'en sort.
attendu("on y range le troisieme", (function()
    ZG:SetCountryContinent(ailleurs.id, terre.id)
    return #ZG:GetCountryList(terre.id)
end)(), 3)
ZG:SetCountryContinent(ailleurs.id, "")
attendu("  et on l'en ressort", ailleurs.continentId, nil)

ZG:RenameContinent(terre.id, "Aelskar la Vieille")
attendu("il se renomme", ZG:GetContinent(terre.id).name, "Aelskar la Vieille")

dire("== supprimer un continent ne perd aucun pays")
local jetable = ZG:CreateContinent("Terre d'essai")
ZG:SetCountryContinent(ailleurs.id, jetable.id)
ZG:RemoveContinent(jetable.id)
attendu("le continent est parti", ZG:GetContinent(jetable.id), nil)
attendu("  le pays est reste", ZG:GetCountry(ailleurs.id) ~= nil, true)
attendu("  mais sans continent", ailleurs.continentId, nil)

dire("== l'arbre du panneau montre le cran de plus")
local combe = ZG:CreateZone("La Combe", nord.id)
local village = ZG:CreatePlace(combe.id, "Le Village")
Tracer(ZoneDuLieu(village), { { 0, 0 }, { 80, 0 }, { 80, 80 }, { 0, 80 } })
ZG:FinishRegion(ZoneDuLieu(village).id)
local isles = ZG:CreateZone("Les Iles", ailleurs.id)
local quai = ZG:CreatePlace(isles.id, "Le Quai")
Tracer(ZoneDuLieu(quai), { { 500, 500 }, { 560, 500 }, { 560, 560 }, { 500, 560 } })
ZG:FinishRegion(ZoneDuLieu(quai).id)

essai("on ouvre le continent dans le panneau", function()
    panneau.mode, panneau.continentId = "continent", terre.id
    panneau:RefreshAll()
end)
local vues = {}
for _, row in ipairs(panneau.treeRows or {}) do
    if row:IsShown() then
        local texte = row.label:GetText() or ""
        vues[#vues + 1] = texte
    end
end
local function Trouve(mot)
    for _, t in ipairs(vues) do if t:find(mot, 1, true) then return true end end
    return false
end
attendu("le continent est dans l'arbre", Trouve("AELSKAR LA VIEILLE"), true)
attendu("  et l'archipel aussi, a son rang", Trouve("L'ARCHIPEL"), true)
attendu("la fiche du continent s'affiche", panneau.cont.form:IsShown(), true)
attendu("  avec son nom", panneau.cont.nom:GetText(), "Aelskar la Vieille")

essai("et la fiche d'un pays dit son continent", function()
    panneau.mode, panneau.countryId = "country", nord.id
    panneau:RefreshAll()
end)

-- Les gestes du panneau, pour de vrai : une ligne de l'arbre qui propose
-- « Nouveau pays ici », et le bouton de la fiche. Ils passaient par un nom de
-- fonction qui n'existait plus, ce qu'aucun test du modele n'aurait vu.
dire("== les gestes du panneau repondent")
local function Creer(declencher, nom)
    declencher()
    local p = panneau.createPrompt
    if not (p and p.onCreate) then error("aucune demande de creation") end
    local fait = p.onCreate
    p:Hide()
    fait(nom)
end
essai("l'arbre cree un pays dans le continent", function()
    panneau.mode, panneau.continentId = "continent", terre.id
    panneau:RefreshAll()
    local ligne
    for _, row in ipairs(panneau.treeRows or {}) do
        if row:IsShown() and (row.label:GetText() or ""):find("AELSKAR LA VIEILLE", 1, true) then
            ligne = row
        end
    end
    if not ligne or not ligne.context then error("pas de menu sur la ligne du continent") end
    local faire
    for _, item in ipairs(ligne.context) do
        if item.text == "Nouveau pays ici" then faire = item.func end
    end
    if not faire then error("pas de « Nouveau pays ici »") end
    Creer(faire, "Terre neuve")
end)
local neuf
for _, c in ipairs(ZG:GetCountryList(terre.id)) do
    if c.name == "Terre neuve" then neuf = c end
end
attendu("le pays est ne dans le continent", neuf ~= nil, true)
essai("et le bouton de la fiche aussi", function()
    panneau.mode, panneau.continentId = "continent", terre.id
    panneau:RefreshAll()
    Creer(function() panneau.cont.ajouter:Click() end, "Terre plus neuve")
end)
local second
for _, c in ipairs(ZG:GetCountryList(terre.id)) do
    if c.name == "Terre plus neuve" then second = c end
end
attendu("le second y est aussi", second ~= nil, true)
for _, c in ipairs(ZG:GetCountryList(terre.id)) do
    if c.name == "Terre neuve" or c.name == "Terre plus neuve" then ZG:RemoveCountry(c.id) end
end

dire("== la carte M a son menu, et son niveau")
essai("la carte s'ouvre", function() ZG:ShowRegionMap() end)
local win = LCMCrossingsRegionMap
attendu("le menu des continents existe", win.pickerContinent ~= nil, true)

essai("on ouvre le continent", function() win:ShowContinent(terre.id) end)
attendu("on est au niveau du continent", win.level, "continent")
local regions = {}
for _, zone in ipairs(win:Zones()) do regions[zone.id] = true end
attendu("la region de son pays s'y montre", regions[combe.id], true)
attendu("  celle d'un pays d'ailleurs, non", regions[isles.id], nil)

-- Sans continent choisi, tout ce qu'on connait, d'ou que ca vienne.
essai("on regarde tout", function() win:ShowContinent(nil) end)
regions = {}
for _, zone in ipairs(win:Zones()) do regions[zone.id] = true end
attendu("les deux regions s'y montrent", regions[combe.id] and regions[isles.id], true)

-- Descendre dans un pays retient son continent : le menu du haut suit.
essai("on descend dans un pays", function() win:ShowCountry(nord.id) end)
attendu("le menu du haut a suivi", win.continent, terre.id)
essai("  puis dans une region", function() win:ShowRegion(combe) end)
attendu("  il suit encore", win.continent, terre.id)

dire("== le nom d'un continent s'apprend, il ne se devine pas")
Maitre()
attendu("le MJ le connait", ZG:HasLearnedContinentName(terre.id), true)
Joueur()
attendu("le joueur, non", ZG:HasLearnedContinentName(terre.id), false)
Maitre(); ZG:MarkLearnedContinentName(terre.id, true); Joueur()
attendu("une fois donne, il le connait", ZG:HasLearnedContinentName(terre.id), true)
Maitre()

dire("== tout cela traverse la serialisation")
local texte = ZG.PackState()
local avant = LCM_Crossings
LCM_Crossings = { countries = {}, zones = {}, themes = {}, continents = {} }
for ligne in (texte .. "\n"):gmatch("([^\n]+)") do ZG.ApplyStateLine(ligne, UnitName("player")) end
local terreRelue = LCM_Crossings.continents[terre.id]
attendu("le continent revient", terreRelue ~= nil, true)
attendu("  avec son nom", terreRelue and terreRelue.name, "Aelskar la Vieille")
attendu("le pays garde son continent", LCM_Crossings.countries[nord.id].continentId, terre.id)
attendu("  et celui qui n'en a pas n'en gagne pas",
    LCM_Crossings.countries[ailleurs.id].continentId, nil)
-- Un auteur plus ancien n'envoie pas ce champ : son pays revient sans
-- continent, ce qu'il etait.
LCM_Crossings = { countries = {}, zones = {}, themes = {}, continents = {} }
for ligne in (texte .. "\n"):gmatch("([^\n]+)") do
    if ligne:find("^COUNTRY:" .. nord.id .. ":") then ligne = ligne:gsub(":[^:]*$", "") end
    ZG.ApplyStateLine(ligne, UnitName("player"))
end
attendu("sans le champ, pas de continent",
    LCM_Crossings.countries[nord.id].continentId, nil)
attendu("  mais le pays est bien la", LCM_Crossings.countries[nord.id].name, "Le Royaume du Nord")
LCM_Crossings = avant

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
