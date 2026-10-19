-- L'onglet « Outils » du Panel MJ, et son sous-menu.
--
-- Quatre sous-onglets, comme les Outils de Necronicon (Master.lua) : Barres,
-- Compteurs, Annonces, Notes. La premiere reprise les avait ecrases dans une
-- seule page — un libelle, une valeur, un maximum, et trois boutons « + »
-- pour choisir la sorte. On ne pouvait ni regler l'apparence, ni choisir qui
-- voit quoi, ni garder une barre d'une scene a l'autre (le MJ, 20 octobre
-- 2026).
--
-- Chaque sous-onglet montre la meme chose, pour sa sorte :
--   a gauche   ce qui est POSE sur la table, puis la BIBLIOTHEQUE des modeles ;
--   a droite   l'editeur de ce qui est choisi, sa portee, et les gestes.
--
-- L'editeur est construit d'apres `LCM.Outils.CHAMPS` : ajouter un reglage a
-- une sorte, c'est ajouter une ligne a cette table, pas une ligne ici.
--
-- Une annonce ne se pose pas sur la table : elle part, elle s'affiche, elle
-- s'efface. Son sous-onglet n'a donc pas de liste « sur la table », mais un
-- brouillon qu'on garde en bibliotheque et qu'on envoie.

local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end

local UI = LCM.UI
local Ecran = {}
MJ.OutilsUI = Ecran
UI.PanneauOutils = Ecran

local LIGNE, LIGNE_CHAMP = 24, 26
local COLONNE = 216

local function Dire(ok, raison)
    if not ok and raison then LCM.Alerte(tostring(raison)) end
    return ok
end

local function Titre(parent, texte)
    local t = UI.Texte(parent, texte, UI.C.titre)
    UI.Police(t, 12)
    return t
end

local function Rangee(parent, hauteur)
    local l = CreateFrame("Button", nil, parent)
    l:SetHeight((hauteur or LIGNE) - 2)
    if UI.SurfaceLigne then UI.SurfaceLigne(l) end
    return l
end

local function Poser(l, parent, y)
    l:ClearAllPoints()
    l:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
    l:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -y)
    l:Show()
end

local function O() return LCM.Outils end
local function B() return LCM.OutilsBiblio end

-- Un nombre comme on l'ecrit : « 7 » et non « 7.0 ».
local function Chiffre(n)
    n = tonumber(n)
    if not n then return "" end
    if n == math.floor(n) then return string.format("%d", n) end
    return (string.format("%.2f", n):gsub("0+$", ""):gsub("%.$", ""))
end

-- ===== L'editeur d'une sorte ===============================================

