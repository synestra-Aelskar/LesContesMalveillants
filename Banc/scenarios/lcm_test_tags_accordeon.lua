-- Les tags, deux corrections du 3 novembre 2026 (le MJ) :
--   * « J'ai cree un tag avec 4 origines, mais le sous-tag avec une seule » —
--     et le sous-tag s'affichait sous les quatre. Le formulaire montre les
--     Origines AVANT le Parent : cocher l'origine puis choisir le parent
--     ecrasait le choix par toutes les origines du parent ;
--   * « Ca devient imbuvable si t'as 500 tags » : la fenetre de choix des
--     tags se replie en accordeon (groupes et branches).
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()
local E = LCM.Etiquettes

-- Des origines TEMOINS : celles de la campagne bougent a chaque seance.
local o = {}
for i = 1, 4 do
    o[i] = LCM.Listes.Add({ id = "orig_accordeon_" .. i, liste = "origines", label = "Témoin " .. i }).id
end
local F = LCM.UI.Compendium
F.Ouvrir("liste_tags")
local fen = F.frame
local ed

local function cocherOrigines(ids)
    ed.origine:Click()
    local veut = {}
    for _, id in ipairs(ids) do veut[id] = true end
    for _, c in ipairs(ed.choixOrigine.cases) do
        if c:IsShown() and (veut[c.id] == true) ~= (ed.choixOrigine.selection[c.id] == true) then c:Click() end
    end
    ed.choixOrigine.valider:Click()
end
local function choisirParent(id)
    ed.parent:Click()
    for _, l in ipairs(ed.choixParent.lignes) do if l:IsShown() and l.choix == id then l:Click() break end end
end
local function tag(nom)
    for _, e in ipairs(E.Liste()) do if e.label == nom then return e end end
end
local function creer(nom, faire)
    fen.nouveauTag:Click()
    ed = LCM.TagsUI.frame
    ed.nom:SetText(nom)
    faire()
    ed:Valider()
    return tag(nom)
end

