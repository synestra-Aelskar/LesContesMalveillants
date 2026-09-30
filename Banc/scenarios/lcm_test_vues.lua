-- Les fenetres du menu tirees de la fiche : registre, liaison au menu,
-- fenetres Sante et Expertise.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
local V = LCM.Vues
local R = LCM.UI.Radial

dire("== le registre refuse les references fausses")
local function refus(definition)
    local ok, err = pcall(V.Add, definition)
    return ok == false and tostring(err) or "ACCEPTE"
end
dire("   " .. refus({ id = "a", blocs = { { onglet = "inexistant" } } }))
attendu("onglet inconnu", refus({ id = "a", blocs = { { onglet = "inexistant" } } }):find("onglet inconnu") ~= nil, true)
attendu("section inconnue", refus({ id = "b", blocs = { { section = { "general", "Nulle part" } } } }):find("absente") ~= nil, true)
attendu("champ inconnu", refus({ id = "c", blocs = { { champs = { "force", "rien" } } } }):find("champ inconnu") ~= nil, true)
attendu("vue vide", refus({ id = "d", blocs = {} }):find("vue vide") ~= nil, true)
attendu("bloc sans cible", refus({ id = "e", blocs = { { label = "x" } } }):find("designe") ~= nil, true)
attendu("doublon", refus({ id = "sante", blocs = { { onglet = "general" } } }):find("en double") ~= nil, true)
attendu("rien d'enregistre par les refus", #V.list, 2)

dire("== les vues declarees")
local sante, expertise = V.Get("sante"), V.Get("expertise")
attendu("sante", sante ~= nil, true)
attendu("sante : une section", #sante.sections, 1)
attendu("c'est Vitalite", sante.sections[1].label, "Vitalite")
attendu("expertise : les trois domaines", #expertise.sections, 3)
local n = 0
for _, s in ipairs(expertise.sections) do n = n + #s.fields end
attendu("25 expertises", n, 25)

dire("== le menu s'allume")
attendu("Sante liee", R.EstLiee("sante"), true)
attendu("Expertise liee", R.EstLiee("expertise"), true)
attendu("Apprentissage reste eteinte", R.EstLiee("apprentissage"), false)

dire("== Sante")
local moi = LCM.Entities.Self()
LCM.Entities.Set_Value(moi, "race", "humain")
LCM.Entities.Set_Value(moi, "niveau", 5)
LCM.Entities.Set_Value(moi, "constitution", 6)
LCM.Entities.Set_Value(moi, "sec_vitalite", 4)
R.Trouver("sante").onClick()
local fs = LCM.UI.Vues.frames.sante
attendu("ouverte", fs:IsShown(), true)
attendu("titre", fs.titre:GetText(), "Santé")
attendu("nom du personnage", fs.nom:GetText(), tostring(moi.name))
attendu("une ligne par champ", #fs.page.lignes, #sante.sections[1].fields)
local corps
for _, l in ipairs(fs.page.lignes) do if l.silhouette then corps = l end end
attendu("la silhouette y est", corps ~= nil, true)
attendu("les PV sont lus", corps.total:GetText(), "23 / 23 PV")
attendu("la page est visible", fs.page:IsShown(), true)

dire("== la blessure se voit dans la fiche")
local bras
for _, p in ipairs(corps.silhouette.parties) do if p.partieId == "bras_1" then bras = p end end
bras:GetScript("OnMouseWheel")(bras, -1)
attendu("un PV de moins", corps.total:GetText(), "22 / 23 PV")
SlashCmdList.LCM("fiche")
local ligneFiche
for _, l in ipairs(LCM.UI.Fiche.frame.pages.general.lignes) do if l.silhouette then ligneFiche = l end end
attendu("la fiche le montre", ligneFiche.total:GetText(), "22 / 23 PV")
SlashCmdList.LCM("fiche")
bras:GetScript("OnMouseWheel")(bras, 1)

dire("== Expertise")
LCM.Entities.Set_Value(moi, "escalade", 4)
LCM.Traits.Grant(moi, "escalade_jungle")
R.Trouver("expertise").onClick()
local fe = LCM.UI.Vues.frames.expertise
attendu("ouverte", fe:IsShown(), true)
attendu("25 lignes", #fe.page.lignes, 25)
local escalade
for _, l in ipairs(fe.page.lignes) do if l.label:GetText() == "Escalade" then escalade = l end end
attendu("bonus de trait montre", escalade.valeur:GetText(), "4 +3")
attendu("case d'avantage", escalade.avantage:IsShown(), true)
local avant = #__sorties
escalade.lancer:Click()
attendu("le jet part", #__sorties > avant, true)
dire("   " .. __sansCouleur(__sorties[#__sorties]))
attendu("le contenu depasse et defile", fe.zone.hauteurContenu > fe.page.lignes[1]:GetHeight() * 20, true)
attendu("pas a la meme place que Sante",
    select(4, fe:GetPoint(1)) ~= select(4, fs:GetPoint(1)), true)

dire("== reclic : se referme ; rouvrir relit le personnage joue")
R.Trouver("expertise").onClick()
attendu("refermee", fe:IsShown(), false)
local autre = LCM.Personnages.Creer("Ysolde", { race = "humain", niveau = 3 })
LCM.Personnages.Choisir(autre.id)
R.Trouver("expertise").onClick()
attendu("montre le nouveau personnage", fe.nom:GetText(), "Ysolde")
attendu("plus le bonus de l'ancien", escalade.valeur:GetText(), "0")
attendu("meme fenetre, pas une nouvelle", LCM.UI.Vues.frames.expertise, fe)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