-- Une ligne de reglage, selon la nature du champ. Chaque ligne sait LIRE
-- (montrer ce que porte l'outil choisi) et ECRIRE (le poser, en disant le
-- refus).
local function Ligne(sous, champ, y)
    local page = sous.editeur
    local l = CreateFrame("Frame", nil, page)
    l:SetHeight(LIGNE_CHAMP - 4)
    l:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -y)
    l:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -y)
    l.champ = champ

    l.label = UI.Texte(l, champ.label, UI.C.discret)
    UI.Police(l.label, 11)
    l.label:SetPoint("LEFT", l, "LEFT", 0, 0)
    l.label:SetWidth(104)
    l.label:SetJustifyH("LEFT")

    local function Ecrire(valeur)
        local ok, raison = sous:Ecrire(champ.cle, valeur)
        if not ok then Dire(false, raison) end
        sous:Afficher()
        return ok
    end

    if champ.nature == "nombre" then
        l.saisie = UI.Champ(l, 74, 20, nil)
        l.saisie:SetPoint("LEFT", l.label, "RIGHT", 4, 0)
        l.saisie:SetScript("OnEnterPressed", function(s) Ecrire(s:GetText()); s:ClearFocus() end)
        l.saisie:SetScript("OnEditFocusLost", function(s) Ecrire(s:GetText()) end)
        l.bornes = UI.Texte(l, "", UI.C.discret)
        UI.Police(l.bornes, 10)
        l.bornes:SetPoint("LEFT", l.saisie, "RIGHT", 8, 0)
        if champ.min or champ.max then
            l.bornes:SetText(string.format("%s – %s", Chiffre(champ.min) ~= "" and Chiffre(champ.min) or "…",
                Chiffre(champ.max) ~= "" and Chiffre(champ.max) or "…"))
        end
        function l:Lire(valeur) self.saisie:SetText(Chiffre(valeur)) end

    elseif champ.nature == "texte" then
        l.saisie = UI.Champ(l, 240, 20, nil)
        l.saisie:SetPoint("LEFT", l.label, "RIGHT", 4, 0)
        l.saisie:SetMaxLetters(champ.max or 40)
        l.saisie:SetScript("OnEnterPressed", function(s) Ecrire(s:GetText()); s:ClearFocus() end)
        l.saisie:SetScript("OnEditFocusLost", function(s) Ecrire(s:GetText()) end)
        function l:Lire(valeur) self.saisie:SetText(tostring(valeur or "")) end

    elseif champ.nature == "texte_long" then
        l:SetHeight(64)
        l.saisie = UI.Zone(l, 300, 60, nil)
        l.saisie:SetPoint("TOPLEFT", l.label, "TOPRIGHT", 4, 4)
        l.saisie.saisie:SetMaxLetters(champ.max or 600)
        l.saisie.saisie:SetScript("OnEditFocusLost", function(s) Ecrire(s:GetText()) end)
        function l:Lire(valeur)
            -- On ne re-ecrit pas le texte qu'on est en train de taper : le
            -- curseur sauterait au debut a chaque frappe.
            if self.saisie.saisie:HasFocus() then return end
            self.saisie:SetText(tostring(valeur or ""))
        end

    elseif champ.nature == "couleur" then
        l.saisie = UI.Champ(l, 74, 20, nil)
        l.saisie:SetPoint("LEFT", l.label, "RIGHT", 4, 0)
        l.saisie:SetMaxLetters(7)
        l.saisie:SetScript("OnEnterPressed", function(s) Ecrire(s:GetText()); s:ClearFocus() end)
        l.saisie:SetScript("OnEditFocusLost", function(s) Ecrire(s:GetText()) end)
        -- L'apercu : on juge une couleur en la voyant, pas en lisant son code.
        l.pastille = CreateFrame("Frame", nil, l)
        l.pastille:SetSize(20, 20)
        l.pastille:SetPoint("LEFT", l.saisie, "RIGHT", 8, 0)
        l.pastille.fond = UI.Aplat(l.pastille, { 1, 1, 1, 1 })
        l.pastille.fond:SetAllPoints(l.pastille)
        UI.BordureFine(l.pastille, 0.6)
        function l:Lire(valeur)
            self.saisie:SetText(tostring(valeur or ""))
            self.pastille.fond:SetColorTexture(O().Teinte(valeur, champ.defaut))
        end

    elseif champ.nature == "choix" then
        l.bouton = UI.Bouton(l, "", 150, 20, function(bouton)
            sous.choix = sous.choix or UI.Choix("outils_" .. tostring(champ.cle), champ.label)
            sous.choix:Proposer(bouton, champ.options, function(id) Ecrire(id) end)
        end)
        l.bouton:SetPoint("LEFT", l.label, "RIGHT", 4, 0)
        function l:Lire(valeur)
            local nom = tostring(valeur or "")
            for _, option in ipairs(champ.options or {}) do
                if option.id == valeur then nom = option.label end
            end
            self.bouton.label:SetText(nom)
        end

    elseif champ.nature == "icone" then
        l.apercu = l:CreateTexture(nil, "ARTWORK")
        l.apercu:SetSize(20, 20)
        l.apercu:SetPoint("LEFT", l.label, "RIGHT", 4, 0)
        l.apercu:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        l.bouton = UI.Bouton(l, "Choisir…", 100, 20, function(bouton)
            sous.icones = sous.icones or UI.SelecteurIcone("outils_annonce")
            sous.icones:Proposer(bouton, function(chemin) Ecrire(chemin) end)
        end)
        l.bouton:SetPoint("LEFT", l.apercu, "RIGHT", 8, 0)
        l.aucune = UI.Bouton(l, "Aucune", 70, 20, function() Ecrire("") end)
        l.aucune:SetPoint("LEFT", l.bouton, "RIGHT", 4, 0)
        function l:Lire(valeur)
            local chemin = tostring(valeur or "")
            self.apercu:SetShown(chemin ~= "")
            if chemin ~= "" then self.apercu:SetTexture(LCM.Icone(chemin)) end
        end
    end

    if not l.Lire then function l:Lire() end end
    return l, y + l:GetHeight() + 6
