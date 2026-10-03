-- En direct (3 octobre 2026) : un geste qui change le personnage met a jour
-- les fenetres ouvertes, sans changer d'onglet ni rouvrir (Core/Direct.lua).
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()
local O, I = LCM.Objets, LCM.Inventaire
local moi = LCM.Entities.Self()
LCM.Personnages.Choisir(moi.id)
O.Add({ id = "dague_vive", label = "Dague vive", categorie = "arme",
    bonus = { pen_tranchant = 2, pen_perforant = 4 } })
I.Poser(moi, "sacs", 1, "gros_sac")
I.Ranger(moi, "sacs", 1, 1, "objets/dague_vive", 1)

dire("== L'exemple : Statistiques ouvertes sur Penetrations, on equipe")
LCM.UI.Menu.Trouver("statistiques").onClick()
local fst = LCM.UI.Vues.frames.statistiques
for _, e in ipairs(fst.sommaire.entrees) do
    if e:IsShown() and e.ongletId == "penetrations" then e:Click() end
end
local pen = fst.pages.penetrations.blocs[1]
local function Valeur(label)
    for _, l in ipairs(pen.lignes) do
        if l:IsShown() and l.label and l.label:GetText() == label then return l.valeur:GetText() end
    end
end
attendu("Tranchant avant", Valeur("Tranchant"), "0")
O.Equiper(moi, "dague_vive")
attendu("Tranchant aussitot", Valeur("Tranchant"), "2")
attendu("Perforant aussitot", Valeur("Perforant"), "4")
attendu("sans changer d'onglet", fst.onglet, "penetrations")
O.Desequiper(moi, "dague_vive")
attendu("retiree : retour a 0", Valeur("Tranchant"), "0")

dire("== Un geste ne previent qu'une fois, a la fin")
local appels = 0
LCM.Entities.Ecouter(function(entity) if entity == moi then appels = appels + 1 end end)
O.Equiper(moi, "dague_vive")      -- Placer + sortir du sac : deux gestes enveloppes
attendu("une seule notification", appels, 1)
appels = 0
LCM.Entities.Set_Value(moi, "force", 3)
attendu("une valeur de fiche aussi", appels, 1)

dire("== L'inventaire ouvert suit")
O.Desequiper(moi, "dague_vive")
local inv = LCM.UI.Inventaires.Fenetre()
inv:Show()
inv.cartes[1]:Click("LeftButton")
attendu("la dague est au sac", inv.lignes[1].nom:GetText(), "Dague vive")
O.Equiper(moi, "dague_vive")
attendu("equipee : la case se vide aussitot", inv.lignes[1].nom:GetText(), "Vide")
I.Deposer(moi, "ressources/eau", 1)
attendu("un depot apparait aussitot", inv.lignes[1].nom:GetText(), "Eau")
inv:Hide()

dire("== Une erreur dans un geste ne bloque pas la suite")
local avant = LCM.Direct.profondeur
local ok = pcall(O.Equiper, nil, "dague_vive")
attendu("refuse proprement", ok, true)
attendu("profondeur revenue", LCM.Direct.profondeur, avant)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
