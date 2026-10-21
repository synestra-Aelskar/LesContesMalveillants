-- L'onglet Traits du panneau MJ : recherche, filtre, ligne entiere cliquable.
-- 21 octobre 2026 : la page n'etait qu'une colonne de cases « Nom · 2 pts »,
-- sans recherche ; trouver un trait demandait de tout faire defiler.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()

-- Des traits temoins : on ne compte pas sur ceux de la campagne, qui bougent.
LCM.Traits.Add({ id = "temoin_echo", label = "Écho des profondeurs", cout = 2,
                 description = "Entend les murmures." })
LCM.Traits.Add({ id = "temoin_lame", label = "Lame vive", cout = 1,
                 description = "Frappe la première." })

__groupe({ "Nytherah-Apertus" })
local p = LCM.UI.PanneauMJ.Basculer()
local onglets = {}
for _, b in ipairs(p.barre.boutons) do onglets[b.ongletId] = b end
onglets.traits:Click()
local page = p.pages.traits
attendu("l'onglet Traits est ouvert", page:IsShown(), true)
attendu("le joueur est choisi d'office", page.joueurActif, "Nytherah-Apertus")

local function Ligne(label)
    for _, l in ipairs(page.lignesTraits) do
        if l:IsShown() and l.nom:GetText() == label then return l end
    end
end

dire("== la recherche")
page.rechercheTraits:Saisir("echo")
attendu("sans accent, « echo » trouve « Écho »", Ligne("Écho des profondeurs") ~= nil, true)
attendu("et pas le reste", Ligne("Lame vive"), nil)
page.rechercheTraits:Saisir("première")
attendu("la description compte aussi", Ligne("Lame vive") ~= nil, true)
page.rechercheTraits:Saisir("zzzz")
attendu("rien ne correspond, et on le dit", page.videTraits:GetText(), "Aucun trait ne correspond.")
page.rechercheTraits:Saisir("")

dire("== une ligne se clique en entier")
local l = Ligne("Lame vive")
attendu("le cout a sa colonne", l.cout:GetText(), "1 pt")
attendu("caché au départ", l.case:EstCochee(), false)
l:Click()
attendu("le clic sur la ligne l'ouvre au joueur",
    LCM.AccesTraits.Liste("Nytherah-Apertus").temoin_lame, true)
attendu("la case suit", l.case:EstCochee(), true)
attendu("et l'envoi part au joueur", __envois[#__envois].cible, "Nytherah-Apertus")
l.case:Click()
attendu("la case seule le referme", LCM.AccesTraits.Liste("Nytherah-Apertus").temoin_lame, nil)

dire("== le filtre")
Ligne("Écho des profondeurs"):Click()
page.filtres.boutons[2]:Click()
attendu("« Visibles » garde l'ouvert", Ligne("Écho des profondeurs") ~= nil, true)
attendu("et retire le caché", Ligne("Lame vive"), nil)
page.filtres.boutons[3]:Click()
attendu("« Cachés » fait l'inverse", Ligne("Lame vive") ~= nil and Ligne("Écho des profondeurs") == nil, true)
page.filtres.boutons[1]:Click()
attendu("le compte dit ce qui est ouvert", page.compteTraits:GetText():find("1 sur", 1, true) ~= nil, true)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
