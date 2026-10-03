-- La Forge du maitre du jeu : deux fenetres reprises de Necronicon
-- (necronicon/Forge.lua).
--
--   * « Forge d'entrées » (CreateForgeWindow, 600 x 700) : on choisit un jeu
--     et une rarete, on donne un nom, on dose les statistiques au +/-, un
--     compteur dit ce qui est depense sur le pool. « Créer l'entrée » en fait
--     un brouillon, puis ouvre l'editeur du compendium pour le reste
--     (description, icone...).
--   * « Équilibrage de la forge » (CreateForgeBalanceWindow) : l'onglet
--     « Jeu & raretés » (nom, categorie cible, raretes) et l'onglet « Champs »
--     (verrou, min, base, max, cout, par rarete si besoin).
--
-- On y entre par le compendium, pas par une commande : le bouton « Forger »
-- d'une categorie qu'un jeu vise ouvre la forge, et la categorie « Jeux
-- d'équilibrage » liste les jeux (« Nouvelle entree », roue, Dupliquer,
-- Supprimer).
--
-- Ce qui change, et pourquoi :
--   * les regles vivent dans Core/Forge.lua, pas ici : cette fenetre ne fait
--     que saisir. Le refus vient de `Brouillons.Enregistrer`, comme pour
--     l'atelier et l'editeur, et s'affiche tel quel ;
--   * aucune valeur n'est rabotee : une statistique hors bornes reste
--     affichee en rouge, et la creation est refusee avec sa raison ;
--   * l'equilibrage s'edite sur une copie et s'enregistre d'un bouton
--     (« Enregistrer le jeu ») : un jeu est un brouillon verifie, la ou
--     Necronicon ecrivait chaque frappe dans sa sauvegarde ;
--   * deux vues, liste repliable ou tableau en deux colonnes ; pas de blocs
--     deplacables a la souris, pas
--     de boutons « C » de copie de colonne : l'ordre des dossiers est celui
--     de la categorie, fige dans le code ;
--   * pas de liste des jeux dans l'equilibrage : c'est le compendium ;
--   * la saisie en cours de la forge ne survit pas a un /reload : elle n'est
--     le contenu de personne tant qu'elle n'est pas creee.

local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end

local UI = LCM.UI
local C = LCM.Compendium
local Brouillons = MJ.Brouillons

local ForgeUI = {}
MJ.ForgeUI = ForgeUI
UI.Forge = ForgeUI