dire("== l'origine d'un sous-tag survit au choix du parent")
local raptor = creer("Raptor témoin", function() cocherOrigines(o) end)
attendu("le parent a ses quatre origines", #E.Origines(raptor), 4)
local foudre = creer("Foudre témoin", function()
    cocherOrigines({ o[2] })
    choisirParent(raptor.id)
end)
attendu("origine cochée PUIS parent : une seule origine", table.concat(E.Origines(foudre), ","), o[2])
local braise = creer("Braise témoin", function()
    choisirParent(raptor.id)
    cocherOrigines({ o[3] })
end)
attendu("parent PUIS origine : une seule aussi", table.concat(E.Origines(braise), ","), o[3])
local dent = creer("Dent témoin", function() choisirParent(raptor.id) end)
attendu("sans choix propre : toutes celles du parent", #E.Origines(dent), 4)

-- Une origine que le parent ne porte pas ne passe pas en douce : elle est
-- retiree, et on le dit.
local autre = LCM.Listes.Add({ id = "orig_accordeon_hors", liste = "origines", label = "Hors parent" }).id
local petit = creer("Petit parent", function() cocherOrigines({ o[1] }) end)
fen.nouveauTag:Click()
ed.nom:SetText("Écaille témoin")
cocherOrigines({ autre })
choisirParent(petit.id)
attendu("une origine hors du parent est retirée", table.concat(E.Origines(ed.travail), ","), o[1])
attendu("  et l'écran le dit", ed.erreur:GetText() ~= "", true)
ed:Hide()

dire("== sous chaque origine, seulement là où il existe")
local ou = {}
for _, g in ipairs(E.Groupes()) do
    for _, l in ipairs(g.tags) do if l.tag.id == foudre.id then ou[#ou + 1] = g.id end end
end
attendu("Foudre n'est que sous son origine", table.concat(ou, ","), o[2])

dire("== l'accordéon")
local choix = UI and UI.ChoixTags or LCM.UI.ChoixTags
local d = choix("essai_accordeon")
local popup = d.coches
d:Proposer("Filtrer par tags", nil, function() end)
local function visible(id)
    for _, c in ipairs(popup.cases) do if c:IsShown() and c.id == id then return true end end
    return false
end
local function entete(origine)
    -- Par la cle du groupe : le libelle passe en capitales (« TÉMOIN »), et
    -- string.upper de Lua ne sait pas faire les accents.
    for _, t in ipairs(popup.entetes) do
        if t:IsShown() and t.cle and t.cle:sub(-#origine) == origine then return t end
    end
end
local function cases()
    local n = 0
    for _, c in ipairs(popup.cases) do if c:IsShown() then n = n + 1 end end
    return n
end
attendu("tout part replié : aucune case", cases(), 0)
attendu("  l'en-tête montre un pli fermé", entete(o[2]).signe.ouvert, false)
-- Sous Témoin 2 : Raptor, Foudre et Dent (Braise est sous Témoin 3).
attendu("  et combien il contient", entete(o[2]).compte:GetText(), "3")
attendu("la fenêtre est haute, même repliée", popup:GetHeight() >= 420, true)
local secondes = 0
for i, t in ipairs(popup.entetes) do if t:IsShown() and t.filet:IsShown() then secondes = secondes + 1 end end
attendu("un gros séparateur entre deux origines, pas au-dessus de la première",
    popup.entetes[1].filet:IsShown() == false and secondes >= 1, true)
entete(o[2]):Click()
attendu("ouvrir une origine montre ses racines", visible(raptor.id), true)
attendu("  mais pas encore leurs sous-tags", visible(foudre.id), false)
local caseRaptor
for _, c in ipairs(popup.cases) do if c:IsShown() and c.id == raptor.id then caseRaptor = c end end
attendu("Raptor a un pli", caseRaptor.pli:IsShown(), true)
attendu("  fermé", caseRaptor.pli.ouvert, false)
caseRaptor.pli:Click()
attendu("déplier Raptor montre Foudre", visible(foudre.id), true)
attendu("  le pli dit ouvert", caseRaptor.pli.ouvert, true)
local traits = 0
for _, t in ipairs(popup.traits) do if t:IsShown() then traits = traits + 1 end end
attendu("  et l'arbre se dessine (L, séparateurs)", traits >= 3, true)
local caseFoudre
for _, c in ipairs(popup.cases) do if c:IsShown() and c.id == foudre.id then caseFoudre = c end end
attendu("Foudre est en retrait de Raptor", select(4, caseFoudre:GetPoint(1)) > select(4, caseRaptor:GetPoint(1)), true)
-- Le liseré d'un pixel REEL (capture du MJ, 3 novembre 2026 : des cases a
-- qui manquaient un ou deux cotes). Le banc annonce un ecran de 1080 pixels :
-- un pixel y vaut 768/1080 d'unite, a l'echelle 1.
local cachees = true
for _, t in ipairs(caseFoudre.bordure) do if t:IsShown() then cachees = false end end
attendu("les traits d'une unité sont retirés", cachees, true)
local _, _, _, retrait = caseFoudre.interieur:GetPoint(1)
attendu("  le fond est en retrait d'un pixel réel", string.format("%.4f", retrait), string.format("%.4f", 768 / 1080))
attendu("  le pli a le même liseré", caseRaptor.pli.contour ~= nil, true)
caseFoudre.ligne:Click()
attendu("cliquer sur le nom coche aussi", popup.selection[foudre.id], true)
caseFoudre.ligne:Click()
attendu("  les autres origines restent repliées", visible(dent.id) and cases() <= 4, true)
-- Cocher depuis la liste depliee, puis rouvrir : le chemin vers ce qui est
-- coche s'ouvre tout seul.
for _, c in ipairs(popup.cases) do if c:IsShown() and c.id == foudre.id then c:Click() end end
attendu("l'en-tête compte ce qui est coché", entete(o[2]).compte:GetText():find("1 coché", 1, true) ~= nil, true)
popup.valider:Click()

local d2 = choix("essai_accordeon_2")
d2:Proposer("Filtrer", { [braise.id] = true }, function() end)
local p2 = d2.coches
local vu = false
for _, c in ipairs(p2.cases) do if c:IsShown() and c.id == braise.id then vu = true end end
attendu("rouvrir sur un choix : il se voit sans rien déplier", vu, true)

dire("== ce qu'on a ouvert reste ouvert d'une fois à l'autre")
d:Proposer("Filtrer par tags", nil, function() end)
attendu("Foudre se voit encore", visible(foudre.id), true)
entete(o[2]):Click()
attendu("replier l'origine cache tout", visible(raptor.id), false)

dire("== un seul groupe : pas de pli inutile")
local unique = LCM.UI.ChoixCoches("essai_unique", "Un")
unique.accordeon = true
unique:Proposer("Un", { { label = "Seul", options = { { id = "a", label = "A" }, { id = "b", label = "B" } } } }, {}, function() end)
local n = 0
for _, c in ipairs(unique.cases) do if c:IsShown() then n = n + 1 end end
attendu("le groupe unique est ouvert", n, 2)

dire("== hors accordéon, rien ne change")
local plat = LCM.UI.ChoixCoches("essai_plat", "Plat")
plat:Proposer("Plat", { { label = "G1", options = { { id = "a", label = "A" } } },
    { label = "G2", options = { { id = "b", label = "B", niveau = 1 } } } }, {}, function() end)
n = 0
for _, c in ipairs(plat.cases) do if c:IsShown() then n = n + 1 end end
attendu("toutes les cases se voient", n, 2)
attendu("  sans pli", plat.cases[2].pli:IsShown(), false)
attendu("  et l'en-tête sans signe", plat.entetes[1]:GetText(), "G1")

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
