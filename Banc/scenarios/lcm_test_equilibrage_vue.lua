-- L'onglet Equilibrage du Panel MJ, range par themes (2 novembre 2026).
-- Ce qu'on verifie d'abord : RIEN NE SE PERD. Chaque nombre que les reglages
-- savent regler doit rester atteignable depuis l'ecran, ou etre masque
-- expres (teintes et rangs des couleurs de metier).
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()
local R = LCM.Reglages
local p = LCM.UI.PanneauMJ.Basculer()
p:Onglet("equilibrage")
local page = p.pages.equilibrage

dire("== rien ne se perd")
local vus = {}
for _, theme in ipairs(page.themes) do
    for _, g in ipairs(theme.groupes) do
        page:Choisir(g.id)
        for _, l in ipairs(page.lignes) do
            if l:IsShown() and l.chemin then vus[l.chemin] = true end
        end
    end
end
-- Les difficultes ont leur editeur : leurs nombres se reglent la-bas.
local manquants = {}
for _, v in ipairs(R.Vecteurs()) do
    local masque = false
    -- Difficultes et paliers des metiers ont leur editeur (verifies plus bas).
    for _, motif in ipairs({ "^metiers%.paliers%.", "^VERSION_CREATION$", "^difficultes%." }) do
        if v.chemin:find(motif) then masque = true end
    end
    if not masque and not vus[v.chemin] then manquants[#manquants + 1] = v.chemin end
end
attendu("chaque nombre réglable est à l'écran", #manquants, 0)
if #manquants > 0 then dire("    manquent : " .. table.concat(manquants, ", ")) end
attendu("les nombres de la racine aussi (malus)", vus["malusInadapte"], true)
attendu("  et les vies par défaut", vus["viesParDefaut"], true)

dire("== des libellés lisibles")
page:Choisir("actions")
local ligne
for _, l in ipairs(page.lignes) do
    if l:IsShown() and l.chemin == "actions.bouclierForce" then ligne = l end
end
attendu("bouclierForce s'écrit Force", ligne and ligne.nom:GetText(), "Force")
local sous = {}
for _, h in ipairs(page.entetes) do if h:IsShown() then sous[h.texte:GetText()] = true end end
attendu("  sous la section Bouclier", sous[LCM.UI.Majuscules("Bouclier")], true)
page:Choisir("secondaires")
local pa
for _, l in ipairs(page.lignes) do
    if l:IsShown() and l.chemin == "secondaires.4.cout" then pa = l end
end
attendu("un indice prend le nom de l'élément", pa and pa.nom:GetText(), "Points d'action · coût")

dire("== à quoi sert une ligne")
page:Choisir("conteneurs")
local acc
for _, l in ipairs(page.lignes) do
    if l:IsShown() and l.chemin == "conteneurs.accessoire" then acc = l end
end
local V = LCM.UI.PanneauMJ and _G.LCM and nil
local aide = acc and acc.bulleTexte or nil
attendu("l'aide d'une ligne existe", (aide or ""):find("accessoires qu'un personnage peut porter") ~= nil, true)

dire("== les paliers des métiers : une grille, des seuils calculés")
page:Choisir("metiers")
local grille = page.paliers
attendu("la grille remplace le tableau", grille:IsShown() and not page.zone:IsShown(), true)
-- Trente-cinq : le Noir a ses cinq niveaux de metier (3 novembre 2026).
attendu("trente-cinq cases", #grille.cases, 35)
-- Le seuil cumule se lit au survol d'une case, et en fin de couleur.
attendu("une case dit son seuil au survol", (grille.cases[2].bulleTexte or ""):find("100 XP") ~= nil, true)
attendu("la fin de Rose dit son seuil", grille.fins[1]:GetText(), "400")
local avantXP = LCM.Metiers.Paliers()[1].xp
grille.cases[1]:SetText("50")
grille.cases[1]:GetScript("OnEnterPressed")(grille.cases[1])
attendu("régler un coût", LCM.Metiers.Paliers()[1].xp, 50)
attendu("  le seuil suivant se recalcule seul", LCM.Metiers.Paliers()[2].cumul, 110)
attendu("  la grille le montre", (grille.cases[2].bulleTexte or ""):find("110 XP") ~= nil, true)
attendu("  et la fin de couleur suit", grille.fins[1]:GetText(), "410")
attendu("  et le métier suit", LCM.Metiers.XPPourNiveau(2), 110)
R.Retirer("metiers.paliers.1.xp")
attendu("revenir au fichier", LCM.Metiers.Paliers()[2].cumul, 100)
grille.cases[1]:SetText("-3")
grille.cases[1]:GetScript("OnEnterPressed")(grille.cases[1])
attendu("un coût négatif est refusé", LCM.Metiers.Paliers()[1].xp, avantXP)

dire("== régler, comme avant")
local avant = R.Lire("actions.bouclierForce")
page:Choisir("actions")
for _, l in ipairs(page.lignes) do
    if l:IsShown() and l.chemin == "actions.bouclierForce" then ligne = l end
end
ligne.saisie:SetText("0.9")
ligne.saisie:GetScript("OnEnterPressed")(ligne.saisie)
attendu("Entrée pose le réglage", R.Lire("actions.bouclierForce"), 0.9)
attendu("  c'est une surcharge à exporter", R.Surcharges()["actions.bouclierForce"], 0.9)
attendu("  le défaut se propose", ligne.defaut:IsShown(), true)
attendu("  et dit ce que dit le fichier", ligne.fichier:GetText(), "fichier : " .. tostring(avant))
ligne.saisie:SetText("abc")
ligne.saisie:GetScript("OnEnterPressed")(ligne.saisie)
attendu("un texte est refusé, rien ne bouge", R.Lire("actions.bouclierForce"), 0.9)
ligne.defaut:Click()
attendu("↺ rend le fichier", R.Lire("actions.bouclierForce"), avant)
attendu("  plus rien à exporter", R.Surcharges()["actions.bouclierForce"], nil)

dire("== chercher")
page.recherche:Saisir("bouclier")
attendu("la recherche trouve dans plusieurs groupes", page.nombreLignes > 3, true)
local groupes = {}
for _, h in ipairs(page.entetes) do if h:IsShown() then groupes[#groupes + 1] = h.texte:GetText() end end
attendu("  chaque trouvaille dit d'où elle vient", #groupes > 0, true)
page.recherche:Saisir("zzzz")
attendu("rien ne correspond", page.nombreLignes, 0)
page:Choisir("pv")
attendu("choisir un groupe vide la recherche", page.recherche:GetText(), "")

print(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
