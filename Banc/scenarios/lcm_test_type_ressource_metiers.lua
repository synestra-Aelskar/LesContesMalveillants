-- Les metiers d'un TYPE de ressource (le MJ, 3 novembre 2026) : « Minerais »
-- a Mineur. Une ressource qui prend ce type part avec Mineur coche, et le MJ
-- en ajoute ou en retire ensuite dans la forge : ce n'est qu'un defaut.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()
local C = LCM.Compendium

dire("== le type garde ses métiers")
-- Un type temoin : le contenu de la campagne bouge a chaque seance.
local minerais = LCM.Listes.Add({ id = "minerais_temoin", liste = "ressources", label = "Minerais témoin",
    metiers = { "mineur" } })
attendu("Minerais a Mineur", minerais.metiers and minerais.metiers[1], "mineur")
LCM.Listes.Add({ id = "bois_temoin", liste = "ressources", label = "Bois témoin" })
local champ
for _, c in ipairs(C.Champs(C.Get("liste_ressources"))) do if c.cle == "metiers" then champ = c end end
attendu("la Liste ressources a un champ Métiers", champ ~= nil, true)
local ailleurs = false
for _, c in ipairs(C.Champs(C.Get("liste_armes"))) do if c.cle == "metiers" then ailleurs = true end end
attendu("  la Liste armes, non", ailleurs, false)

dire("== le formulaire du type : les métiers se cochent par catégories")
local E = LCM.UI.Compendium.Editeur
E.Ouvrir(C.Get("liste_ressources"), minerais)
local f = E.frame
local ed
for c, editeur in pairs(f.editeurs) do if c.cle == "metiers" then ed = editeur end end
attendu("l'éditeur du champ est là", ed ~= nil, true)
if ed then
    f.deplies[ed.champ] = true
    f:Afficher()
    -- Le champ dit son nom (le MJ, 3 novembre 2026 : « Valeurs (selection
    -- multiple) », seul, obligeait a deviner).
    attendu("le champ dit son nom", (ed.etiquette:GetText() or ""):find("Métiers", 1, true) ~= nil, true)
    attendu("  et à quoi il sert", (ed.etiquette:GetText() or ""):find("par défaut", 1, true) ~= nil, true)
    ed.choisir:Click()
end
local popup = E.coches
attendu("la fenêtre de coches s'ouvre", popup and popup:IsShown(), true)
local deja, bucheron = false, nil
for _, cse in ipairs(popup and popup.cases or {}) do
    if cse:IsShown() and cse.id == "mineur" then deja = cse:EstCochee() end
    if cse:IsShown() and cse.id == "bucheron" then bucheron = cse end
end
attendu("  Mineur y est déjà coché", deja, true)
if bucheron then bucheron:Click() end
if popup then popup.valider:Click() end
local valeur = f.travail and f.travail.e and f.travail.e.metiers
attendu("valider ajoute le Bûcheron", valeur and table.concat(valeur, ","), "bucheron,mineur")
f:Hide()

dire("== la forge : choisir le type coche ses métiers")
local FU = LCM.UI.Forge
LCM.Forge.Add({ id = "jeu_type_metiers", label = "Jeu type métiers", categorie = "ressources",
    raretes = { { id = "commun", label = "Commun", points = 10, couleur = "FF8CB8" } }, champs = {} })
FU.Ouvrir("ressources")
local forge = FU.Fenetre()
FU.courant.jeuId, FU.courant.rareteId = "jeu_type_metiers", "commun"
FU.courant.metiersRecolte = nil
forge:Rafraichir()
local function ChoisirType(id)
    forge.type:Click()
    for _, ligne in ipairs(FU.choixType.lignes or {}) do
        if ligne:IsShown() and ligne.choix == id then ligne:Click() return true end
    end
    return false
end
attendu("le type Minerais se choisit", ChoisirType("minerais_temoin"), true)
attendu("Mineur se coche tout seul", FU.courant.metiersRecolte and table.concat(FU.courant.metiersRecolte, ","), "mineur")
FU.courant.metiersRecolte = { "bucheron" }
forge:Rafraichir()
ChoisirType("minerais_temoin")
attendu("reprendre le même type ne refait pas les coches", table.concat(FU.courant.metiersRecolte, ","), "bucheron")
ChoisirType("bois_temoin")
attendu("un type sans métiers garde ce qui est coché", table.concat(FU.courant.metiersRecolte, ","), "bucheron")
ChoisirType("minerais_temoin")
attendu("revenir au Minerais recoche Mineur", table.concat(FU.courant.metiersRecolte, ","), "mineur")
forge:Hide()

dire("== le transfert vers une liste sans métiers le dit")
-- La « Liste consommable » n'a pas de Métiers : les perdre en silence serait
-- corriger dans le dos du MJ. Un type sans metier, lui, passe sans panneau.
local T = LCM.Transfert or (LCM.UI and LCM.UI.Transfert)
if T and T.Plan then
    local plan = T.Plan({ categorie = "liste_ressources", element = LCM.Listes.Get("minerais_temoin") },
        C.Get("liste_consommables"))
    attendu("un type avec métiers demande la main du MJ",
        plan and plan.etapes[1].raisons[1] and plan.etapes[1].raisons[1]:find("Métiers", 1, true) ~= nil, true)
    plan = T.Plan({ categorie = "liste_ressources", element = LCM.Listes.Get("bois_temoin") },
        C.Get("liste_consommables"))
    attendu("  un type sans métier passe sans panneau",
        plan and plan.question and plan.question:find("Rien à modifier", 1, true) ~= nil, true)
end

LCM.Listes.Retirer("minerais_temoin")
LCM.Listes.Retirer("bois_temoin")
print(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