end

-- ===== Un sous-onglet ======================================================

local function Sous(page, f, sorte)
    local sous = CreateFrame("Frame", nil, page)
    sous:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -28)
    sous:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
    sous.sorte = sorte
    -- Une annonce ne se pose pas sur la table : elle part et s'efface.
    sous.posable = sorte ~= "annonce"
    sous.brouillon = O().Defauts(sorte)
    page.sous[sorte] = sous

    -- ----- ce qui est choisi ------------------------------------------------
    -- `sous.outilId` : un outil pose, regle en direct (chaque frappe repart a
    -- la table si l'outil est affiche). Sinon, le brouillon.
    function sous:Cible()
        if self.outilId then return O().Get(self.outilId) end
        return self.brouillon
    end

    function sous:Ecrire(cle, valeur)
        if self.outilId then return O().Definir(self.outilId, cle, valeur) end
        local propre, raison = O().Lire(sorte, cle, valeur)
        if propre == nil then return false, raison end
        self.brouillon[cle] = propre
        return true
    end

    -- ----- la colonne de gauche --------------------------------------------
    local hautListe = 0
    if sous.posable then
        sous.titreTable = Titre(sous, "Sur la table")
        sous.titreTable:SetPoint("TOPLEFT", sous, "TOPLEFT", 0, 0)
        sous.nouveau = UI.Bouton(sous, "+ Nouveau", 92, 20, function()
            local outil, raison = O().Creer(sorte, O().Defauts(sorte))
            if not outil then Dire(false, raison) return end
            sous.outilId = outil.id
            sous:Afficher()
        end)
        sous.nouveau:SetPoint("TOPLEFT", sous, "TOPLEFT", COLONNE - 94, 2)
        sous.zoneTable = UI.Defilement(sous)
        sous.zoneTable:SetPoint("TOPLEFT", sous, "TOPLEFT", 0, -22)
        sous.zoneTable:SetWidth(COLONNE)
        sous.zoneTable:SetHeight(140)
        sous.lignesTable = {}
        sous.videTable = UI.Texte(sous, "", UI.C.discret)
        UI.Police(sous.videTable, 11)
        sous.videTable:SetPoint("TOPLEFT", sous.zoneTable, "TOPLEFT", 4, -6)
        hautListe = 170
    end

    sous.titreBiblio = Titre(sous, "Bibliothèque")
    sous.titreBiblio:SetPoint("TOPLEFT", sous, "TOPLEFT", 0, -hautListe)
    sous.garder = UI.Bouton(sous, "Garder", 92, 20, function()
        local modele, raison = B().Garder(sous:Cible())
        if not modele then Dire(false, raison) return end
        LCM.Ok(string.format("« %s » gardé en bibliothèque.", tostring(modele.libelle)))
        sous:Afficher()
    end)
    sous.garder:SetPoint("TOPLEFT", sous, "TOPLEFT", COLONNE - 94, -hautListe + 2)
    sous.zoneBiblio = UI.Defilement(sous)
    sous.zoneBiblio:SetPoint("TOPLEFT", sous, "TOPLEFT", 0, -hautListe - 22)
    sous.zoneBiblio:SetPoint("BOTTOMLEFT", sous, "BOTTOMLEFT", 0, 0)
    sous.zoneBiblio:SetWidth(COLONNE)
    sous.lignesBiblio = {}
    sous.videBiblio = UI.Texte(sous, "", UI.C.discret)
    UI.Police(sous.videBiblio, 11)
    sous.videBiblio:SetPoint("TOPLEFT", sous.zoneBiblio, "TOPLEFT", 4, -6)

    -- ----- l'editeur --------------------------------------------------------
    sous.editeur = CreateFrame("Frame", nil, sous)
    sous.editeur:SetPoint("TOPLEFT", sous, "TOPLEFT", COLONNE + 14, 0)
    sous.editeur:SetPoint("BOTTOMRIGHT", sous, "BOTTOMRIGHT", 0, 92)

    sous.lignes = {}
    local y = 0
    for _, champ in ipairs(O().Champs(sorte) or {}) do
        local ligne, suite = Ligne(sous, champ, y)
        sous.lignes[#sous.lignes + 1] = ligne
        y = suite
    end

    -- ----- la portee et les gestes -----------------------------------------
    local pied = CreateFrame("Frame", nil, sous)
    pied:SetPoint("BOTTOMLEFT", sous, "BOTTOMLEFT", COLONNE + 14, 0)
    pied:SetPoint("BOTTOMRIGHT", sous, "BOTTOMRIGHT", 0, 0)
    pied:SetHeight(88)
    sous.pied = pied

    sous.labelPortee = UI.Texte(pied, "Portée", UI.C.discret)
    UI.Police(sous.labelPortee, 11)
    sous.labelPortee:SetPoint("TOPLEFT", pied, "TOPLEFT", 0, -4)
    sous.labelPortee:SetWidth(104)
    sous.portee = UI.Bouton(pied, "", 150, 20, function(bouton)
        sous.choixPortee = sous.choixPortee or UI.Choix("outils_portee", "Qui le voit")
        sous.choixPortee:Proposer(bouton, O().PORTEES, function(id)
            if sous.outilId then
                Dire(O().Cibler(sous.outilId, id, sous.brouillon.cibles))
            else
                sous.brouillon.portee = id
            end
            sous:Afficher()
        end)
    end)
    sous.portee:SetPoint("LEFT", sous.labelPortee, "RIGHT", 4, 0)
    sous.joueurs = UI.Bouton(pied, "Joueurs…", 90, 20, function()
        sous.choixJoueurs = sous.choixJoueurs or UI.ChoixJoueurs("outils")
        sous.choixJoueurs:Proposer("Montrer à", function(noms)
            if #noms == 0 then return false, "personne de sélectionné." end
            if sous.outilId then
                Dire(O().Cibler(sous.outilId, "joueurs", noms))
            else
                sous.brouillon.portee, sous.brouillon.cibles = "joueurs", noms
            end
            sous:Afficher()
            return true
        end)
    end)
    sous.joueurs:SetPoint("LEFT", sous.portee, "RIGHT", 6, 0)
    sous.cibles = UI.Texte(pied, "", UI.C.discret)
    UI.Police(sous.cibles, 10)
    sous.cibles:SetPoint("TOPLEFT", sous.labelPortee, "BOTTOMLEFT", 0, -6)
    sous.cibles:SetPoint("TOPRIGHT", pied, "TOPRIGHT", 0, -30)
    sous.cibles:SetJustifyH("LEFT")
    sous.cibles:SetWordWrap(false)

    if sous.posable then
        sous.afficher = UI.Bouton(pied, "Afficher", 90, 22, function()
            if not sous.outilId then Dire(false, "choisis d'abord un outil.") return end
            local outil = sous:Cible()
            Dire(O().Afficher(sous.outilId, outil.portee, outil.cibles))
            sous:Afficher()
        end)
        sous.afficher:SetPoint("BOTTOMLEFT", pied, "BOTTOMLEFT", 0, 4)
        sous.masquer = UI.Bouton(pied, "Masquer", 90, 22, function()
            if not sous.outilId then return end
            Dire(O().Masquer(sous.outilId))
            sous:Afficher()
        end)
        sous.masquer:SetPoint("LEFT", sous.afficher, "RIGHT", 6, 0)
        sous.moins = UI.Bouton(pied, "−", 28, 22, function()
            if sous.outilId then Dire(O().Ajouter(sous.outilId, -(sous:Cible().pas or 1))) end
            sous:Afficher()
        end)
        sous.moins:SetPoint("LEFT", sous.masquer, "RIGHT", 16, 0)
        sous.plus = UI.Bouton(pied, "+", 28, 22, function()
            if sous.outilId then Dire(O().Ajouter(sous.outilId, sous:Cible().pas or 1)) end
            sous:Afficher()
        end)
        sous.plus:SetPoint("LEFT", sous.moins, "RIGHT", 4, 0)
        sous.retirer = UI.Bouton(pied, "Retirer", 80, 22, function()
            if not sous.outilId then return end
            Dire(O().Retirer(sous.outilId))
            sous.outilId = nil
            sous:Afficher()
        end)
        sous.retirer:SetPoint("BOTTOMRIGHT", pied, "BOTTOMRIGHT", 0, 4)
    else
        sous.annoncer = UI.Bouton(pied, "Annoncer", 110, 22, function()
            local annonce = {}
            for _, champ in ipairs(O().Champs("annonce")) do annonce[champ.cle] = sous.brouillon[champ.cle] end
            annonce.portee = sous.brouillon.portee or "groupe"
            annonce.cibles = sous.brouillon.cibles
            if Dire(O().Annoncer(annonce)) then LCM.Ok("annonce envoyée.") end
        end)
        sous.annoncer:SetPoint("BOTTOMLEFT", pied, "BOTTOMLEFT", 0, 4)
        sous.neuve = UI.Bouton(pied, "Vider", 80, 22, function()
            sous.brouillon = O().Defauts("annonce")
            sous:Afficher()
        end)
        sous.neuve:SetPoint("BOTTOMRIGHT", pied, "BOTTOMRIGHT", 0, 4)
    end

    -- ----- dessiner ---------------------------------------------------------
    local function LigneTable(rang)
        local l = sous.lignesTable[rang]
        if l then return l end
        l = Rangee(sous.zoneTable.contenu, LIGNE)
        l.nom = UI.Texte(l, "", UI.C.texte)
        UI.Police(l.nom, 11)
        l.nom:SetPoint("LEFT", l, "LEFT", 6, 0)
        l.nom:SetWidth(120)
        l.nom:SetJustifyH("LEFT")
        l.nom:SetWordWrap(false)
        l.etat = UI.Texte(l, "", UI.C.discret)
        UI.Police(l.etat, 10)
        l.etat:SetPoint("RIGHT", l, "RIGHT", -6, 0)
        l:SetScript("OnClick", function(self)
            sous.outilId = self.outilId
            sous:Afficher()
        end)
        sous.lignesTable[rang] = l
        return l
    end

    local function LigneBiblio(rang)
        local l = sous.lignesBiblio[rang]
        if l then return l end
        l = Rangee(sous.zoneBiblio.contenu, LIGNE)
        l.nom = UI.Texte(l, "", UI.C.texte)
        UI.Police(l.nom, 11)
        l.nom:SetPoint("LEFT", l, "LEFT", 6, 0)
        l.nom:SetWidth(96)
        l.nom:SetJustifyH("LEFT")
        l.nom:SetWordWrap(false)
        l.oublier = UI.Bouton(l, "x", 18, 18, function()
            Dire(B().Oublier(l.modeleId))
            sous:Afficher()
        end)
        l.oublier:SetPoint("RIGHT", l, "RIGHT", -4, 0)
        -- Poser un modele : il devient un outil de scene (ou, pour une
        -- annonce, le brouillon qu'on va envoyer).
        l.poser = UI.Bouton(l, sous.posable and "Poser" or "Charger", 60, 18, function()
            local modele = B().Get(l.modeleId)
            if not modele then return end
            if sous.posable then
                local outil, raison = B().Poser(l.modeleId)
                if not outil then Dire(false, raison) return end
                sous.outilId = outil.id
            else
                local brouillon = O().Defauts("annonce")
                for _, champ in ipairs(O().Champs("annonce")) do brouillon[champ.cle] = modele[champ.cle] end
                brouillon.portee = sous.brouillon.portee
                brouillon.cibles = sous.brouillon.cibles
                sous.brouillon = brouillon
            end
            sous:Afficher()
        end)
        l.poser:SetPoint("RIGHT", l.oublier, "LEFT", -4, 0)
        sous.lignesBiblio[rang] = l
        return l
    end

    function sous:Afficher()
        -- L'outil choisi a pu etre retire entre-temps.
        if self.outilId and not O().Get(self.outilId) then self.outilId = nil end

        if self.posable then
            local liste = O().Liste(sorte)
            local y2 = 0
            for rang, outil in ipairs(liste) do
                local l = LigneTable(rang)
                l.outilId = outil.id
                l.nom:SetText(outil.libelle)
                local nom = O().NomPortee(outil.portee) or "?"
                l.etat:SetText(outil.visible and ("montré · " .. nom) or "posé")
                local couleur = outil.visible and UI.C.accent or UI.C.discret
                l.etat:SetTextColor(couleur[1], couleur[2], couleur[3])
                -- Ce qui est choisi se voit : sans quoi l'editeur de droite
                -- parle d'un outil qu'on ne sait pas designer.
                local choisi = outil.id == self.outilId
                l.nom:SetTextColor(choisi and UI.C.titre[1] or UI.C.texte[1],
                    choisi and UI.C.titre[2] or UI.C.texte[2],
                    choisi and UI.C.titre[3] or UI.C.texte[3])
                Poser(l, self.zoneTable.contenu, y2)
                y2 = y2 + LIGNE
            end
            for rang = #liste + 1, #self.lignesTable do self.lignesTable[rang]:Hide() end
            self.zoneTable:Regler(y2)
            self.nombreTable = #liste
            self.videTable:SetText(#liste > 0 and "" or "Rien de posé.")
        end

        local modeles = B().Liste(sorte)
        local y3 = 0
        for rang, modele in ipairs(modeles) do
            local l = LigneBiblio(rang)
            l.modeleId = modele.id
            l.nom:SetText(modele.libelle)
            Poser(l, self.zoneBiblio.contenu, y3)
            y3 = y3 + LIGNE
        end
        for rang = #modeles + 1, #self.lignesBiblio do self.lignesBiblio[rang]:Hide() end
        self.zoneBiblio:Regler(y3)
        self.nombreBiblio = #modeles
        self.videBiblio:SetText(#modeles > 0 and "" or "Rien de gardé.")

        local cible = self:Cible()
        for _, ligne in ipairs(self.lignes) do
            ligne:Lire(cible and cible[ligne.champ.cle])
        end
        local portee = (cible and cible.portee) or "groupe"
        self.portee.label:SetText(O().NomPortee(portee) or portee)
        local noms = (cible and cible.cibles) or {}
        self.cibles:SetText(portee == "joueurs"
            and (#noms > 0 and ("→ " .. table.concat(noms, ", ")) or "→ personne de choisi")
            or "")
        if self.posable then
            local chiffre = sorte == "barre" or sorte == "compteur"
            self.moins:SetShown(chiffre)
            self.plus:SetShown(chiffre)
            self.afficher:SetEnabled(self.outilId ~= nil)
            self.masquer:SetEnabled(self.outilId ~= nil and cible and cible.visible == true)
            self.retirer:SetEnabled(self.outilId ~= nil)
            self.editeur:SetShown(self.outilId ~= nil)
            self.pied:SetShown(self.outilId ~= nil)
        end
    end

    sous:Hide()
    return sous
end

-- ===== La page =============================================================

function Ecran.Page(page, f)
    page.sous = {}
    local onglets = {}
    for _, sorte in ipairs(LCM.Outils.ORDRE) do
        onglets[#onglets + 1] = { id = sorte,
            label = sorte == "annonce" and "Annonces" or (LCM.Outils.SORTES[sorte] .. "s") }
    end

    page.barre = UI.BandeauOnglets(page, onglets, function(id) page:Sous(id) end)
    page.barre:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    page.barre:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, 0)
    page.barre:Disposer(page:GetWidth() > 0 and page:GetWidth() or 676, 24, { uneRangee = true })

    for _, sorte in ipairs(LCM.Outils.ORDRE) do Sous(page, f, sorte) end

    function page:Sous(id)
        id = LCM.Outils.Champs(id) and id or LCM.Outils.ORDRE[1]
        self.sorte = id
        self.barre:Selectionner(id)
        for sorte, sous in pairs(self.sous) do
            sous:SetShown(sorte == id)
            if sorte == id then sous:Afficher() end
        end
    end

    function page:Afficher()
        -- A la construction, la page n'a pas encore sa largeur : le bandeau
        -- s'etait partage 676 au jugé. On le redispose sur la vraie largeur des
        -- qu'on l'ouvre.
        local largeur = self:GetWidth() or 0
        if largeur > 0 and largeur ~= self.largeurBandeau then
            self.largeurBandeau = largeur
            self.barre:Disposer(largeur, 24, { uneRangee = true })
        end
        self:Sous(self.sorte or LCM.Outils.ORDRE[1])
    end

    -- Les outils changent (le MJ regle, un joueur demande un renvoi) : la page
    -- ouverte suit.
    LCM.Outils.onChangeMJ = function()
        if f:IsShown() and f.onglet == "outils" then page:Afficher() end
    end
    if LCM.OutilsBiblio then
        LCM.OutilsBiblio.onChange = function()
            if f:IsShown() and f.onglet == "outils" then page:Afficher() end
        end
    end
end
