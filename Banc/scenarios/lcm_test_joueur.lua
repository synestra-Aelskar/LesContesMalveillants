-- L'addon tel que le voit un joueur : tout ouvrir, sans rien casser.
--
-- A jouer SURTOUT avec --sans-mj : c'est la moitie du produit que personne
-- n'a encore ouverte en jeu. Avec le compagnon, le meme parcours sert de
-- tour du proprietaire cote MJ. Le scenario ne verifie pas ce que montre
-- chaque fenetre (les autres scenarios s'en chargent) : il verifie qu'aucune
-- n'est morte, qu'aucune ne leve d'erreur, et qu'un joueur ne voit rien du MJ.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

-- Les erreurs passent par LCM.Erreur, en rouge dans le chat : on les compte
-- depuis un repere, plutot que de chercher un texte precis.
local ROUGE = "|cffe86b6b"
local function Erreurs(depuis)
    local out = {}
    for i = depuis + 1, #__sorties do
        if __sorties[i]:find(ROUGE, 1, true) then out[#out + 1] = __sansCouleur(__sorties[i]) end
    end
    return out
end

-- Appelle sans laisser une erreur arreter le parcours : elle est rendue.
local function Essayer(fn)
    local repere = #__sorties
    local ok, err = pcall(fn)
    __avancer(1)
    local erreurs = Erreurs(repere)
    if not ok then erreurs[#erreurs + 1] = tostring(err) end
    return table.concat(erreurs, " / ")
end

-- Le repere est pris AVANT la connexion : une erreur a l'ouverture du jeu
-- est la premiere chose que voit un joueur.
local depart = #__sorties
__declencher("PLAYER_LOGIN")
local mj = LCM.IsMaster()
dire(mj and "   (compagnon MJ charge : relancer avec --sans-mj pour le vrai joueur)"
        or "   (sans compagnon : c'est ce que voit un joueur)")
attendu("aucune erreur a la connexion", #Erreurs(depart), 0)

dire("== un personnage")
local P = LCM.Personnages
local reika = P.Creer("Reika", { race = "Humain" })
attendu("cree", reika ~= nil, true)
attendu("il est joue", P.ActifId(), reika and reika.id)

dire("== le menu : chaque entree visible ouvre quelque chose")
local M = LCM.UI.Menu
local function Parcourir(noeuds, chemin)
    for _, noeud in ipairs(M.Visibles(noeuds)) do
        local nom = chemin .. noeud.label
        if noeud.enfants then
            Parcourir(noeud.enfants, nom .. " > ")
        else
            attendu("  " .. nom .. " : branchee", M.EstLiee(noeud.id), true)
            if M.EstLiee(noeud.id) then
                attendu("  " .. nom .. " : sans erreur", Essayer(noeud.onClick), "")
            end
        end
    end
end
Parcourir(nil, "")

dire("== le menu : rien du MJ chez un joueur")
local function CompterMJ(noeuds)
    local n = 0
    for _, noeud in ipairs(M.Visibles(noeuds)) do
        if noeud.mjSeulement then n = n + 1 end
        if noeud.enfants then n = n + CompterMJ(noeud.enfants) end
    end
    return n
end
attendu("entrees reservees visibles", CompterMJ() > 0, mj)

dire("== le lanceur d'actions")
local R = LCM.UI.Radial
attendu("le sceau est la", R.Fenetre():IsShown(), true)
attendu("l'ouvrir", Essayer(R.Basculer), "")
local reservees = 0
for _, categorie in ipairs(R.Categories()) do
    if categorie.mjSeulement then reservees = reservees + 1 end
    for _, entree in ipairs(R.Entrees(categorie.id)) do
        local nom = "  " .. categorie.label .. " > " .. entree.label
        if type(entree.onClick) == "function" then
            attendu(nom .. " : sans erreur", Essayer(entree.onClick), "")
        else
            -- Une entree sans fenetre reste visible, eteinte : le dire suffit.
            dire("   " .. nom .. " : pas encore disponible")
        end
    end
end
attendu("categorie Animation visible", reservees > 0, mj)
attendu("le refermer", Essayer(R.Fermer), "")

dire("== la selection de personnage")
attendu("l'ouvrir", Essayer(function() LCM.UI.Personnages.Ouvrir() end), "")
attendu("ouverte", LCM.UI.Personnages.frame:IsShown(), true)
attendu("sur Reika", LCM.UI.Personnages.frame:Courant().id, reika.id)

dire("== au bout du parcours")
local toutes = Erreurs(depart)
for _, e in ipairs(toutes) do dire("   erreur : " .. e) end
attendu("aucune erreur dans le chat", #toutes, 0)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
