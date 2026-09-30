-- La fenetre de fiche : construction, onglets, lignes, corps.
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
-- Un champ masque (pv_max, montre par la jauge des PV) ne se dessine pas ; un
-- champ reserve au MJ se dessine ici, le compagnon MJ etant charge.
local total, attenduTotal = 0, 0
for _, tab in ipairs(LCM.Schema.Tabs()) do
    local page = f.pages[tab.id]
    local champs = 0
    for _, section in ipairs(tab.sections) do
        for _, field in ipairs(section.fields) do
            if not field.masque then champs = champs + 1 end
        end
    end
    attendu("onglet " .. tab.id, #page.lignes, champs)
    total = total + #page.lignes
    attenduTotal = attenduTotal + champs
end
attendu("total des lignes", total, attenduTotal)
attendu("un seul champ masque", LCM.Schema.Count() - total, 1)

dire("== la mise en page du modele Necronicon")
attendu("bande d'onglets", f.barre.boutons ~= nil, true)
local largeurBandeau = f.barre:GetWidth()
local finRangee = 0
for _, b in ipairs(f.barre.boutons) do
    local _, _, _, x = b:GetPoint(1)
    finRangee = math.max(finRangee, (x or 0) + b:GetWidth())
end
attendu("aucun onglet ne deborde", finRangee <= largeurBandeau + 0.5, true)
attendu("onglet actif dore", select(1, f.barre.boutons[1].label:GetTextColor()) > 0.95, true)
attendu("titre en capitales", f.titre:GetText(), "FICHE")
local bloc = f.pages.general.blocs[1]
attendu("section en bloc titre", bloc.titre:GetText(), "VITALITÉ")

dire("== le corps : jauge des PV et une jauge par zone")
local ligneCorps
for _, l in ipairs(f.pages.general.lignes) do
    if l.zones then ligneCorps = l end
end
attendu("la ligne corps existe", ligneCorps ~= nil, true)
local visibles = 0
for _, z in ipairs(ligneCorps.zones) do if z:IsShown() then visibles = visibles + 1 end end
attendu("5 zones (template)", visibles, 5)
attendu("le total est affiche", ligneCorps.total.barre.label:GetText(), "42 / 42")
local tete = ligneCorps.zones[1]
attendu("la tete a son icone", tete.icone:GetTexture() ~= nil, true)
attendu("30 % par zone", tete.barre.label:GetText(), "12 / 12")

dire("== blesser avec les boutons")
local bras
for _, z in ipairs(ligneCorps.zones) do if z.partieId == "bras" then bras = z end end
attendu("le bras est la", bras ~= nil, true)
bras.boutons[1]:Click()
attendu("un point en moins", LCM.Body.Totals(moi), 41)
attendu("l affichage suit", ligneCorps.total.barre.label:GetText(), "41 / 42")
attendu("la zone aussi", bras.barre.label:GetText(), "11 / 12")
bras.boutons[3]:Click()
attendu("R soigne la zone", LCM.Body.Totals(moi), 42)

dire("== la case d'avantage n'apparait que si un trait la justifie")
f:Afficher("expertises")
local ligneEscalade, ligneCourse
for _, l in ipairs(f.pages.expertises.lignes) do
    if l.label and l.label:GetText() == "Escalade" then ligneEscalade = l end
    if l.label and l.label:GetText() == "Course" then ligneCourse = l end
end
attendu("escalade : case visible", ligneEscalade.avantage:IsShown(), true)
attendu("course : case masquee", ligneCourse.avantage:IsShown(), false)
attendu("valeur", ligneEscalade.valeur:GetText(), "4")
attendu("le bonus de trait dans sa colonne", ligneEscalade.bonus:GetText(), "+3")

dire("== le bouton de jet")
local avant = #__sorties
ligneEscalade.lancer:Click()
attendu("un jet est annonce", #__sorties > avant, true)
dire("   " .. __sansCouleur(__sorties[#__sorties]))

dire("== fermeture")
SlashCmdList.LCM("fiche")
attendu("la fenetre se referme", f:IsShown(), false)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