local function Texte(v) return (tostring(v or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
local function Peindre(fs, c) fs:SetTextColor(c[1], c[2], c[3]) end

local function RVB(hexa)
    local h = Texte(hexa):gsub("^#", "")
    if not h:match("^%x%x%x%x%x%x$") then return 1, 1, 1 end
    return tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255
end

-- Vert au-dessus de la base, rouge en dessous, gris a la base (Necronicon).
local VERT, ROUGE, GRIS = { 0.35, 0.90, 0.45 }, { 1, 0.35, 0.35 }, { 0.62, 0.62, 0.62 }

-- Les raretes d'un jeu neuf : noms et couleurs de Necronicon (DEFAULT_RARITIES).
-- Les pools restent VIDES : c'est au MJ de les fixer, l'enregistrement le
-- refuse tant qu'il ne l'a pas fait. Necronicon proposait 8 a 32 ; on ne
-- recopie pas un bareme que personne n'a decide pour les Contes.
local RARETES_NEUVES = {
    { label = "Commun",     couleur = "FF8CB8" },
    { label = "Inhabituel", couleur = "4DE04D" },
    { label = "Rare",       couleur = "4D8CFF" },
    { label = "Épique",     couleur = "FF9926" },
    { label = "Légendaire", couleur = "FF3838" },
    { label = "Mythique",   couleur = "BF4DFF" },
    { label = "Unique",     couleur = "9999A6" },
}

-- ===== La saisie en cours ==================================================
-- En memoire seulement : jeu, rarete, nom, et les valeurs touchees (une
-- statistique non touchee vaut sa base).

local courant = { valeurs = {}, nom = "" }
ForgeUI.courant = courant

-- Les jeux proposes : ceux de la categorie d'ou l'on a ouvert la forge.
local function Jeux()
    if courant.categorie then return LCM.Forge.PourCategorie(courant.categorie) end
    return LCM.Forge.list
end

local function JeuCourant()
    local jeu = courant.jeuId and LCM.Forge.Get(courant.jeuId)
    if jeu and courant.categorie and jeu.categorie ~= courant.categorie then jeu = nil end
    if not jeu then
        jeu = Jeux()[1]
        courant.jeuId = jeu and jeu.id or nil
        courant.valeurs = {}
    end
    local rarete = jeu and LCM.Forge.Rarete(jeu, courant.rareteId)
    if jeu and not rarete then
        rarete = jeu.raretes[1]
        courant.rareteId = rarete and rarete.id or nil
    end
    return jeu, rarete
end

local function Valeur(jeu, rarete, cle)
    local v = courant.valeurs[cle]
    if v ~= nil then return v end
    return LCM.Forge.Limites(jeu, cle, rarete and rarete.id).base
end

-- Les valeurs d'une entree : une statistique verrouillee vaut sa base, les
-- autres ce qui est saisi. Un zero ne s'ecrit pas (le registre le refuse).
local function Bonus(jeu, rarete)
    local out = {}
    for _, champ in ipairs(LCM.Forge.Statistiques(C.Get(jeu.categorie))) do
        local l = LCM.Forge.Limites(jeu, champ.cle, rarete.id)
        local v = l.verrou and l.base or Valeur(jeu, rarete, champ.cle)
        if v ~= 0 then out[champ.cle] = v end
    end
    return out
end
ForgeUI.Bonus = Bonus

-- La definition de l'entree, prete pour `Brouillons.Enregistrer`.
function ForgeUI.Definition()
    local jeu, rarete = JeuCourant()
    if not jeu then return nil, "aucun jeu d'équilibrage : crée-en un (Équilibrage)" end
    if not rarete then return nil, "ce jeu n'a pas de rareté" end
    local categorie = C.Get(jeu.categorie)
    local nom = Texte(courant.nom)
    if nom == "" then return nil, "donne-lui un nom" end
    local id = Brouillons.Identifiant(nom)
    if id == "" then return nil, "le nom ne donne aucun identifiant (lettres ou chiffres)" end
    local def = { id = id, label = nom, bonus = Bonus(jeu, rarete), forge = LCM.Forge.Valeur(jeu, rarete),
                  -- L'entree prend la couleur et le tag de sa rarete, comme
                  -- dans Necronicon (ForgeCreateEntry).
                  couleurTitre = rarete.couleur, tags = rarete.label, icone = courant.icone }
    for k, v in pairs(categorie.defaut or {}) do
        if def[k] == nil then def[k] = LCM.Copie(v) end
    end
    return def, categorie
end

-- Cree l'entree. Renvoie true et l'element, ou false et la raison.
function ForgeUI.Creer()
    local def, categorie = ForgeUI.Definition()
    if not def then return false, categorie end
    local ok, refus = Brouillons.Enregistrer(categorie.famille, def, true)
    if not ok then return false, refus end
    local registre = Brouillons.Registre(categorie.famille)
    courant.valeurs, courant.nom, courant.icone = {}, "", nil
    return true, registre and registre.Get(def.id), categorie
end

-- ===== Fenetre de creation =================================================

local LARGEUR, HAUTEUR = 600, 700
local LIGNE = 24
local FORGE_COLONNE, FORGE_ECART = 450, 16

-- Memes accents dans les deux vues ; resistances et penetrations reprennent
-- leur couleur dans la fiche du personnage.
local COULEURS = {
    ["Statistiques"] = { 0.94, 0.79, 0.46 },
    ["Résistances"] = { 0.44, 0.78, 0.94 },
    ["Pénétrations"] = { 1, 0.48, 0.38 },
    ["Bonus"] = { 0.72, 0.85, 0.48 },
    ["Observations"] = { 0.47, 0.83, 0.77 },
    ["Athlétismes"] = { 0.83, 0.66, 0.42 },
    ["Filouteries"] = { 0.72, 0.59, 0.90 },
    ["Attaques & Défense"] = { 0.93, 0.58, 0.43 },
    ["Bouclier et Soin"] = { 0.49, 0.85, 0.69 },
    ["Buff"] = { 0.60, 0.83, 0.95 },
    ["Debuff"] = { 0.82, 0.53, 0.75 },
    ["Perce-Armure"] = { 0.95, 0.66, 0.46 },
    ["Brise-Armure"] = { 0.86, 0.54, 0.39 },
    ["Provocation"] = { 0.92, 0.71, 0.42 },
    ["Intimidation"] = { 0.77, 0.57, 0.83 },
    ["Saignement"] = { 0.93, 0.43, 0.49 },
    ["Empoisonnement"] = { 0.62, 0.79, 0.38 },
    ["Mécanique de compétence"] = { 0.58, 0.68, 0.94 },
    ["Autres"] = { 0.75, 0.72, 0.65 },
}
local function CouleurDossier(nom) return COULEURS[nom] or UI.C.titre end
local function TeinterDossier(cadre, nom)
    local couleur = CouleurDossier(nom)
    cadre.label:SetTextColor(couleur[1], couleur[2], couleur[3])
    if not cadre.filetCategorie then
        cadre.filetCategorie = UI.Aplat(cadre, couleur, "OVERLAY")
        cadre.filetCategorie:SetPoint("BOTTOMLEFT", cadre, "BOTTOMLEFT", 8, 1)
        cadre.filetCategorie:SetPoint("BOTTOMRIGHT", cadre, "BOTTOMRIGHT", -8, 1)
        cadre.filetCategorie:SetHeight(1)
    end
    cadre.filetCategorie:SetColorTexture(couleur[1], couleur[2], couleur[3], 0.7)
end



local function Construire()
    local f = UI.Fenetre("forge", "Forge d'entrées", LARGEUR, HAUTEUR, { x = -120, y = 0 }, { enTeteSimple = true })
    ForgeUI.frame = f
    f.fond:SetColorTexture(0.045, 0.038, 0.03, 0.985)
    f.vue = "liste"
    local c = f.contenu
    f.choix = UI.Choix("forge", "")

    local function Libelle(texte, x, y)
        local t = UI.Texte(c, texte, UI.C.libelle, "GameFontNormalSmall")
        t:SetPoint("TOPLEFT", c, "TOPLEFT", x, y)
        return t
    end

    Libelle("Jeu d'équilibrage", 2, -8)
    f.jeu = UI.Bouton(c, "", 276, 22, function(b)
        local options = {}
        for _, jeu in ipairs(Jeux()) do
            local categorie = C.Get(jeu.categorie)
            options[#options + 1] = { id = jeu.id, label = jeu.label, groupe = categorie and categorie.label }
        end
        if #options == 0 then
            f:Statut("Aucun jeu : crée-en un dans la catégorie « Jeux d'équilibrage » du compendium.", UI.C.plein)
            return
        end
        f.choix.titre:SetText("Jeu d'équilibrage")
        f.choix:Proposer(b, options, function(id)
            if courant.jeuId ~= id then courant.jeuId, courant.rareteId, courant.valeurs = id, nil, {} end
            f:Rafraichir()
        end)
    end)
    f.jeu:SetPoint("TOPLEFT", c, "TOPLEFT", 2, -24)

    Libelle("Rareté", 292, -8)
    f.rarete = UI.Bouton(c, "", 160, 22, function(b)
        local jeu = JeuCourant()
        if not jeu then return end
        local options = {}
        for _, r in ipairs(jeu.raretes) do
            options[#options + 1] = { id = r.id, label = string.format("%s (%d pts)", r.label, r.points) }
        end
        f.choix.titre:SetText("Rareté")
        -- On ne reborne rien en changeant de rarete : ce qui sort des bornes
        -- de la nouvelle passe au rouge, c'est au MJ d'ajuster.
        f.choix:Proposer(b, options, function(id) courant.rareteId = id f:Rafraichir() end)
    end)
    f.rarete:SetPoint("TOPLEFT", c, "TOPLEFT", 292, -24)
    for _, bouton in ipairs({ f.jeu, f.rarete }) do
        bouton.label:ClearAllPoints()
        bouton.label:SetPoint("LEFT", bouton, "LEFT", 10, 0)
        bouton.label:SetPoint("RIGHT", bouton, "RIGHT", -26, 0)
        bouton.label:SetJustifyH("LEFT")
        bouton.fleche = bouton:CreateTexture(nil, "OVERLAY")
        bouton.fleche:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
        bouton.fleche:SetSize(18, 18)
        bouton.fleche:SetPoint("RIGHT", bouton, "RIGHT", -4, 0)
    end

    f.equilibrage = UI.Bouton(c, "Équilibrage", 108, 22, function()
        local jeu = JeuCourant()
        if jeu then ForgeUI.Editer(jeu) end
    end)
    f.equilibrage:SetPoint("TOPLEFT", c, "TOPLEFT", 464, -24)

    Libelle("Nom de l'entrée", 46, -56)
    f.selecteurIcone = UI.SelecteurIcone("forge_entree")
    f.icone = UI.Bouton(c, "", 36, 36, function(b)
        f.selecteurIcone:Proposer(b, function(chemin)
            courant.icone = chemin
            f:Rafraichir()
        end)
    end)
    f.icone:SetPoint("TOPLEFT", c, "TOPLEFT", 2, -57)
    f.icone.texture = f.icone:CreateTexture(nil, "ARTWORK")
    f.icone.texture:SetPoint("TOPLEFT", f.icone, "TOPLEFT", 3, -3)
    f.icone.texture:SetPoint("BOTTOMRIGHT", f.icone, "BOTTOMRIGHT", -3, 3)
    if UI.AelCadre then f.icone.cadre = UI.AelCadre(f.icone, "icone") end
    UI.Bulle(f.icone, "Icône de l'entrée", "Cliquer pour choisir une icône.")
    f.nom = UI.Champ(c, 570, 22, function(texte) courant.nom = texte end)
    f.nom:SetMaxLetters(80)
    f.nom:SetPoint("TOPLEFT", c, "TOPLEFT", 46, -72)
    f.nom:SetPoint("TOPRIGHT", c, "TOPRIGHT", -2, -72)

    -- Le compteur : points depenses sur le pool de la rarete.
    local k = CreateFrame("Frame", nil, c)
    k:SetPoint("TOPLEFT", c, "TOPLEFT", 2, -104)
    k:SetPoint("TOPRIGHT", c, "TOPRIGHT", -2, -104)
    k:SetHeight(50)
    k.fond = UI.Aplat(k, { 0, 0, 0, 0.35 })
    k.fond:SetAllPoints(k)
    UI.BordureFine(k, 0.3)
    if UI.AelCadre then k.cadre = UI.AelCadre(k, "section") end
    k.barre = k:CreateTexture(nil, "ARTWORK")
    k.barre:SetPoint("TOPLEFT", k, "TOPLEFT", 1, -1)
    k.barre:SetPoint("BOTTOMLEFT", k, "BOTTOMLEFT", 1, 1)
    k.barre:SetWidth(1)
    k.points = UI.Texte(k, "", UI.C.titre, "GameFontNormalLarge")
    k.points:SetPoint("LEFT", k, "LEFT", 14, 8)
    k.palier = UI.Texte(k, "", UI.C.discret, "GameFontNormalSmall")
    k.palier:SetPoint("LEFT", k, "LEFT", 14, -12)
    k.pool = UI.Texte(k, "", UI.C.discret, "GameFontNormalSmall")
    k.pool:SetPoint("RIGHT", k, "RIGHT", -12, 0)
    f.compteur = k
    f.mode = UI.Onglets(c, { { id = "liste", label = "Liste" }, { id = "tableau", label = "Tableau" } },
        function(id)
            f.vue = id
            f.zone:Aller(0)
            f:Rafraichir()
        end, { largeur = 100, hauteur = 22 })
    f.mode:SetPoint("TOPLEFT", c, "TOPLEFT", 2, -164)
    f.mode:SetWidth(204)
    f.aideVue = UI.Texte(c, "", UI.C.discret, "GameFontNormalSmall")
    f.aideVue:SetPoint("TOPRIGHT", c, "TOPRIGHT", -4, -170)

    f.zone = UI.Defilement(c)
    f.zone:SetPoint("TOPLEFT", c, "TOPLEFT", 2, -198)
    f.zone:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -14, 60)
    f.vide = UI.Texte(f.zone.contenu, "", UI.C.discret, "GameFontNormal")
    f.vide:SetPoint("TOPLEFT", f.zone.contenu, "TOPLEFT", 10, -30)
    f.vide:SetPoint("TOPRIGHT", f.zone.contenu, "TOPRIGHT", -10, -30)
    f.vide:SetJustifyH("CENTER")
    f.vide:SetWordWrap(true)

    f.statut = UI.Texte(c, "", UI.C.discret, "GameFontNormalSmall")
    f.statut:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 2, 32)
    f.statut:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -2, 32)
    f.statut:SetJustifyH("LEFT")
    f.statut:SetWordWrap(true)

    f.reinitialiser = UI.Bouton(c, "Réinitialiser", 120, 24, function()
        courant.valeurs = {}
        f:Rafraichir()
        f:Statut("Valeurs remises à la base.")
    end)
    f.reinitialiser:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 2, 0)
    f.creer = UI.Bouton(c, "Créer l'entrée", 170, 24, function() f:Creer() end)
    f.creer:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -2, 0)

    f.dossiers, f.lignes, f.ouverts = {}, {}, {}

    function f:Statut(texte, couleur)
        self.statut:SetText(texte or "")
        Peindre(self.statut, couleur or UI.C.discret)
    end

    -- Une ligne de statistique : creee une fois, reutilisee ensuite.
    function f:Ligne(index)
        local l = self.lignes[index]
        if l then return l end
        l = CreateFrame("Frame", nil, self.zone.contenu)
        l:SetHeight(LIGNE - 2)
        l.fond = UI.Aplat(l, { 1, 1, 1, 0.04 })
        l.fond:SetAllPoints(l)
        l.label = UI.Texte(l, "", UI.C.texte, "GameFontNormalSmall")
        l.label:SetPoint("LEFT", l, "LEFT", 8, 0)
        l.label:SetWidth(166)
        UI.Police(l.label, 11)
        l.label:SetJustifyH("LEFT")
        l.label:SetWordWrap(false)
        l.moins = UI.Bouton(l, "-", 18, 19, function(b) f:Changer(b:GetParent().cle, -1) end)
        l.moins:SetPoint("LEFT", l.label, "RIGHT", 6, 0)
        l.valeur = UI.Champ(l, 40, 19)
        l.valeur:SetJustifyH("CENTER")
        l.valeur:SetPoint("LEFT", l.moins, "RIGHT", 4, 0)
        l.valeur:SetScript("OnEnterPressed", function(e)
            e:ClearFocus()
            f:Fixer(e:GetParent().cle, e:GetText())
        end)
        l.valeur:SetScript("OnEscapePressed", function(e) e:ClearFocus() f:Rafraichir() end)
        l.plus = UI.Bouton(l, "+", 18, 19, function(b) f:Changer(b:GetParent().cle, 1) end)
        l.plus:SetPoint("LEFT", l.valeur, "RIGHT", 4, 0)
        l.limites = UI.Texte(l, "", UI.C.discret, "GameFontNormalSmall")
        l.limites:SetPoint("LEFT", l.plus, "RIGHT", 8, 0)
        l.limites:SetWidth(76)
        l.limites:SetJustifyH("LEFT")
        l.limites:SetWordWrap(false)
        l.cout = UI.Texte(l, "", UI.C.discret, "GameFontNormalSmall")
        l.cout:SetPoint("RIGHT", l, "RIGHT", -6, 0)
        l.cout:SetWidth(60)
        l.cout:SetJustifyH("RIGHT")
        self.lignes[index] = l
        return l
    end

    -- Un en-tete de dossier, qui ouvre et ferme son bloc.
    function f:Dossier(index)
        local b = self.dossiers[index]
        if b then return b end
        b = UI.Bouton(self.zone.contenu, "", 10, 24, function(bouton)
            if f.vue == "tableau" then return end
            local nom = bouton.dossier
            local ouvert = f.ouverts[nom]
            if ouvert == nil then ouvert = bouton.premier end
            f.ouverts[nom] = not ouvert
            f:Rafraichir()
        end)
        b.label:ClearAllPoints()
        b.label:SetPoint("LEFT", b, "LEFT", 8, 0)
        b.label:SetJustifyH("LEFT")
        UI.Police(b.label, 11)
        b.carte = CreateFrame("Frame", nil, b)
        b.carte:SetPoint("TOPLEFT", b, "TOPLEFT", -3, 3)
        b.carte:EnableMouse(false)
        if UI.AelCadre then b.carte.cadre = UI.AelCadre(b.carte, "section") end
        if UI.AelRef then
            b.gemme = UI.AelRef(b, 501, 656, 27, 25, "OVERLAY")
            b.gemme:SetSize(8, 8)
            b.gemme:SetPoint("TOP", b, "TOP", 0, 7)
        end
        self.dossiers[index] = b
        return b
    end

    function f:Changer(cle, pas)
        local jeu, rarete = JeuCourant()
        if not jeu then return end
        courant.valeurs[cle] = Valeur(jeu, rarete, cle) + pas
        self:Rafraichir()
    end

    -- Une saisie illisible n'est pas remplacee par zero : elle est refusee,
    -- et la case reprend la valeur d'avant.
    function f:Fixer(cle, texte)
        local n = tonumber(texte)
        if not n or n ~= math.floor(n) then
            self:Statut(string.format("« %s » n'est pas un nombre entier.", tostring(texte)), UI.C.plein)
            self:Rafraichir()
            return
        end
        courant.valeurs[cle] = n
        self:Rafraichir()
    end

    function f:Compteur(jeu, rarete, bilan)
        local k = self.compteur
        if not rarete then
            k.points:SetText(C.Nombre(bilan and bilan.total or 0) .. " pts")
            Peindre(k.points, UI.C.texte)
            k.palier:SetText("Aucune rareté")
            k.pool:SetText("")
            k.barre:SetWidth(1)
            return
        end
        local total = bilan.total
        local depasse = total > rarete.points
        local r, g, b = RVB(rarete.couleur)
        k.points:SetText(C.Nombre(total) .. " pts")
        if depasse then Peindre(k.points, ROUGE) else k.points:SetTextColor(r, g, b) end
        local suffit = LCM.Forge.RareteSuffisante(jeu, total)
        if depasse then
            k.palier:SetText("Dépasse le pool de " .. rarete.label)
        elseif suffit and suffit.id ~= rarete.id then
            k.palier:SetText("Rentrerait déjà en " .. suffit.label)
        else
            k.palier:SetText("Rareté " .. rarete.label)
        end
        k.pool:SetText(string.format("/ %d pts", rarete.points))
        local part = rarete.points > 0 and math.min(1, math.max(0, total / rarete.points)) or (total > 0 and 1 or 0)
        k.barre:SetWidth(math.max(1, ((k:GetWidth() or (LARGEUR - 28)) - 2) * part))
        if depasse then k.barre:SetColorTexture(1, 0.2, 0.2, 0.22) else k.barre:SetColorTexture(r, g, b, 0.18) end
    end

    function f:Rafraichir()
        local jeu, rarete = JeuCourant()
        local tableau = self.vue == "tableau"
        local colonnes = tableau and math.max(1, math.min(2,
            math.floor((UIParent:GetWidth() * 0.9 - 40) / (FORGE_COLONNE + FORGE_ECART)))) or 1
        self:SetSize(tableau and (40 + colonnes * (FORGE_COLONNE + FORGE_ECART)) or LARGEUR,
            math.min(HAUTEUR, UIParent:GetHeight() * 0.88))
        self.mode:Selectionner(self.vue)
        self.aideVue:SetText(tableau and "Toutes les catégories" or "Catégories repliables")
        self.jeu.label:SetText(jeu and jeu.label or "Aucun jeu")
        self.rarete.label:SetText(rarete and rarete.label or "—")
        self.icone.texture:SetTexture(LCM.Icone(courant.icone))
        if not self.nom:HasFocus() then self.nom:SetText(courant.nom or "") end

        local bilan = jeu and rarete and LCM.Forge.Bilan(jeu, rarete.id, (function()
            local v = {}
            for _, champ in ipairs(LCM.Forge.Statistiques(C.Get(jeu.categorie))) do
                v[champ.cle] = Valeur(jeu, rarete, champ.cle)
            end
            return v
        end)()) or nil
        self:Compteur(jeu, rarete, bilan)

        -- Les statistiques ouvertes a l'investissement, par dossier. Les
        -- verrouillees n'apparaissent pas (Necronicon) : elles valent leur base.
        local dossiers, parDossier = {}, {}
        for _, ligne in ipairs(bilan and bilan.lignes or {}) do
            if not ligne.limites.verrou then
                local nom = ligne.champ.dossier or "Général"
                if not parDossier[nom] then
                    parDossier[nom] = {}
                    dossiers[#dossiers + 1] = nom
                end
                table.insert(parDossier[nom], ligne)
            end
        end
        if not jeu then
            self.vide:SetText("Aucun jeu d'équilibrage : crée-en un dans la catégorie « Jeux d'équilibrage » du compendium.")
        elseif not rarete then
            self.vide:SetText("Ce jeu n'a aucune rareté.")
        else
            self.vide:SetText("Toutes les statistiques de ce jeu sont verrouillées.")
        end
        self.vide:SetShown(#dossiers == 0)

        local largeur = tableau and FORGE_COLONNE or math.max(400, self.zone:GetWidth() or (LARGEUR - 40))
        local y, nLignes = 6, 0
        local hauteurs = { 6, 6 }
        for index, nom in ipairs(dossiers) do
            local liste = parDossier[nom]
            local ouvert = self.ouverts[nom]
            if ouvert == nil then ouvert = index == 1 end
            if tableau then ouvert = true end
            local colonne = 1
            if colonnes == 2 and hauteurs[2] < hauteurs[1] then colonne = 2 end
            y = hauteurs[colonne]
            local x = (colonne - 1) * (FORGE_COLONNE + FORGE_ECART)
            local debut = y
            local depense = 0
            for _, ligne in ipairs(liste) do depense = depense + ligne.depense end
            local b = self:Dossier(index)
            b.dossier, b.premier = nom, index == 1
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", self.zone.contenu, "TOPLEFT", x + 4, -y)
            b:SetWidth(largeur - 4)
            b.label:SetText(string.format("%s %s  |cff888888(%d)|r%s", tableau and "" or (ouvert and "v" or ">"), nom, #liste,
                depense ~= 0 and string.format("   |cffffd200%s pts|r", C.Nombre(depense)) or ""))
            TeinterDossier(b, nom)
            b:Show()
            y = y + 26
            if ouvert then
                for _, ligne in ipairs(liste) do
                    nLignes = nLignes + 1
                    local l = self:Ligne(nLignes)
                    l.cle = ligne.champ.cle
                    l:ClearAllPoints()
                    l:SetPoint("TOPLEFT", self.zone.contenu, "TOPLEFT", x + 8, -y)
                    l:SetWidth(largeur - 12)
                    l.label:SetText(ligne.champ.label)
                    self:PeindreLigne(l, ligne, nLignes)
                    l:Show()
                    y = y + LIGNE
                end
            end
            b.carte:SetWidth(largeur + 2)
            b.carte:SetHeight(y - debut + 4)
            hauteurs[colonne] = y + 14
        end
        for index = #dossiers + 1, #self.dossiers do self.dossiers[index]:Hide() end
        for index = nLignes + 1, #self.lignes do self.lignes[index]:Hide() end
        self.zone:Regler(math.max(hauteurs[1], colonnes == 2 and hauteurs[2] or 0))
    end

    function f:PeindreLigne(l, ligne, index)
        local v, base = ligne.valeur, ligne.limites.base
        if not l.valeur:HasFocus() then l.valeur:SetText(C.Nombre(v)) end
        Peindre(l.valeur, v > base and VERT or (v < base and ROUGE or GRIS))
        local morceaux = { "base " .. C.Nombre(base) }
        if ligne.limites.min then morceaux[#morceaux + 1] = "min " .. C.Nombre(ligne.limites.min) end
        if ligne.limites.max then morceaux[#morceaux + 1] = "max " .. C.Nombre(ligne.limites.max) end
        l.limites:SetText(table.concat(morceaux, "  "))
        UI.Bulle(l, ligne.champ.label, table.concat(morceaux, "\n") .. "\nCoût : " .. C.Nombre(ligne.limites.cout) .. " / pt")
        -- Hors bornes : la valeur reste, la ligne le dit.
        Peindre(l.limites, ligne.hors and UI.C.plein or UI.C.discret)
        l.hors = ligne.hors
        if ligne.hors then
            l.fond:SetColorTexture(0.9, 0.2, 0.2, 0.14)
        else
            local couleur = CouleurDossier(ligne.champ.dossier)
            l.fond:SetColorTexture(couleur[1], couleur[2], couleur[3], index % 2 == 0 and 0.035 or 0.065)
        end
        if ligne.depense ~= 0 then
            l.cout:SetText(C.Nombre(ligne.depense) .. " pts")
            Peindre(l.cout, ligne.depense < 0 and VERT or { 1, 0.82, 0 })
        else
            l.cout:SetText(C.Nombre(ligne.limites.cout) .. " / pt")
            Peindre(l.cout, GRIS)
        end
    end

    function f:Creer()
        local ok, element, categorie = ForgeUI.Creer()
        if not ok then
            self:Statut("Refusé : " .. tostring(element), UI.C.plein)
            return
        end
        self:Statut(string.format("Brouillon « %s » créé : complète-le dans l'éditeur.", element.label), UI.C.accent)
        LCM.Ok(string.format("brouillon forge : %s (%s)", element.label, categorie.label))
        self:Rafraichir()
        if UI.Compendium and UI.Compendium.Actualiser then UI.Compendium.Actualiser() end
        if LCM.CompendiumEditeur then LCM.CompendiumEditeur.Ouvrir(categorie, element) end
    end

    f:HookScript("OnShow", function() f:Rafraichir() end)
    return f
end

function ForgeUI.Fenetre()
    return ForgeUI.frame or Construire()
end

-- Le bouton « Forger » du compendium : la forge, sur les jeux de cette
-- categorie. false et la raison s'il n'y en a aucun.
function ForgeUI.Ouvrir(categorieId)
    local categorie = C.Get(categorieId)
    if not categorie then return false, "catégorie inconnue" end
    if #LCM.Forge.PourCategorie(categorie.id) == 0 then
        return false, string.format("aucun jeu d'équilibrage ne vise %s : crée-en un dans la catégorie "
            .. "« Jeux d'équilibrage »", categorie.label)
    end
    if courant.categorie ~= categorie.id then
        courant.categorie, courant.jeuId, courant.rareteId, courant.valeurs = categorie.id, nil, nil, {}
    end
    local f = ForgeUI.Fenetre()
    if f:IsShown() then f:Rafraichir() else f:Show() end
    UI.Devant(f)
    return true
end

-- Apres l'enregistrement d'un jeu : la forge ouverte suit.
function ForgeUI.Actualiser()
    local f = ForgeUI.frame
    if f and f:IsShown() then f:Rafraichir() end
end

-- ===== Equilibrage : la copie de travail d'un jeu ==========================
-- Rien n'est ecrit tant que le MJ n'enregistre pas. Les nombres restent tels
-- qu'ils ont ete tapes : c'est le registre qui les lit, et qui refuse.

local travaux = {}

local function Travail(id)
    if travaux[id] then return travaux[id] end
    local jeu = LCM.Forge.Get(id)
    local def = LCM.Copie(jeu)
    def.brouillon = nil
    local t = { id = id, def = def, creation = false, publie = Brouillons.EstPublie("jeux", id) }
    travaux[id] = t
    return t
end

local nouveaux = 0
local function Nouveau()
    nouveaux = nouveaux + 1
    local raretes = {}
    for _, r in ipairs(RARETES_NEUVES) do
        raretes[#raretes + 1] = { id = Brouillons.Identifiant(r.label), label = r.label, points = "", couleur = r.couleur }
    end
    local cle = "__nouveau_" .. nouveaux
    local t = { id = cle, creation = true, publie = false,
                def = { label = "Jeu " .. tostring(#LCM.Forge.list + nouveaux), raretes = raretes, champs = {} } }
    travaux[cle] = t
    return t
end

-- Le reglage d'une statistique dans la copie, cree a l'ecriture seulement.
local function Reglage(t, cle, rareteId, pourEcrire)
    local champs = t.def.champs
    if not champs[cle] then
        if not pourEcrire then return nil end
        champs[cle] = {}
    end
    local r = champs[cle]
    if not rareteId then return r end
    if not (r.raretes and r.raretes[rareteId]) then
        if not pourEcrire then return nil end
        r.raretes = r.raretes or {}
        r.raretes[rareteId] = {}
    end
    return r.raretes[rareteId]
end

-- Une valeur effacee ne laisse pas de table vide derriere elle.
local function Nettoyer(t, cle)
    local r = t.def.champs[cle]
    if not r then return end
    for rid, sur in pairs(r.raretes or {}) do
        if next(sur) == nil then r.raretes[rid] = nil end
    end
    if r.raretes and next(r.raretes) == nil then r.raretes = nil end
    if next(r) == nil then t.def.champs[cle] = nil end
end

local function Ecrire(t, cle, rareteId, nom, valeur)
    t.modifie = true
    if valeur == "" then valeur = nil end
    if valeur == nil and not Reglage(t, cle, rareteId, false) then return end
    Reglage(t, cle, rareteId, true)[nom] = valeur
    Nettoyer(t, cle)
end
ForgeUI.Ecrire = Ecrire

-- Enregistre la copie. true, ou false et la raison.
function ForgeUI.EnregistrerJeu(t)
    local def = LCM.Copie(t.def)
    def.label = Texte(def.label)
    if def.label == "" then return false, "donne un nom au jeu" end
    if t.creation then def.id = Brouillons.Identifiant(def.label) end
    if Texte(def.id) == "" then return false, "le nom ne donne aucun identifiant (lettres ou chiffres)" end
    local ok, refus = Brouillons.Enregistrer("jeux", def, t.creation, t.publie)
    if not ok then return false, refus end
    -- La copie est rendue : la prochaine ouverture repart de l'enregistre.
    travaux[t.id] = nil
    return true, def.id
end

-- ===== Fenetre d'equilibrage ===============================================
-- Un jeu a la fois. La liste des jeux, c'est le compendium (categorie « Jeux
-- d'equilibrage ») : « Nouvelle entree » et la roue d'une ligne ouvrent ici,
-- Dupliquer et Supprimer y restent. Necronicon avait sa propre liste a
-- gauche ; elle ferait doublon.

local EQ_LARGEUR, EQ_HAUTEUR = 560, 640

local function ConstruireEquilibrage()
    local f = UI.Fenetre("forge_equilibrage", "Équilibrage de la forge", EQ_LARGEUR, EQ_HAUTEUR,
        { x = 200, y = 0 }, { enTeteSimple = true })
    ForgeUI.equilibrage = f
    f.fond:SetColorTexture(0.045, 0.038, 0.03, 0.985)
    local c = f.contenu
    f.choix = UI.Choix("forge_equilibrage", "")
    f.onglet = "jeu"

    f.onglets = UI.Onglets(c, { { id = "jeu", label = "Jeu & raretés" },
                                { id = "champs", label = "Champs : verrou, limites, coûts" } },
        function(id) f.onglet = id f:Rafraichir() end, { largeur = 230, hauteur = 24 })
    f.onglets:SetPoint("TOPLEFT", c, "TOPLEFT", 2, -8)
    f.onglets:SetPoint("TOPRIGHT", c, "TOPRIGHT", -2, -8)

    f.zone = UI.Defilement(c)
    f.zone:SetPoint("TOPLEFT", c, "TOPLEFT", 2, -42)
    f.zone:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -14, 58)
    local z = f.zone.contenu

    f.statut = UI.Texte(c, "", UI.C.discret, "GameFontNormalSmall")
    f.statut:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 2, 30)
    f.statut:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -2, 30)
    f.statut:SetJustifyH("LEFT")
    f.statut:SetWordWrap(true)
    f.enregistrer = UI.Bouton(c, "Enregistrer le jeu", 170, 24, function() f:Enregistrer() end)
    f.enregistrer:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -2, 0)
    f.etat = UI.Texte(c, "", UI.C.discret, "GameFontNormalSmall")
    f.etat:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 2, 6)

    function f:Statut(texte, couleur)
        self.statut:SetText(texte or "")
        Peindre(self.statut, couleur or UI.C.discret)
    end

    local function Libelle(parent, texte, x, y, couleur)
        local t = UI.Texte(parent, texte, couleur or UI.C.libelle, "GameFontNormalSmall")
        t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        return t
    end

    function f:Travail()
        return self.selection and (travaux[self.selection] or (LCM.Forge.Get(self.selection) and Travail(self.selection)))
    end

    -- La premiere modification se voit dans l'etat, en bas.
    local function Touche()
        local t = f:Travail()
        if t and not t.modifie then t.modifie = true f:Etat(t) end
    end

    -- ----- Onglet « Jeu & raretés » -----------------------------------------
    local pj = CreateFrame("Frame", nil, z)
    pj:SetPoint("TOPLEFT", z, "TOPLEFT", 0, 0)
    pj:SetPoint("TOPRIGHT", z, "TOPRIGHT", 0, 0)
    pj:SetHeight(1)
    f.pageJeu = pj
    Libelle(pj, "Nom du jeu", 4, -4)
    pj.nom = UI.Champ(pj, 300, 22, function(texte)
        local t = f:Travail()
        if t then t.def.label = texte Touche() end
    end)
    pj.nom:SetMaxLetters(60)
    pj.nom:SetPoint("TOPLEFT", pj, "TOPLEFT", 4, -20)
    Libelle(pj, "Catégorie cible", 4, -52)
    pj.categorie = UI.Bouton(pj, "", 300, 22, function(b)
        local t = f:Travail()
        if not t then return end
        local options = {}
        for _, categorie in ipairs(C.categories) do
            if categorie.statistiques == "bonus" and categorie.famille then
                options[#options + 1] = { id = categorie.id, label = categorie.label }
            end
        end
        f.choix.titre:SetText("Catégorie cible")
        f.choix:Proposer(b, options, function(id)
            -- Changer de categorie rend caducs les reglages de statistiques.
            if t.def.categorie ~= id then t.def.champs = {} end
            t.def.categorie = id
            Touche()
            f:Rafraichir()
        end)
    end)
    pj.categorie:SetPoint("TOPLEFT", pj, "TOPLEFT", 4, -68)
    pj.titreRaretes = UI.Texte(pj, "Raretés : pool de points et couleur", UI.C.titre, "GameFontNormal")
    pj.titreRaretes:SetPoint("TOPLEFT", pj, "TOPLEFT", 4, -106)
    pj.aide = UI.Texte(pj, "Nom  ·  points  ·  couleur (RRVVBB). L'entrée forgée prend la couleur et le tag de sa rareté.",
        UI.C.discret, "GameFontNormalSmall")
    pj.aide:SetPoint("TOPLEFT", pj.titreRaretes, "BOTTOMLEFT", 0, -3)
    pj.ajouter = UI.Bouton(pj, "+ Rareté", 130, 20, function()
        local t = f:Travail()
        if not t then return end
        local n = #t.def.raretes + 1
        local nom = "Rareté " .. n
        local id, suffixe = Brouillons.Identifiant(nom), 1
        local pris = {}
        for _, r in ipairs(t.def.raretes) do pris[r.id] = true end
        while pris[id] do suffixe = suffixe + 1 id = Brouillons.Identifiant(nom) .. "_" .. suffixe end
        t.def.raretes[n] = { id = id, label = nom, points = "", couleur = "F2E6C6" }
        Touche()
        f:Rafraichir()
    end)
    pj.ajouter:SetPoint("TOPLEFT", pj, "TOPLEFT", 4, -142)
    pj.lignes = {}

    function f:LigneRarete(index)
        local l = pj.lignes[index]
        if l then return l end
        l = CreateFrame("Frame", nil, pj)
        l:SetSize(480, 24)
        l.nom = UI.Champ(l, 170, 20, function(texte) if l.rarete then l.rarete.label = texte Touche() end end)
        l.nom:SetPoint("LEFT", l, "LEFT", 4, 0)
        l.points = UI.Champ(l, 60, 20, function(texte) if l.rarete then l.rarete.points = texte Touche() end end)
        l.points:SetPoint("LEFT", l.nom, "RIGHT", 8, 0)
        l.couleur = UI.Champ(l, 80, 20, function(texte)
            if not l.rarete then return end
            l.rarete.couleur = texte
            Touche()
            l.pastille:SetColorTexture(RVB(texte))
        end)
        l.couleur:SetPoint("LEFT", l.points, "RIGHT", 8, 0)
        l.pastille = l:CreateTexture(nil, "ARTWORK")
        l.pastille:SetSize(18, 18)
        l.pastille:SetPoint("LEFT", l.couleur, "RIGHT", 6, 0)
        l.retirer = UI.Bouton(l, "Retirer", 60, 20, function()
            local t = f:Travail()
            if not t or #t.def.raretes <= 1 then
                f:Statut("Un jeu garde au moins une rareté.", UI.C.plein)
                return
            end
            for i, r in ipairs(t.def.raretes) do
                if r == l.rarete then table.remove(t.def.raretes, i) break end
            end
            -- Ce qu'elle precisait par statistique part avec elle.
            for cle, r in pairs(t.def.champs) do
                if r.raretes then r.raretes[l.rarete.id] = nil end
                Nettoyer(t, cle)
            end
            Touche()
            f:Rafraichir()
        end)
        l.retirer:SetPoint("LEFT", l.pastille, "RIGHT", 10, 0)
        pj.lignes[index] = l
        return l
    end

    function f:PageJeu(t)
        if not pj.nom:HasFocus() then pj.nom:SetText(t.def.label or "") end
        local categorie = C.Get(t.def.categorie)
        pj.categorie.label:SetText(categorie and categorie.label or "Choisir une catégorie...")
        local y = 168
        for index, r in ipairs(t.def.raretes) do
            local l = self:LigneRarete(index)
            l.rarete = r
            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", pj, "TOPLEFT", 0, -y)
            if not l.nom:HasFocus() then l.nom:SetText(r.label or "") end
            if not l.points:HasFocus() then l.points:SetText(tostring(r.points or "")) end
            if not l.couleur:HasFocus() then l.couleur:SetText(r.couleur or "") end
            l.pastille:SetColorTexture(RVB(r.couleur))
            l:Show()
            y = y + 26
        end
        for index = #t.def.raretes + 1, #pj.lignes do pj.lignes[index]:Hide() end
        return y + 10
    end

    -- ----- Onglet « Champs » -------------------------------------------------
    -- Tout ce qu'un objet peut donner : le bloc de statistiques du compendium
    -- (statistiques, penetrations, resistances, expertises, mecaniques...),
    -- range par dossier. Un dossier se coche (actif, le defaut) ou se decoche
    -- (prive : ses champs sont verrouilles, absents de la forge) ; un champ
    -- aussi, seul. Deux lectures, comme Necronicon : en liste (dossiers
    -- repliables) ou en tableau (tout a plat, la fenetre s'elargit).
    local pc = CreateFrame("Frame", nil, z)
    pc:SetPoint("TOPLEFT", z, "TOPLEFT", 0, 0)
    pc:SetPoint("TOPRIGHT", z, "TOPRIGHT", 0, 0)
    pc:SetHeight(1)
    f.pageChamps = pc
    f.vue = "liste"
    Libelle(pc, "Limites pour", 4, -6)
    pc.rarete = UI.Bouton(pc, "", 180, 22, function(b)
        local t = f:Travail()
        if not t then return end
        local options = { { id = "", label = "Toutes les raretés" } }
        for _, r in ipairs(t.def.raretes) do options[#options + 1] = { id = r.id, label = r.label } end
        f.choix.titre:SetText("Limites pour")
        f.choix:Proposer(b, options, function(id)
            f.rareteChamps = id ~= "" and id or nil
            f:Rafraichir()
        end)
    end)
    pc.rarete:SetPoint("TOPLEFT", pc, "TOPLEFT", 92, -2)
    pc.vueBouton = UI.Bouton(pc, "Affichage : tableau", 150, 22, function()
        f.vue = f.vue == "tableau" and "liste" or "tableau"
        f:Rafraichir()
    end)
    pc.vueBouton:SetPoint("LEFT", pc.rarete, "RIGHT", 10, 0)
    local aideComplete = "Case cochée = le champ fait partie du jeu ; décochée = privé (absent de la forge, "
        .. "l'entrée garde sa base). Base = valeur de départ (vide = 0) : les points se comptent à partir d'elle, "
        .. "une valeur en dessous rembourse. Min / max vides = libre. Avec une rareté choisie, base / min / max "
        .. "ne valent que pour elle. Coût = points par +1 dans CE jeu (vide = "
        .. C.Nombre(LCM.Equilibrage.forge.coutParDefaut) .. " ; négatif = malus qui rembourse)."
    pc.aide = UI.Texte(pc, "Coche : champ inclus dans la forge. Min / Max vides : aucune limite.\nBase : valeur de départ. Coût : points dépensés par +1.", UI.C.texte, "GameFontNormalSmall")
    pc.aideBouton = UI.Bouton(pc, "?", 22, 22, function() end)
    pc.aideBouton:SetPoint("LEFT", pc.vueBouton, "RIGHT", 8, 0)
    UI.Bulle(pc.aideBouton, "Règles des champs", aideComplete)
    pc.aide:SetPoint("TOPLEFT", pc, "TOPLEFT", 4, -30)
    pc.aide:SetPoint("RIGHT", pc, "RIGHT", -4, 0)
    pc.aide:SetJustifyH("LEFT")
    pc.aide:SetWordWrap(true)

    local HAUT = 134
    local CELLULE = 24
    local COL_L, COL_E = 420, 16
    local LISTE_LARGEUR = 530
    -- En-tete des colonnes de la liste.
    local LISTE_COL = { { "Champ actif", 26, 176, "LEFT" }, { "Min", 214, 44, "CENTER" },
                        { "Base", 262, 44, "CENTER" }, { "Max", 310, 44, "CENTER" }, { "Coût", 358, 44, "CENTER" } }
    pc.enteteListe = {}
    for _, col in ipairs(LISTE_COL) do
        local t = Libelle(pc, col[1], 4 + col[2], -(HAUT - 18))
        t:SetWidth(col[3])
        t:SetJustifyH(col[4])
        pc.enteteListe[#pc.enteteListe + 1] = t
    end

    pc.dossiers, pc.casesDossier, pc.lignes = {}, {}, {}
    pc.tDossiers, pc.tLignes = {}, {}
    f.ouverts = {}
    pc.mode = Libelle(pc, "", 4, -76)
    pc.deplier = UI.Bouton(pc, "Tout déplier", 112, 22, function()
        local t = f:Travail()
        if not t then return end
        local ouvrir = false
        for _, champ in ipairs(LCM.Forge.Champs(t.def.categorie)) do
            if not f.ouverts[champ.dossier] then ouvrir = true break end
        end
        for _, champ in ipairs(LCM.Forge.Champs(t.def.categorie)) do
            f.ouverts[champ.dossier] = ouvrir
        end
        f:Rafraichir()
    end)
    pc.deplier:SetPoint("TOPLEFT", pc, "TOPLEFT", 354, -70)

    -- Un dossier prive : tous ses champs verrouilles. Cocher le rend entier.
    local function Priver(t, dossier, prive)
        for _, champ in ipairs(LCM.Forge.Champs(t.def.categorie)) do
            if champ.dossier == dossier then Ecrire(t, champ.cle, nil, "verrou", prive or nil) end
        end
    end

    local function CaseDossier(parent)
        local k
        k = UI.Case(parent, "", function(coche)
            local t = f:Travail()
            if not t then return end
            Priver(t, k.dossier, not coche)
            f:Rafraichir()
        end)
        return k
    end

    -- « C » : la premiere valeur saisie dans une colonne du dossier, recopiee
    -- sur tous ses champs (CopyFolderColumn de Necronicon, qui prenait le
    -- premier champ meme vide ; ici le premier REMPLI, pour qu'on puisse taper
    -- la valeur sur n'importe quelle ligne). Min, base, max suivent la rarete
    -- choisie ; le cout est celui du jeu.
    local COLONNES_COPIE = { "min", "base", "max", "cout" }
    local XS_COLONNES = { min = 214, base = 262, max = 310, cout = 358 }
    local NOMS_COLONNES = { min = "Min", base = "Base", max = "Max", cout = "Coût" }

    local function Copier(t, dossier, nom)
        local rid = nom ~= "cout" and f.rareteChamps or nil
        local champs, valeur = {}, nil
        for _, champ in ipairs(LCM.Forge.Champs(t.def.categorie)) do
            if champ.dossier == dossier then
                champs[#champs + 1] = champ
                local r = t.def.champs[champ.cle] or {}
                local source = rid and (r.raretes and r.raretes[rid] or {}) or r
                local v = source[nom]
                if valeur == nil and v ~= nil and Texte(v) ~= "" then valeur = v end
            end
        end
        if valeur == nil then
            f:Statut(string.format("%s : aucune valeur à copier dans la colonne %s.", dossier, NOMS_COLONNES[nom]),
                UI.C.plein)
            return
        end
        for _, champ in ipairs(champs) do Ecrire(t, champ.cle, rid, nom, valeur) end
        f:Statut(string.format("%s : %s = %s sur les %d champs.", dossier, NOMS_COLONNES[nom], tostring(valeur), #champs))
        f:Rafraichir()
    end

    -- Les quatre « C » d'un en-tete de dossier, poses au-dessus des colonnes.
    -- `decalage` : ou commence l'en-tete par rapport aux lignes.
    local function BoutonsCopie(parent, decalage)
        local boutons = {}
        for _, nom in ipairs(COLONNES_COPIE) do
            local bouton = UI.Bouton(parent, "C", 18, 16, function(self)
                local t = f:Travail()
                if t and self.dossier then Copier(t, self.dossier, nom) end
            end)
            bouton:SetFrameLevel((parent:GetFrameLevel() or 0) + 5)
            bouton:SetPoint("LEFT", parent, "LEFT", XS_COLONNES[nom] + 13 - decalage, 0)
            UI.Bulle(bouton, "Copier sur tout le dossier",
                "Recopie la première valeur saisie dans cette colonne sur tous les champs du dossier.", 0.4)
            boutons[nom] = bouton
        end
        return boutons
    end

    local function RemplirCopie(boutons, dossier, rarete)
        for nom, bouton in pairs(boutons) do
            bouton.dossier = dossier
            bouton:SetShown(nom ~= "cout" or rarete == nil)
        end
    end

    local function CaseChamp(l)
        return UI.Case(l, "", function(coche)
            local t = f:Travail()
            if not t then return end
            Ecrire(t, l.cle, nil, "verrou", (not coche) or nil)
            f:Rafraichir()
        end)
    end

    local function Saisie(l, nom, largeur, hauteur)
        local e = UI.Champ(l, largeur, hauteur, function(texte)
            local t = f:Travail()
            if not t then return end
            -- Le cout et l'inclusion sont propres au jeu ; min, base, max a
            -- la rarete choisie s'il y en a une.
            local rid = nom ~= "cout" and f.rareteChamps or nil
            Ecrire(t, l.cle, rid, nom, Texte(texte))
            f:Etat(t)
        end)
        e:SetJustifyH("CENTER")
        return e
    end

    -- Une ligne, en liste ou en tableau : memes elements, autres mesures.
    local function NouvelleLigne(compacte)
        local l = CreateFrame("Frame", nil, pc)
        l:SetSize(COL_L - 4, CELLULE - 2)
        l.fond = UI.Aplat(l, { 1, 0.88, 0.65, 0.035 })
        l.fond:SetAllPoints(l)
        l.filet = UI.Aplat(l, UI.C.filetDoux, "BORDER")
        l.filet:SetHeight(1)
        l.filet:SetPoint("BOTTOMLEFT", l, "BOTTOMLEFT", 0, 0)
        l.filet:SetPoint("BOTTOMRIGHT", l, "BOTTOMRIGHT", 0, 0)
        l.actif = CaseChamp(l)
        l.actif:SetScale(0.8)
        l.actif:SetPoint("LEFT", l, "LEFT", 0, 0)
        l.label = UI.Texte(l, "", UI.C.texte, "GameFontNormalSmall")
        l.label:SetPoint("LEFT", l, "LEFT", 28, 0)
        l.label:SetWidth(176)
        UI.Police(l.label, 11)
        l.label:SetJustifyH("LEFT")
        l.label:SetWordWrap(false)
        local w, h = 44, 19
        l.min, l.base, l.max, l.cout = Saisie(l, "min", w, h), Saisie(l, "base", w, h),
            Saisie(l, "max", w, h), Saisie(l, "cout", w, h)
        local xs = { 214, 262, 310, 358 }
        l.min:SetPoint("LEFT", l, "LEFT", xs[1], 0)
        l.base:SetPoint("LEFT", l, "LEFT", xs[2], 0)
        l.max:SetPoint("LEFT", l, "LEFT", xs[3], 0)
        l.cout:SetPoint("LEFT", l, "LEFT", xs[4], 0)
        return l
    end

    function f:LigneChamp(index)
        pc.lignes[index] = pc.lignes[index] or NouvelleLigne(false)
        return pc.lignes[index]
    end

    function f:Dossier(index)
        local b = pc.dossiers[index]
        if b then return b, pc.casesDossier[index] end
        b = UI.Bouton(pc, "", COL_L - 28, 24, function(bouton)
            f.ouverts[bouton.dossier] = not f.ouverts[bouton.dossier]
            f:Rafraichir()
        end)
        b.label:ClearAllPoints()
        b.label:SetPoint("LEFT", b, "LEFT", 8, 0)
        b.label:SetJustifyH("LEFT")
        local k = CaseDossier(pc)
        k:SetScale(0.8)
        if UI.AelCadre then b.cadreCategorie = UI.AelCadre(b, "section") end
        b.copie = BoutonsCopie(b, 28 - 4)
        k:SetPoint("RIGHT", b, "LEFT", -6, 0)
        pc.dossiers[index], pc.casesDossier[index] = b, k
        return b, k
    end

    -- Remplit une ligne depuis la copie de travail.
    local function RemplirLigne(l, t, champ, rarete)
        l.cle = champ.cle
        local r = t.def.champs[champ.cle] or {}
        local sur = rarete and r.raretes and r.raretes[rarete.id] or {}
        local source = rarete and sur or r
        local actif = r.verrou ~= true
        l.label:SetText(champ.label)
        UI.Bulle(l, champ.label, actif and "Champ inclus dans la forge." or "Champ privé : absent de la forge, sa base est conservée.")
        local teinte = actif and UI.C.texte or UI.C.discret
        l.label:SetTextColor(teinte[1], teinte[2], teinte[3])
        local couleur = CouleurDossier(champ.dossier)
        l.fond:SetColorTexture(couleur[1], couleur[2], couleur[3], actif and 0.045 or 0.015)
        l.filet:SetColorTexture(couleur[1], couleur[2], couleur[3], 0.16)
        l.actif:Cocher(actif)
        l.actif:SetShown(rarete == nil)
        for _, nom in ipairs({ "min", "base", "max" }) do
            if not l[nom]:HasFocus() then l[nom]:SetText(tostring(source[nom] or "")) end
            l[nom]:SetAlpha(actif and 1 or 0.4)
        end
        if not l.cout:HasFocus() then l.cout:SetText(tostring(r.cout or "")) end
        l.cout:SetShown(rarete == nil)
        l.cout:SetAlpha(actif and 1 or 0.4)
    end

    -- Les dossiers et leurs champs, avec ce qui est prive.
    local function Groupes(t)
        local groupes, parNom = {}, {}
        for _, champ in ipairs(LCM.Forge.Champs(t.def.categorie)) do
            local g = parNom[champ.dossier]
            if not g then
                g = { nom = champ.dossier, champs = {}, prives = 0 }
                parNom[champ.dossier] = g
                groupes[#groupes + 1] = g
            end
            g.champs[#g.champs + 1] = champ
            local r = t.def.champs[champ.cle]
            if r and r.verrou then g.prives = g.prives + 1 end
        end
        return groupes
    end

    local function Compte(g)
        if g.prives == 0 then return string.format("(%d)", #g.champs) end
        if g.prives == #g.champs then return string.format("(%d, privé)", #g.champs) end
        return string.format("(%d, %d privé%s)", #g.champs, g.prives, g.prives > 1 and "s" or "")
    end

    function f:PageListe(t, rarete)
        for _, e in ipairs(pc.enteteListe) do e:Show() end
        local y = HAUT
        local nD, nL = 0, 0
        local largeur = COL_L - 28
        for _, g in ipairs(Groupes(t)) do
            nD = nD + 1
            local b, k = self:Dossier(nD)
            local ouvert = self.ouverts[g.nom] == true
            b.dossier, k.dossier = g.nom, g.nom
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", pc, "TOPLEFT", 28, -y)
            b:SetWidth(largeur)
            b.label:SetText(string.format("%s %s  |cff888888%s|r", ouvert and "v" or ">", g.nom, Compte(g)))
            TeinterDossier(b, g.nom)
            RemplirCopie(b.copie, g.nom, rarete)
            b:Show()
            -- Cochee tant qu'il reste un champ actif ; decocher prive tout.
            k:Cocher(g.prives < #g.champs)
            k:SetShown(rarete == nil)
            y = y + 29
            if ouvert then
                for _, champ in ipairs(g.champs) do
                    nL = nL + 1
                    local l = self:LigneChamp(nL)
                    l:ClearAllPoints()
                    l:SetPoint("TOPLEFT", pc, "TOPLEFT", 4, -y)
                    RemplirLigne(l, t, champ, rarete)
                    l:Show()
                    y = y + CELLULE
                end
            end
            y = y + 9
        end
        for index = nD + 1, #pc.dossiers do pc.dossiers[index]:Hide() pc.casesDossier[index]:Hide() end
        for index = nL + 1, #pc.lignes do pc.lignes[index]:Hide() end
        return y + 10
    end

    -- Tableau : deux colonnes au maximum, categories entieres et defilement vertical.
    function f:PageTableau(t, rarete)
        for _, e in ipairs(pc.enteteListe) do e:Hide() end
        local hauteurEcran = (UIParent and UIParent:GetHeight()) or 1080
        local largeurEcran = (UIParent and UIParent:GetWidth()) or 1920
        local cols = math.max(1, math.min(2, math.floor((largeurEcran * 0.9 - 60) / (COL_L + COL_E))))
        local places, hauteurs = {}, {}
        for i = 1, cols do hauteurs[i] = 0 end
        -- Chaque categorie reste entiere, dans la colonne la moins haute.
        -- Une seconde ligne rappelle les colonnes de saisie dans chaque carte.
        for _, g in ipairs(Groupes(t)) do
            local colonne = 1
            for i = 2, cols do
                if hauteurs[i] < hauteurs[colonne] then colonne = i end
            end
            local ligne = hauteurs[colonne]
            places[#places + 1] = { groupe = g, col = colonne - 1, ligne = ligne }
            ligne = ligne + 2
            for _, champ in ipairs(g.champs) do
                places[#places + 1] = { champ = champ, col = colonne - 1, ligne = ligne }
                ligne = ligne + 1
            end
            hauteurs[colonne] = ligne + 1
        end
        local lignes = math.max(unpack(hauteurs))
        local largeur = math.max(LISTE_LARGEUR, 46 + cols * (COL_L + COL_E))
        self:SetSize(largeur, math.min(710, hauteurEcran * 0.85))
        local TETE = { { "Champ actif", 26, 176 }, { "Min", 214, 44 }, { "Base", 262, 44 },
                       { "Max", 310, 44 }, { "Coût", 358, 44 } }
        local nD, nL = 0, 0
        for _, p in ipairs(places) do
            local x, y = 4 + p.col * (COL_L + COL_E), -(HAUT + p.ligne * CELLULE)
            if p.groupe then
                nD = nD + 1
                local d = pc.tDossiers[nD]
                if not d then
                    d = CreateFrame("Frame", nil, pc)
                    d:SetSize(COL_L - 4, CELLULE - 2)
                    d.fond = UI.Aplat(d, { UI.C.accent[1], UI.C.accent[2], UI.C.accent[3], 0.10 })
                    d.fond:SetAllPoints(d)
                    d.case = CaseDossier(d)
                    d.case:SetScale(0.8)
                    d.case:SetPoint("LEFT", d, "LEFT", 0, 0)
                    d.label = UI.Texte(d, "", UI.C.titre, "GameFontNormalSmall")
                    d.label:SetPoint("LEFT", d, "LEFT", 22, 0)
                    d.label:SetPoint("RIGHT", d, "LEFT", 210, 0)
                    d.label:SetJustifyH("LEFT")
                    d.label:SetWordWrap(false)
                    UI.Police(d.label, 11)
                    d.carte = CreateFrame("Frame", nil, d)
                    d.carte:SetPoint("TOPLEFT", d, "TOPLEFT", -4, 4)
                    d.carte:SetWidth(COL_L + 4)
                    d.carte:EnableMouse(false)
                    if UI.AelCadre then d.carte.cadre = UI.AelCadre(d.carte, "section") end
                    if UI.AelRef then
                        d.gemme = UI.AelRef(d, 501, 656, 27, 25, "OVERLAY")
                        d.gemme:SetSize(8, 8)
                        d.gemme:SetPoint("TOP", d, "TOP", 0, 8)
                    end
                    d.entetes = {}
                    for i, def in ipairs(TETE) do
                        local texte = Libelle(d, def[1], def[2], -CELLULE - 5)
                        texte:SetWidth(def[3])
                        texte:SetJustifyH(i == 1 and "LEFT" or "CENTER")
                        d.entetes[i] = texte
                    end
                    d.copie = BoutonsCopie(d, 0)
                    pc.tDossiers[nD] = d
                end
                RemplirCopie(d.copie, p.groupe.nom, rarete)
                d.case.dossier = p.groupe.nom
                d.case:Cocher(p.groupe.prives < #p.groupe.champs)
                d.case:SetShown(rarete == nil)
                d.label:SetText(string.format("%s  |cff888888%s|r", p.groupe.nom, Compte(p.groupe)))
                d.carte:SetHeight((2 + #p.groupe.champs) * CELLULE + 6)
                TeinterDossier(d, p.groupe.nom)
                local couleur = CouleurDossier(p.groupe.nom)
                d.fond:SetColorTexture(couleur[1], couleur[2], couleur[3], 0.10)
                d:ClearAllPoints()
                d:SetPoint("TOPLEFT", pc, "TOPLEFT", x, y)
                d:Show()
            else
                nL = nL + 1
                pc.tLignes[nL] = pc.tLignes[nL] or NouvelleLigne(true)
                local l = pc.tLignes[nL]
                l:ClearAllPoints()
                l:SetPoint("TOPLEFT", pc, "TOPLEFT", x, y)
                RemplirLigne(l, t, p.champ, rarete)
                l:Show()
            end
        end
        for index = nD + 1, #pc.tDossiers do pc.tDossiers[index]:Hide() end
        for index = nL + 1, #pc.tLignes do pc.tLignes[index]:Hide() end
        return HAUT + lignes * CELLULE + 10
    end

    function f:PageChamps(t)
        local rarete
        for _, r in ipairs(t.def.raretes) do if r.id == self.rareteChamps then rarete = r end end
        if self.rareteChamps and not rarete then self.rareteChamps = nil end
        pc.rarete.label:SetText(rarete and rarete.label or "Toutes les raretés")
        pc.mode:SetText(self.vue == "tableau" and "TABLEAU · Catégories complètes" or "LISTE · Catégories repliables")
        pc.deplier:SetShown(self.vue == "liste")
        local toutOuvert = true
        for _, g in ipairs(Groupes(t)) do
            if not self.ouverts[g.nom] then toutOuvert = false break end
        end
        pc.deplier.label:SetText(toutOuvert and "Tout replier" or "Tout déplier")
        pc.vueBouton.label:SetText(self.vue == "tableau" and "Affichage : liste" or "Affichage : tableau")
        if self.vue == "tableau" then
            for index = 1, #pc.dossiers do pc.dossiers[index]:Hide() pc.casesDossier[index]:Hide() end
            for _, l in ipairs(pc.lignes) do l:Hide() end
            return self:PageTableau(t, rarete)
        end
        for _, d in ipairs(pc.tDossiers) do d:Hide() end
        for _, l in ipairs(pc.tLignes) do l:Hide() end
        self:SetSize(LISTE_LARGEUR, math.min(710, UIParent:GetHeight() * 0.85))
        return self:PageListe(t, rarete)
    end

    -- ----- Ensemble ----------------------------------------------------------

    function f:Etat(t)
        if t.creation then
            self.etat:SetText("Jeu neuf, pas encore enregistré.")
        elseif t.publie then
            self.etat:SetText("Publié : l'enregistrer en fait un brouillon qui remplace le fichier.")
        else
            self.etat:SetText(t.modifie and "Brouillon, modifications non enregistrées." or "Brouillon.")
        end
    end

    function f:Rafraichir()
        self.onglets:Selectionner(self.onglet)
        local t = self:Travail()
        pj:Hide() pc:Hide()
        self.enregistrer:SetShown(t ~= nil)
        if not t then
            self.etat:SetText("")
            self.zone:Regler(0)
            return
        end
        self:Titre(Texte(t.def.label) ~= "" and t.def.label or "Équilibrage de la forge")
        self:Etat(t)
        local h
        if self.onglet == "jeu" then
            -- Le tableau des champs elargit la fenetre ; la page du jeu non.
            self:SetSize(EQ_LARGEUR, EQ_HAUTEUR)
            pj:Show()
            h = self:PageJeu(t)
        else
            pc:Show()
            h = self:PageChamps(t)
        end
        self.zone:Regler(h)
    end

    function f:Enregistrer()
        local t = self:Travail()
        if not t then return end
        local ok, id = ForgeUI.EnregistrerJeu(t)
        if not ok then
            self:Statut("Refusé : " .. tostring(id), UI.C.plein)
            return
        end
        self.selection = id
        self:Statut("Jeu enregistré : la forge s'en sert dès maintenant, à exporter entre deux séances.", UI.C.accent)
        LCM.Ok("jeu d'equilibrage enregistre : " .. tostring(id))
        self:Rafraichir()
        ForgeUI.Actualiser()
        if UI.Compendium and UI.Compendium.Actualiser then UI.Compendium.Actualiser() end
    end

    f:HookScript("OnShow", function() f:Rafraichir() end)
    return f
end

function ForgeUI.Equilibrage()
    return ForgeUI.equilibrage or ConstruireEquilibrage()
end

-- Ouvre l'equilibrage d'un jeu, ou d'un jeu neuf (`jeu` nil). C'est ce que
-- le compendium appelle pour « Nouvelle entree » et la roue d'une ligne.
function ForgeUI.Editer(jeu)
    local f = ForgeUI.Equilibrage()
    f.selection = jeu and jeu.id or Nouveau().id
    f.onglet, f.rareteChamps = "jeu", nil
    f:Statut("")
    if f:IsShown() then f:Rafraichir() else f:Show() end
    UI.Devant(f)
end
