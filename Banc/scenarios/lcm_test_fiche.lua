-- La fenetre de fiche : construction, onglets, lignes, silhouette.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")

local moi = LCM.Entities.Self()
LCM.Entities.Set_Value(moi, "race", "humain")
LCM.Entities.Set_Value(moi, "niveau", 5)
LCM.Entities.Set_Value(moi, "constitution", 6)
LCM.Entities.Set_Value(moi, "sec_vitalite", 4)
LCM.Entities.Set_Value(moi, "escalade", 4)
LCM.Traits.Grant(moi, "escalade_jungle")

dire("== ouverture")
SlashCmdList.LCM("fiche")
local f = LCM.UI.Fiche.frame
attendu("la fenetre existe", f ~= nil, true)
attendu("elle est affichee", f:IsShown(), true)
attendu("elle porte le nom de l entite", f.nom:GetText(), "Reika")

dire("== onglets")
attendu("un bouton par onglet", #f.barre.boutons, #LCM.Schema.Tabs())
local noms = {}
for _, b in ipairs(f.barre.boutons) do noms[#noms + 1] = b.label:GetText() end
dire("   " .. table.concat(noms, " | "))
attendu("le premier est actif", f.barre.actif, "general")
attendu("sa page est visible", f.pages.general:IsShown(), true)
attendu("les autres non", f.pages.expertises:IsShown(), false)

dire("== une ligne par champ affichable")
local total = 0
for _, tab in ipairs(LCM.Schema.Tabs()) do
    local page = f.pages[tab.id]
    local champs = 0
    for _, section in ipairs(tab.sections) do champs = champs + #section.fields end
    attendu("onglet " .. tab.id, #page.lignes, champs)
    total = total + #page.lignes
end
attendu("total des lignes", total, LCM.Schema.Count())

dire("== la silhouette")
local ligneCorps
for _, l in ipairs(f.pages.general.lignes) do
    if l.silhouette then ligneCorps = l end
end
attendu("la ligne corps existe", ligneCorps ~= nil, true)
local visibles = 0
for _, p in ipairs(ligneCorps.silhouette.parties) do
    if p:IsShown() then visibles = visibles + 1 end
end
attendu("7 parties dessinees", visibles, 7)
attendu("le total est affiche", ligneCorps.total:GetText(), "23 / 23 PV")

dire("   placement :")
for _, p in ipairs(ligneCorps.silhouette.parties) do
    if p:IsShown() then
        local _, _, _, x, y = p:GetPoint(1)
        dire(string.format("     %-14s %5.0f x %5.0f  a (%4.0f, %4.0f)  %s",
            p.donnees.label, p:GetWidth(), p:GetHeight(), x or 0, y or 0, p.label:GetText()))
    end
end

dire("== blesser a la molette")
local bras
for _, p in ipairs(ligneCorps.silhouette.parties) do
    if p.partieId == "bras_1" then bras = p end
end
attendu("le bras est la", bras ~= nil, true)
bras:GetScript("OnMouseWheel")(bras, -1)
attendu("un point en moins", LCM.Body.Totals(moi), 22)
attendu("l affichage suit", ligneCorps.total:GetText(), "22 / 23 PV")
bras:GetScript("OnMouseWheel")(bras, 1)
attendu("soigne", LCM.Body.Totals(moi), 23)

dire("== la case d'avantage n'apparait que si un trait la justifie")
f:Afficher("expertises")
local ligneEscalade, ligneCourse
for _, l in ipairs(f.pages.expertises.lignes) do
    if l.label and l.label:GetText() == "Escalade" then ligneEscalade = l end
    if l.label and l.label:GetText() == "Course" then ligneCourse = l end
end
attendu("escalade : case visible", ligneEscalade.avantage:IsShown(), true)
attendu("course : case masquee", ligneCourse.avantage:IsShown(), false)
attendu("le bonus de trait est montre", ligneEscalade.valeur:GetText(), "4 +3")

dire("== le bouton de jet")
local avant = #__sorties
ligneEscalade.lancer:Click()
attendu("un jet est annonce", #__sorties > avant, true)
dire("   " .. __sansCouleur(__sorties[#__sorties]))

dire("== fermeture")
SlashCmdList.LCM("fiche")
attendu("la fenetre se referme", f:IsShown(), false)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
