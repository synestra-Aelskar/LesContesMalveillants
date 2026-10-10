-- L'atelier des lieux : poser les frontieres, sur place.
--
-- Le principe vient du module Zone Gate d'Omega Hub (Akriaxx) ; la mecanique
-- est dans Core/Lieux.lua, et le pourquoi des ecarts avec Zone Gate y est
-- explique. Ici, c'est l'outil du MJ.
--
-- La fenetre en deux colonnes :
--
--   * a GAUCHE l'arbre : les lieux, et sous chacun ses seuils. Un clic passe
--     de l'un a l'autre, le volet de droite suit ;
--   * a DROITE ce qu'on peut faire a ce qui est selectionne, et rien d'autre.
--     Une porte n'affiche pas de rayon, un cercle n'affiche pas de bornes.
--
-- Le coeur du volet, c'est le RADAR, avec les boutons de pose juste a cote.
-- On pose une frontiere en marchant : il faut voir ou l'on est par rapport a
-- elle au moment ou l'on clique, sinon on repose trois fois la meme borne.
-- Le radar est nord en haut, le joueur au centre, et son echelle se choisit
-- toute seule pour que le seuil tienne toujours dedans. Pas de vue
-- egocentrique : on n'a pas besoin de l'orientation du personnage, et s'en
-- passer evite une inconnue. Ou est le nord, lui, se MESURE (LCM.Lieux.Boussole).

local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end

local UI = LCM.UI
local Ecran = {}
UI.LieuxMJ = Ecran
MJ.Lieux = Ecran

local LARGEUR, HAUTEUR = 780, 620
local COLONNE = 240
local LIGNE = 22
local RADAR = 180
-- Le pouls du radar et de la ligne d'etat. Plus fin ne se verrait pas, plus
-- lent donnerait l'impression que l'atelier a decroche.
local POULS = 0.2

local function L() return LCM.Lieux end

local function Dire(ok, raison)
    if not ok and raison then LCM.Alerte(tostring(raison)) end
    return ok
end

-- ===== Ou est le nord =====================================================
-- Le radar est au nord. Ou est le nord dans les coordonnees d'une source, ce
-- n'est plus une deduction : `LCM.Lieux.Boussole` rend ce qui a ete MESURE en
-- regardant bouger le MJ (deux deplacements suffisent), et ne retombe sur la
-- convention que si la carte ne repond pas du tout. Le troisieme retour dit
-- laquelle des deux on applique — et le radar l'affiche, pour qu'un nord
-- suppose ne passe jamais pour un nord su.

-- Les paliers d'echelle, en pixels par metre. On prend le plus serre qui fait
-- tenir le seuil dans le radar : une porte a trois pas doit se voir en grand,
-- une region de deux cents metres doit tenir en entier.
local ECHELLES = { 8, 5, 3, 2, 1.2, 0.7, 0.4, 0.2, 0.1, 0.05 }

-- ===== Le radar ============================================================

local function Segment(texture, x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    local longueur = math.sqrt(dx * dx + dy * dy)
    if longueur < 0.5 then texture:Hide() return end
    texture:ClearAllPoints()
    texture:SetPoint("CENTER", texture.radar, "CENTER", (x1 + x2) / 2, (y1 + y2) / 2)
    texture:SetWidth(longueur)
    if texture.SetRotation then texture:SetRotation(math.atan2(dy, dx)) end
    texture:Show()
end

local function ConstruireRadar(parent)
    local r = CreateFrame("Frame", nil, parent)
    r:SetSize(RADAR, RADAR)
    r.fond = UI.Aplat(r, { 0.035, 0.030, 0.023, 0.92 })
    r.fond:SetAllPoints(r)
    UI.Bordure(r, { UI.C.bordure[1], UI.C.bordure[2], UI.C.bordure[3], 0.45 })

    -- Le reticule : deux filets, pour avoir un repere quand rien n'est pose.
    r.croixV = UI.Filet(r, true, true)
    r.croixV:SetPoint("TOP", r, "TOP", 0, -2)
    r.croixV:SetPoint("BOTTOM", r, "BOTTOM", 0, 2)
    r.croixH = UI.Filet(r, true)
    r.croixH:SetPoint("LEFT", r, "LEFT", 2, 0)
    r.croixH:SetPoint("RIGHT", r, "RIGHT", -2, 0)

    -- Le N ne reste pas en haut : le radar tourne avec le personnage, donc
    -- c'est le nord qui se promene sur le pourtour, comme sur la minicarte du
    -- jeu en mode « rotation ».
    r.nord = UI.Texte(r, "N", UI.C.accent)
    UI.Police(r.nord, 10)
    r.nord:SetPoint("CENTER", r, "CENTER", 0, RADAR / 2 - 12)

    -- Le joueur, au centre et toujours, le regard vers le haut.
    r.moi = UI.Aplat(r, { 0.95, 0.90, 0.60, 1 }, "OVERLAY")
    r.moi:SetSize(7, 7)
    r.moi:SetPoint("CENTER", r, "CENTER", 0, 0)
    r.regard = r:CreateTexture(nil, "OVERLAY")
    r.regard:SetSize(14, 14)
    r.regard:SetTexture("Interface\\Minimap\\MinimapArrow")
    r.regard:SetPoint("CENTER", r, "CENTER", 0, 10)
    r.regard:Hide()

    -- La porte : le segment entre les deux bornes, et une pastille par borne.
    r.porte = UI.Aplat(r, { 0.85, 0.75, 0.40, 0.95 }, "ARTWORK")
    r.porte:SetHeight(3)
    r.porte.radar = r
    r.porte:Hide()
    r.borneA = UI.Aplat(r, { 0.90, 0.80, 0.45, 1 }, "OVERLAY")
    r.borneA:SetSize(6, 6)
    r.borneA:Hide()
    r.borneB = UI.Aplat(r, { 0.90, 0.80, 0.45, 1 }, "OVERLAY")
    r.borneB:SetSize(6, 6)
    r.borneB:Hide()
    -- De quel cote on entre, de quel cote on sort : sans ca, « Inverser le
    -- sens » se regle a l'aveugle.
    r.dedans = UI.Texte(r, "ENTRÉE", { 0.40, 0.85, 0.45 })
    UI.Police(r.dedans, 9)
    r.dedans:Hide()
    r.dehors = UI.Texte(r, "RETOUR", { 0.85, 0.40, 0.40 })
    UI.Police(r.dehors, 9)
    r.dehors:Hide()

    -- Le cercle : un disque a la bonne echelle, decoupe par un masque rond.
    r.disque = r:CreateTexture(nil, "ARTWORK")
    r.disque:SetColorTexture(0.85, 0.75, 0.40, 0.28)
    if r.CreateMaskTexture then
        local masque = r:CreateMaskTexture(nil, "ARTWORK")
        masque:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
        masque:SetAllPoints(r.disque)
        if r.disque.AddMaskTexture then r.disque:AddMaskTexture(masque) end
    end
    r.disque:Hide()
    r.centre = UI.Aplat(r, { 0.90, 0.80, 0.45, 1 }, "OVERLAY")
    r.centre:SetSize(6, 6)
    r.centre:Hide()

    -- La region : un point par sommet, des segments entre eux. Reserve une
    -- fois pour toutes — on ne cree pas de texture dans une boucle d'affichage.
    r.points, r.aretes = {}, {}
    for i = 1, 20 do
        local p = UI.Aplat(r, { 0.90, 0.80, 0.45, 1 }, "OVERLAY")
        p:SetSize(5, 5)
        p:Hide()
        r.points[i] = p
        local a = UI.Aplat(r, { 0.85, 0.75, 0.40, 0.75 }, "ARTWORK")
        a:SetHeight(2)
        a.radar = r
        a:Hide()
        r.aretes[i] = a
    end

    r.echelle = UI.Texte(r, "", UI.C.discret)
    UI.Police(r.echelle, 9)
    r.echelle:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -4, 3)

    function r:Effacer()
        self.porte:Hide() self.borneA:Hide() self.borneB:Hide()
        self.dedans:Hide() self.dehors:Hide()
        self.disque:Hide() self.centre:Hide()
        for i = 1, 20 do self.points[i]:Hide() self.aretes[i]:Hide() end
        self.echelle:SetText("")
    end

    -- Place une pastille a un decalage radar donne, en la ramenant au bord si
    -- elle sort : mieux vaut une borne collee au bord qu'une borne invisible.
    local MARGE = RADAR / 2 - 8
    function r:Poser(texture, x, y)
        local d = math.sqrt(x * x + y * y)
        if d > MARGE and d > 0 then x, y = x * MARGE / d, y * MARGE / d end
        texture:ClearAllPoints()
        texture:SetPoint("CENTER", self, "CENTER", x, y)
        texture:Show()
        return x, y
    end

    return r
end

-- ===== L'arbre =============================================================

local function LigneArbre(f, rang)
    local l = f.lignes[rang]
    if l then return l end
    l = CreateFrame("Button", nil, f.arbre.contenu)
    l:SetHeight(LIGNE - 2)
    if UI.SurfaceLigne then UI.SurfaceLigne(l) end
    l.survol = UI.Aplat(l, UI.C.survol, "HIGHLIGHT")
    l.survol:SetAllPoints(l)
    l.nom = UI.Texte(l, "", UI.C.texte)
    UI.Police(l.nom, 11)
    l.nom:SetPoint("LEFT", l, "LEFT", 6, 0)
    l.nom:SetWordWrap(false)
    l.note = UI.Texte(l, "", UI.C.discret)
    UI.Police(l.note, 10)
    l.note:SetPoint("RIGHT", l, "RIGHT", -6, 0)
    l.nom:SetPoint("RIGHT", l.note, "LEFT", -6, 0)
    l:SetScript("OnClick", function(self)
        Ecran.lieu, Ecran.seuil = self.lieuId, self.seuilId
        f:Afficher()
    end)
    f.lignes[rang] = l
    return l
end

-- ===== La fenetre ==========================================================

local function Construire()
    local f = UI.Fenetre("lieux_mj", "Atelier des lieux", LARGEUR, HAUTEUR, { x = 0, y = 0 })
    Ecran.frame = f
    f.lignes = {}

    -- ----- colonne de gauche ------------------------------------------------
    f.titreArbre = UI.Texte(f.contenu, "Lieux", UI.C.titre)
    UI.Police(f.titreArbre, 12)
    f.titreArbre:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)

    f.nouveau = UI.Champ(f.contenu, COLONNE - 86, 20, nil)
    f.nouveau:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -20)
    f.creer = UI.Bouton(f.contenu, "+ Lieu", 80, 20, function()
        local lieu, raison = L().Creer(f.nouveau:GetText())
        if not lieu then LCM.Alerte(tostring(raison)) return end
        f.nouveau:SetText("")
        Ecran.lieu, Ecran.seuil = lieu.id, nil
        f:Afficher()
    end)
    f.creer:SetPoint("LEFT", f.nouveau, "RIGHT", 6, 0)

    f.arbre = UI.Defilement(f.contenu)
    f.arbre:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -48)
    f.arbre:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 24)
    f.arbre:SetWidth(COLONNE)

    f.vide = UI.Texte(f.contenu, "", UI.C.discret)
    UI.Police(f.vide, 11)
    f.vide:SetPoint("TOPLEFT", f.arbre, "TOPLEFT", 4, -4)
    f.vide:SetWidth(COLONNE - 12)
    f.vide:SetWordWrap(true)
    f.vide:SetJustifyH("LEFT")

    f.renvoyer = UI.Bouton(f.contenu, "Tout renvoyer au groupe", COLONNE, 20, function()
        LCM.Ok(string.format("%d lieu(x) renvoyé(s).", L().Renvoyer()))
    end)
    f.renvoyer:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 0)

    f.filet = UI.Filet(f.contenu, true, true)
    f.filet:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", COLONNE + 12, 0)
    f.filet:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", COLONNE + 12, 0)

    -- ----- le volet de droite ----------------------------------------------
    local X = COLONNE + 24
    local largeur = LARGEUR - 24 - X
    -- La colonne des commandes, a droite du radar.
    local XB = X + RADAR + 14
    local largeurB = largeur - RADAR - 14

    local function Poser(w, y, dx)
        w:ClearAllPoints()
        w:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", X + (dx or 0), -y)
        return w
    end
    local function PoserB(w, y, dx)
        w:ClearAllPoints()
        w:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", XB + (dx or 0), -y)
        return w
    end
    local function Etiquette(texte, y, dx, ancrage)
        local t = UI.Texte(f.contenu, texte, UI.C.libelle)
        UI.Police(t, 11)
        if ancrage == "b" then PoserB(t, y, dx) else Poser(t, y, dx) end
        return t
    end

    f.cible = UI.Texte(f.contenu, "", UI.C.titre)
    UI.Police(f.cible, 14)
    Poser(f.cible, 0)
    f.cible:SetWidth(largeur)
    f.cible:SetJustifyH("LEFT")
    f.cible:SetWordWrap(false)

    f.etat = UI.Texte(f.contenu, "", UI.C.discret)
    UI.Police(f.etat, 11)
    Poser(f.etat, 20)
    f.etat:SetWidth(largeur)
    f.etat:SetJustifyH("LEFT")

    f.manque = UI.Texte(f.contenu, "", UI.C.plein)
    UI.Police(f.manque, 11)
    Poser(f.manque, 38)
    f.manque:SetWidth(largeur)
    f.manque:SetJustifyH("LEFT")
    f.manque:SetWordWrap(true)

    f.nomLabel = Etiquette("Nom", 62)
    f.nom = UI.Champ(f.contenu, largeur - 150, 20, nil)
    Poser(f.nom, 60, 34)
    f.renommer = UI.Bouton(f.contenu, "Renommer", 96, 20, function()
        if Ecran.seuil then Dire(L().RenommerSeuil(Ecran.seuil, f.nom:GetText()))
        else Dire(L().Renommer(Ecran.lieu, f.nom:GetText())) end
        f:Afficher()
    end)
    f.renommer:SetPoint("LEFT", f.nom, "RIGHT", 6, 0)

    -- ----- ce qui n'appartient qu'au LIEU ----------------------------------
    f.couleurLabel = Etiquette("Couleur", 94)
    f.couleur = UI.Champ(f.contenu, 80, 20, nil)
    Poser(f.couleur, 92, 54)
    f.couleurOk = UI.Bouton(f.contenu, "Appliquer", 80, 20, function()
        Dire(L().Couleur(Ecran.lieu, f.couleur:GetText()))
        f:Afficher()
    end)
    f.couleurOk:SetPoint("LEFT", f.couleur, "RIGHT", 6, 0)
    f.couleurAide = UI.Texte(f.contenu, "RRVVBB — la bannière s'en teinte.", UI.C.discret)
    UI.Police(f.couleurAide, 10)
    f.couleurAide:SetPoint("LEFT", f.couleurOk, "RIGHT", 10, 0)

    f.decouverte = UI.Case(f.contenu, "Le nom se découvre en entrant", function(cochee)
        Dire(L().Decouverte(Ecran.lieu, cochee))
        f:Afficher()
    end)
    Poser(f.decouverte, 122)
    UI.Bulle(f.decouverte, "Découverte",
        "Coché, le joueur apprend le nom du lieu en franchissant un de ses seuils.\n\n"
        .. "Décoché, il lit « Lieu inconnu » et un nom masqué jusqu'à ce que tu le lui "
        .. "révèles : c'est pour les endroits qui doivent se mériter.")

    f.reveler = UI.Bouton(f.contenu, "Révéler à…", 110, 20, function()
        Ecran.choix = Ecran.choix or UI.ChoixJoueurs("lieux_reveler")
        local lieuId, seuilId = Ecran.lieu, Ecran.seuil
        Ecran.choix:Proposer("Révéler ce lieu à", function(noms)
            if #noms == 0 then return false, "personne de sélectionné." end
            for _, nom in ipairs(noms) do L().Reveler(lieuId, nom, seuilId) end
            LCM.Ok(string.format("révélé à %d joueur(s).", #noms))
            return true
        end)
    end)
    Poser(f.reveler, 150)

    f.ajouterSeuil = UI.Bouton(f.contenu, "+ Seuil ici", 110, 20, function()
        local seuil, raison = L().CreerSeuil(Ecran.lieu)
        if not seuil then LCM.Alerte(tostring(raison)) return end
        Ecran.seuil = seuil.id
        LCM.Ok("seuil posé ici — il reste à le compléter.")
        f:Afficher()
    end)
    f.ajouterSeuil:SetPoint("LEFT", f.reveler, "RIGHT", 6, 0)

    -- La banniere du lieu : tous ses seuils en heritent, sauf ceux qui
    -- choisissent la leur.
    f.themeLabel = Etiquette("Bannière", 180)
    f.theme = UI.Bouton(f.contenu, "", 200, 20, function(bouton)
        local options = { { id = "", label = "— rendu d'origine —" } }
        for _, t in ipairs(LCM.Bannieres.Liste()) do
            options[#options + 1] = { id = t.id, label = tostring(t.nom) }
        end
        Ecran.choixTheme = Ecran.choixTheme or UI.Choix("lieux_theme", "Bannière")
        Ecran.choixTheme:Proposer(bouton, options, function(id)
            Dire(L().ThemeDuLieu(Ecran.lieu, id))
            f:Afficher()
        end)
    end)
    Poser(f.theme, 178, 64)
    f.atelierTheme = UI.Bouton(f.contenu, "Atelier…", 80, 20, function()
        local lieu = L().Get(Ecran.lieu)
        if MJ.Bannieres then MJ.Bannieres.Basculer(lieu and lieu.theme) end
    end)
    f.atelierTheme:SetPoint("LEFT", f.theme, "RIGHT", 6, 0)

    f.retirerLieu = UI.Bouton(f.contenu, "Retirer le lieu", 110, 20, function()
        local lieu = L().Get(Ecran.lieu)
        if not lieu then return end
        f.confirmation:Demander(string.format("Retirer « %s » et ses seuils ?", tostring(lieu.nom)),
            function()
                if Dire(L().Retirer(Ecran.lieu)) then
                    Ecran.lieu, Ecran.seuil = nil, nil
                    f:Afficher()
                end
            end)
    end)
    f.retirerLieu:SetPoint("LEFT", f.ajouterSeuil, "RIGHT", 6, 0)

    -- ----- ce qui n'appartient qu'au SEUIL ---------------------------------
    f.formeLabel = Etiquette("Forme", 94)
    f.formes = {}
    local dx = 44
    for _, forme in ipairs(L().ORDRE_FORMES) do
        local b = UI.Bouton(f.contenu, L().FORMES[forme], 82, 20, function()
            Dire(L().Forme(Ecran.seuil, forme))
            f:Afficher()
        end)
        Poser(b, 92, dx)
        b.forme = forme
        f.formes[#f.formes + 1] = b
        dx = dx + 86
    end

    -- Le radar, et les commandes de pose juste a sa droite.
    f.radar = ConstruireRadar(f.contenu)
    Poser(f.radar, 124)

    f.distance = UI.Texte(f.contenu, "", UI.C.discret)
    UI.Police(f.distance, 11)
    Poser(f.distance, 124 + RADAR + 6)
    f.distance:SetWidth(RADAR)
    f.distance:SetJustifyH("CENTER")
    f.distance:SetWordWrap(true)

    -- La porte.
    f.borneA = UI.Bouton(f.contenu, "1re borne ici", 136, 22, function()
        if Dire(L().Recapturer(Ecran.seuil)) then LCM.Ok("première borne posée ici.") end
        f:Afficher()
    end)
    PoserB(f.borneA, 124)
    f.borneB = UI.Bouton(f.contenu, "2e borne ici", 136, 22, function()
        if Dire(L().PoserBorne(Ecran.seuil)) then LCM.Ok("seconde borne posée : la porte est faite.") end
        f:Afficher()
    end)
    PoserB(f.borneB, 124, 142)
    f.inverser = UI.Bouton(f.contenu, "Inverser le sens", 136, 22, function()
        Dire(L().Inverser(Ecran.seuil))
        f:Afficher()
    end)
    PoserB(f.inverser, 152)
    UI.Bulle(f.inverser, "Sens",
        "Quel côté de la porte compte comme « dedans ». Le radar l'affiche : "
        .. "ENTRÉE du côté où l'on entre, RETOUR de l'autre.")
    f.debordLabel = Etiquette("Débord", 184, 0, "b")
    f.debord = UI.Champ(f.contenu, 50, 20, nil)
    PoserB(f.debord, 182, 50)
    f.debordOk = UI.Bouton(f.contenu, "OK", 34, 20, function()
        Dire(L().Debord(Ecran.seuil, f.debord:GetText()))
        f:Afficher()
    end)
    f.debordOk:SetPoint("LEFT", f.debord, "RIGHT", 6, 0)
    f.debordAide = UI.Texte(f.contenu, "Mètres tolérés au-delà des deux bornes : "
        .. "on ne passe jamais exactement entre les piquets.", UI.C.discret)
    UI.Police(f.debordAide, 10)
    PoserB(f.debordAide, 208)
    f.debordAide:SetWidth(largeurB)
    f.debordAide:SetJustifyH("LEFT")
    f.debordAide:SetWordWrap(true)

    -- Le cercle.
    f.centre = UI.Bouton(f.contenu, "Centre ici", 136, 22, function()
        if Dire(L().Recapturer(Ecran.seuil)) then LCM.Ok("centre posé ici.") end
        f:Afficher()
    end)
    PoserB(f.centre, 124)
    f.rayonLabel = Etiquette("Rayon", 154, 0, "b")
    f.rayon = UI.Champ(f.contenu, 50, 20, nil)
    PoserB(f.rayon, 152, 44)
    f.rayonOk = UI.Bouton(f.contenu, "OK", 34, 20, function()
        Dire(L().Rayon(Ecran.seuil, f.rayon:GetText()))
        f:Afficher()
    end)
    f.rayonOk:SetPoint("LEFT", f.rayon, "RIGHT", 6, 0)
    f.rayonAide = UI.Texte(f.contenu, "Mètres. Le disque sur le radar est à l'échelle.",
        UI.C.discret)
    UI.Police(f.rayonAide, 10)
    PoserB(f.rayonAide, 178)
    f.rayonAide:SetWidth(largeurB)
    f.rayonAide:SetJustifyH("LEFT")
    f.rayonAide:SetWordWrap(true)

    -- La region.
    f.point = UI.Bouton(f.contenu, "+ Point ici", 136, 22, function()
        if Dire(L().AjouterPoint(Ecran.seuil)) then f:Afficher() end
    end)
    PoserB(f.point, 124)
    f.pointMoins = UI.Bouton(f.contenu, "Retirer le dernier", 136, 22, function()
        if Dire(L().RetirerPoint(Ecran.seuil)) then f:Afficher() end
    end)
    PoserB(f.pointMoins, 124, 142)
    f.vider = UI.Bouton(f.contenu, "Tout effacer", 136, 22, function()
        if Dire(L().ViderPoints(Ecran.seuil)) then f:Afficher() end
    end)
    PoserB(f.vider, 152)
    -- `valider`, et surtout PAS `fermer` : la fenetre appelle `f.fermer` sa
    -- croix de fermeture, et `PlacerCoinsHaut` la replace dans l'encoche du
    -- coin a chaque fois que l'habillage se redispose. Le champ pris, c'est ce
    -- bouton-ci qui partait dans le coin, a la taille d'une croix.
    f.valider = UI.Bouton(f.contenu, "Valider la région", 136, 22, function()
        local seuil = L().Seuil(Ecran.seuil)
        if seuil and seuil.ferme then Dire(L().Rouvrir(Ecran.seuil))
        else Dire(L().Fermer(Ecran.seuil)) end
        f:Afficher()
    end)
    PoserB(f.valider, 152, 142)
    f.points = UI.Texte(f.contenu, "", UI.C.discret)
    UI.Police(f.points, 11)
    PoserB(f.points, 184)
    f.points:SetWidth(largeurB)
    f.points:SetJustifyH("LEFT")
    f.points:SetWordWrap(true)

    -- Commun a toutes les formes.
    local Y = 124 + RADAR + 42
    f.actif = UI.Case(f.contenu, "Seuil actif", function(cochee)
        Dire(L().Activer(Ecran.seuil, cochee))
        f:Afficher()
    end)
    Poser(f.actif, Y)
    f.entree = UI.Case(f.contenu, "Bannière en entrant", function(cochee)
        Dire(L().Sens(Ecran.seuil, "entree", cochee))
        f:Afficher()
    end)
    Poser(f.entree, Y + 24)
    f.retour = UI.Case(f.contenu, "Bannière en sortant", function(cochee)
        Dire(L().Sens(Ecran.seuil, "retour", cochee))
        f:Afficher()
    end)
    Poser(f.retour, Y + 24, 200)

    -- La banniere de CE seuil. Vide : celle du lieu.
    f.themeSeuilLabel = Etiquette("Bannière", Y + 50)
    f.themeSeuil = UI.Bouton(f.contenu, "", 200, 20, function(bouton)
        local options = { { id = "", label = "— celle du lieu —" } }
        for _, t in ipairs(LCM.Bannieres.Liste()) do
            options[#options + 1] = { id = t.id, label = tostring(t.nom) }
        end
        Ecran.choixTheme = Ecran.choixTheme or UI.Choix("lieux_theme", "Bannière")
        Ecran.choixTheme:Proposer(bouton, options, function(id)
            Dire(L().ThemeDuSeuil(Ecran.seuil, id))
            f:Afficher()
        end)
    end)
    Poser(f.themeSeuil, Y + 48, 64)
    f.atelierSeuil = UI.Bouton(f.contenu, "Atelier…", 80, 20, function()
        local seuil = L().Seuil(Ecran.seuil)
        if MJ.Bannieres then MJ.Bannieres.Basculer(seuil and seuil.theme) end
    end)
    f.atelierSeuil:SetPoint("LEFT", f.themeSeuil, "RIGHT", 6, 0)

    f.messageLabel = Etiquette("Message au franchissement", Y + 78)
    f.message = UI.Champ(f.contenu, largeur - 56, 20, nil)
    Poser(f.message, Y + 96)
    f.messageOk = UI.Bouton(f.contenu, "OK", 44, 20, function()
        Dire(L().Message(Ecran.seuil, f.message:GetText()))
        f:Afficher()
    end)
    f.messageOk:SetPoint("LEFT", f.message, "RIGHT", 6, 0)
    f.messageAide = UI.Texte(f.contenu,
        "Imprimé dans le chat de celui qui franchit, et de lui seul.", UI.C.discret)
    UI.Police(f.messageAide, 10)
    Poser(f.messageAide, Y + 120)
    f.messageAide:SetWidth(largeur)
    f.messageAide:SetJustifyH("LEFT")

    f.retirerSeuil = UI.Bouton(f.contenu, "Retirer le seuil", 120, 20, function()
        local seuil = L().Seuil(Ecran.seuil)
        if not seuil then return end
        f.confirmation:Demander(string.format("Retirer le seuil « %s » ?", tostring(seuil.nom)),
            function()
                if Dire(L().RetirerSeuil(Ecran.seuil)) then
                    Ecran.seuil = nil
                    f:Afficher()
                end
            end)
    end)
    Poser(f.retirerSeuil, Y + 140)

    f.confirmation = UI.Confirmer(f, "", "Retirer")

    f.volets = {
        lieu = { f.couleurLabel, f.couleur, f.couleurOk, f.couleurAide, f.decouverte,
                 f.themeLabel, f.theme, f.atelierTheme,
                 f.reveler, f.ajouterSeuil, f.retirerLieu },
        seuil = { f.formeLabel, f.radar, f.distance, f.actif, f.entree, f.retour,
                  f.themeSeuilLabel, f.themeSeuil, f.atelierSeuil,
                  f.messageLabel, f.message, f.messageOk, f.messageAide, f.retirerSeuil },
        porte = { f.borneA, f.borneB, f.inverser, f.debordLabel, f.debord, f.debordOk,
                  f.debordAide },
        cercle = { f.centre, f.rayonLabel, f.rayon, f.rayonOk, f.rayonAide },
        region = { f.point, f.pointMoins, f.vider, f.valider, f.points },
    }

    local function Montrer(nom, visible)
        for _, w in ipairs(f.volets[nom]) do
            w:SetShown(visible)
            -- Le libelle d'une case vit sur le parent, pas dans la case : il ne
            -- suit pas tout seul quand on cache le volet.
            if w.coche and w.label then w.label:SetShown(visible) end
        end
        if nom == "seuil" then
            for _, b in ipairs(f.formes) do b:SetShown(visible) end
        end
    end
    f.Montrer = Montrer

    -- ----- le radar, rafraichi ----------------------------------------------
    function f:Dessiner()
        local r = self.radar
        r:Effacer()
        local seuil = Ecran.seuil and L().Seuil(Ecran.seuil) or nil
        if not seuil then
            self.distance:SetText("")
            return
        end

        local D = LCM.DeplacementForce
        -- Surtout PAS `local px, py = D and D.Position(...)` : en affectation
        -- multiple, une chaine `and` est ajustee a UNE valeur, et py resterait
        -- nil. Le piege est deja documente dans CLAUDE.md.
        local px, py
        if D and D.Position then px, py = D.Position(seuil.source) end
        local carte = D and D.Carte and D.Carte()
        if not px then
            self.distance:SetText(string.format(
                "Position « %s » indisponible ici : le radar ne peut rien montrer.",
                tostring(seuil.source)))
            return
        end
        if seuil.carte ~= carte then
            self.distance:SetText(string.format("Ce seuil est sur la carte %s ; tu es sur la %s.",
                tostring(seuil.carte or "?"), tostring(carte or "?")))
            return
        end

        local dr, dh, mesuree = L().Boussole(carte, seuil.source)
        -- Le nord mesure se porte en clair ; le nord suppose se signale.
        r.nord:SetText(mesuree and "N" or "N ?")
        local teinte = mesuree and UI.C.accent or UI.C.discret
        r.nord:SetTextColor(teinte[1], teinte[2], teinte[3])

        -- Vue egocentrique : ce que regarde le personnage est en haut. Sans
        -- ca, on tourne sur soi-meme en cherchant de quel cote est la porte.
        local cap = L().Cap()
        local cosCap, sinCap = 1, 0
        if cap then cosCap, sinCap = math.cos(cap), math.sin(cap) end
        r.regard:SetShown(cap ~= nil)
        -- Le nord part se placer sur le pourtour, a l'oppose du cap.
        local rayonNord = RADAR / 2 - 12
        r.nord:ClearAllPoints()
        r.nord:SetPoint("CENTER", r, "CENTER", -rayonNord * sinCap, rayonNord * cosCap)
        -- Un point du monde, vu du radar : decalage par rapport a MOI, projete
        -- sur les axes de l'ecran, puis mis a l'echelle.
        local echelle = 1
        local function Brut(x, y)
            local ax, ay = x - px, y - py
            return dr[1] * ax + dr[2] * ay, dh[1] * ax + dh[2] * ay
        end
        local function Vers(x, y)
            -- `Brut` rend le decalage nord-en-haut ; on le fait tourner de
            -- l'oppose du cap pour mettre le regard du personnage en haut.
            local sx, sy = Brut(x, y)
            return (sx * cosCap - sy * sinCap) * echelle,
                   (sy * cosCap + sx * sinCap) * echelle
        end

        -- Choisir l'echelle : la plus serree qui fasse tenir tout le seuil.
        local etendue = 0
        local function Compter(x, y)
            local sx, sy = Brut(x, y)
            etendue = math.max(etendue, math.sqrt(sx * sx + sy * sy))
        end
        if seuil.forme == "porte" then
            if seuil.ax then Compter(seuil.ax, seuil.ay) end
            if seuil.bx then Compter(seuil.bx, seuil.by) end
        elseif seuil.forme == "cercle" then
            Compter(seuil.x, seuil.y)
            etendue = etendue + (tonumber(seuil.rayon) or 0)
        else
            for _, p in ipairs(seuil.points or {}) do Compter(p.x, p.y) end
        end
        local utile = RADAR / 2 - 10
        for _, e in ipairs(ECHELLES) do
            echelle = e
            if etendue * e <= utile then break end
        end
        r.echelle:SetText(string.format("%d m", math.floor(utile / echelle + 0.5)))

        if seuil.forme == "porte" then
            if seuil.ax and seuil.bx then
                local xa, ya = r:Poser(r.borneA, Vers(seuil.ax, seuil.ay))
                local xb, yb = r:Poser(r.borneB, Vers(seuil.bx, seuil.by))
                Segment(r.porte, xa, ya, xb, yb)
                -- Les deux cotes, nommes : la normale a gauche de A -> B est le
                -- « dedans » quand le sens vaut 1 (meme calcul que Lieux.Cote).
                local vx, vy = xb - xa, yb - ya
                local n = math.sqrt(vx * vx + vy * vy)
                if n > 0 then
                    local nx, ny = -vy / n, vx / n
                    local sens = (seuil.sens == -1) and -1 or 1
                    local mx, my = (xa + xb) / 2, (ya + yb) / 2
                    local d = 16
                    r:Poser(r.dedans, mx + nx * d * sens, my + ny * d * sens)
                    r:Poser(r.dehors, mx - nx * d * sens, my - ny * d * sens)
                end
            elseif seuil.ax then
                r:Poser(r.borneA, Vers(seuil.ax, seuil.ay))
            end
        elseif seuil.forme == "cercle" then
            local cx, cy = Vers(seuil.x, seuil.y)
            local rayon = (tonumber(seuil.rayon) or 0) * echelle
            r.disque:ClearAllPoints()
            r.disque:SetSize(math.max(4, rayon * 2), math.max(4, rayon * 2))
            r.disque:SetPoint("CENTER", r, "CENTER", cx, cy)
            r.disque:Show()
            r:Poser(r.centre, cx, cy)
        else
            local pts = seuil.points or {}
            local ecran = {}
            for i, p in ipairs(pts) do
                if i > 20 then break end
                local x, y = r:Poser(r.points[i], Vers(p.x, p.y))
                ecran[i] = { x, y }
            end
            for i = 1, #ecran - 1 do
                Segment(r.aretes[i], ecran[i][1], ecran[i][2], ecran[i + 1][1], ecran[i + 1][2])
            end
            -- La boucle de fermeture n'apparait que si la region est validee :
            -- le contour ouvert doit SE VOIR ouvert.
            if seuil.ferme and #ecran >= 3 then
                Segment(r.aretes[#ecran], ecran[#ecran][1], ecran[#ecran][2], ecran[1][1], ecran[1][2])
            end
        end

        -- Sous le radar : a quelle distance, et de quel cote.
        local bouts = {}
        local distance = L().Distance(seuil)
        if distance then bouts[#bouts + 1] = string.format("à %d m", math.floor(distance + 0.5)) end
        local portee, cote = L().Etat(seuil)
        if portee == nil then bouts[#bouts + 1] = "hors de portée"
        elseif not portee then bouts[#bouts + 1] = "sur le seuil même"
        else bouts[#bouts + 1] = (cote == "dedans") and "tu es dedans" or "tu es dehors" end
        self.distance:SetText(table.concat(bouts, " — "))
    end

    -- La ligne du haut : la carte et la source, qui valent pour tout le volet.
    function f:Pouls()
        local D = LCM.DeplacementForce
        local carte = D and D.Carte and D.Carte()
        local source, x, y
        if D and D.Position then
            local px, py, _, trouvee = D.Position()
            if px then source, x, y = trouvee, px, py end
        end

        -- Mesurer le nord, c'est regarder marcher le MJ : rien a lui demander,
        -- il marche de toute facon pour poser ses bornes. Deux deplacements
        -- non paralleles, et c'est su pour cette carte, une fois pour toutes.
        if source then
            L().Calibrer(source, x, y)
            -- Le cap se mesure au meme prix : en le regardant marcher.
            L().CalibrerCap(source, x, y)
        end

        local bouts = { string.format("Carte %s", carte and tostring(carte) or "?") }
        bouts[#bouts + 1] = source and ("position : " .. source)
            or "position indisponible ici"
        if source then
            local _, _, mesuree = L().Boussole(carte, source)
            bouts[#bouts + 1] = mesuree and "nord mesuré"
                or "nord par convention — marche un peu pour le mesurer"
            local _, capMesure = L().Cap()
            if capMesure == false then
                bouts[#bouts + 1] = "cap par convention"
            elseif capMesure then
                bouts[#bouts + 1] = "cap mesuré"
            end
        end
        self.etat:SetText(table.concat(bouts, " — "))
        if Ecran.seuil then self:Dessiner() end
    end

    function f:Afficher()
        if not LCM.IsMaster() then
            self.vide:SetText("Réservé au maître du jeu.")
            return
        end

        local lieux = L().Liste()
        local rang, y = 0, 0
        for _, lieu in ipairs(lieux) do
            rang = rang + 1
            local l = LigneArbre(self, rang)
            l.lieuId, l.seuilId = lieu.id, nil
            local seuils = L().Seuils(lieu.id)
            l.nom:SetText(tostring(lieu.nom))
            l.note:SetText(tostring(#seuils))
            local choisi = (Ecran.lieu == lieu.id and not Ecran.seuil)
            local couleur = choisi and UI.C.accent or UI.C.titre
            l.nom:SetTextColor(couleur[1], couleur[2], couleur[3])
            l.nom:SetPoint("LEFT", l, "LEFT", 6, 0)
            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", self.arbre.contenu, "TOPLEFT", 0, -y)
            l:SetPoint("TOPRIGHT", self.arbre.contenu, "TOPRIGHT", 0, -y)
            l:Show()
            y = y + LIGNE

            for _, seuil in ipairs(seuils) do
                rang = rang + 1
                local s = LigneArbre(self, rang)
                s.lieuId, s.seuilId = lieu.id, seuil.id
                s.nom:SetText(tostring(seuil.nom))
                -- Un seuil inerte doit se voir DANS LA LISTE : un « il manque
                -- la seconde borne » qu'il faut aller chercher en cliquant, on
                -- l'oublie et on croit sa porte posee.
                local complet = L().Complet(seuil)
                if not complet then s.note:SetText("à finir")
                elseif not seuil.actif then s.note:SetText("éteint")
                else s.note:SetText(L().FORMES[seuil.forme] or "") end
                local vif = (Ecran.seuil == seuil.id)
                local c = vif and UI.C.accent
                    or ((complet and seuil.actif) and UI.C.texte or UI.C.discret)
                s.nom:SetTextColor(c[1], c[2], c[3])
                s.nom:SetPoint("LEFT", s, "LEFT", 20, 0)
                s:ClearAllPoints()
                s:SetPoint("TOPLEFT", self.arbre.contenu, "TOPLEFT", 0, -y)
                s:SetPoint("TOPRIGHT", self.arbre.contenu, "TOPRIGHT", 0, -y)
                s:Show()
                y = y + LIGNE
            end
        end
        for r = rang + 1, #self.lignes do self.lignes[r]:Hide() end
        self.arbre:Regler(math.max(1, y))
        self.vide:SetText(#lieux > 0 and ""
            or "Aucun lieu. Nomme-en un, puis va poser ses seuils sur le terrain.")

        -- La selection a pu disparaitre (retrait, ou un lieu recu remplace).
        local lieu = Ecran.lieu and L().Get(Ecran.lieu) or nil
        if not lieu then Ecran.lieu, Ecran.seuil = nil, nil end
        local seuil = Ecran.seuil and L().Seuil(Ecran.seuil) or nil
        if not seuil then Ecran.seuil = nil end

        local aLieu, aSeuil = lieu ~= nil, seuil ~= nil
        -- Un lieu recu d'un autre MJ se LIT : ses commandes sont cachees, pas
        -- grisees — le skin du modele ne dessine pas l'etat grise, et on
        -- cliquerait sur des boutons d'apparence normale qui ne repondent pas.
        local mien = lieu ~= nil and L().AMoi(lieu)
        Montrer("lieu", aLieu and not aSeuil and mien)
        Montrer("seuil", aSeuil)
        Montrer("porte", aSeuil and mien and seuil.forme == "porte")
        Montrer("cercle", aSeuil and mien and seuil.forme == "cercle")
        Montrer("region", aSeuil and mien and seuil.forme == "region")
        for _, b in ipairs(self.formes) do b:SetShown(aSeuil and mien) end
        self.formeLabel:SetShown(aSeuil and mien)
        self.nomLabel:SetShown(aLieu and mien)
        self.nom:SetShown(aLieu and mien)
        self.renommer:SetShown(aLieu and mien)
        self.retirerSeuil:SetShown(aSeuil and mien)
        self.themeSeuilLabel:SetShown(aSeuil and mien)
        self.themeSeuil:SetShown(aSeuil and mien)
        self.atelierSeuil:SetShown(aSeuil and mien)
        self.messageLabel:SetShown(aSeuil and mien)
        self.message:SetShown(aSeuil and mien)
        self.messageOk:SetShown(aSeuil and mien)
        self.messageAide:SetShown(aSeuil and mien)
        for _, w in ipairs({ self.actif, self.entree, self.retour }) do
            w:SetShown(aSeuil and mien)
            w.label:SetShown(aSeuil and mien)
        end

        if not aLieu then
            self.cible:SetText("")
            self.etat:SetText("")
            self.manque:SetText("")
            self.distance:SetText("")
            self.radar:Effacer()
            return
        end

        if aSeuil then
            self.cible:SetText(string.format("%s  —  %s", tostring(seuil.nom), tostring(lieu.nom)))
            if not self.nom:HasFocus() then self.nom:SetText(tostring(seuil.nom)) end
            local complet, manque = L().Complet(seuil)
            self.manque:SetText(complet and "" or tostring(manque))
            for _, b in ipairs(self.formes) do b:Selectionner(b.forme == seuil.forme) end
            if not self.debord:HasFocus() then self.debord:SetText(tostring(seuil.debord or "")) end
            if not self.rayon:HasFocus() then self.rayon:SetText(tostring(seuil.rayon or "")) end
            if not self.message:HasFocus() then self.message:SetText(tostring(seuil.message or "")) end
            self.actif:Cocher(seuil.actif)
            self.entree:Cocher(seuil.entree)
            self.retour:Cocher(seuil.retour)
            local n = seuil.points and #seuil.points or 0
            if seuil.ferme then
                self.points:SetText(string.format("%d point(s), contour fermé.", n))
                self.valider.label:SetText("Rouvrir le contour")
            else
                self.points:SetText(n >= 3
                    and string.format("%d point(s). Valide pour fermer le contour.", n)
                    or string.format("%d point(s) — il en faut au moins 3.", n))
                self.valider.label:SetText("Valider la région")
            end
            -- La seconde borne d'abord : tant qu'elle manque, c'est le seul
            -- geste qui fasse avancer la porte.
            self.borneB.label:SetText(seuil.bx and "Redéplacer la 2e" or "2e borne ici")
            local sienTheme = seuil.theme and LCM.Bannieres.Get(seuil.theme)
            self.themeSeuil.label:SetText(sienTheme and tostring(sienTheme.nom)
                or "— celle du lieu —")
        else
            local seuils = L().Seuils(lieu.id)
            self.cible:SetText(tostring(lieu.nom))
            if not self.nom:HasFocus() then self.nom:SetText(tostring(lieu.nom)) end
            self.manque:SetText(mien and "" or string.format(
                "Ce lieu est à %s : on peut le lire, pas le modifier.", tostring(lieu.auteur)))
            if not self.couleur:HasFocus() then self.couleur:SetText(tostring(lieu.couleur or "")) end
            self.decouverte:Cocher(lieu.decouverte)
            local sonTheme = lieu.theme and LCM.Bannieres.Get(lieu.theme)
            self.theme.label:SetText(sonTheme and tostring(sonTheme.nom)
                or "— rendu d'origine —")
            self.distance:SetText("")
            self.radar:Effacer()
            -- Un lieu sans seuil n'a rien a reveler.
            self.reveler:SetShown(mien and #seuils > 0)
        end

        self:Pouls()
    end

    -- Le pouls tourne tant que la fenetre est ouverte, et seulement alors.
    f:SetScript("OnUpdate", function(self, ecoule)
        self.reste = (self.reste or 0) + (tonumber(ecoule) or 0)
        if self.reste < POULS then return end
        self.reste = 0
        if Ecran.lieu then self:Pouls() end
    end)

    function f:Montrer()
        self:Afficher()
        self:Show()
    end

    return f
end

function Ecran.Fenetre()
    if not Ecran.frame then Construire() end
    return Ecran.frame
end

function Ecran.Basculer()
    local f = Ecran.Fenetre()
    if f:IsShown() then f:Hide() else f:Montrer() end
    return f
end

LCM.WhenReady(function()
    UI.Menu.Lier("lieux", Ecran.Basculer)
    LCM.AddCommand("atelier-lieux", "l'atelier des lieux", function()
        Ecran.Basculer()
    end, true)

    -- Un lieu recu ou retire d'ailleurs rafraichit l'atelier : deux MJ dans le
    -- groupe regardent la meme carte.
    local avant = LCM.Lieux.onChange
    LCM.Lieux.onChange = function(...)
        if avant then avant(...) end
        if Ecran.frame and Ecran.frame:IsShown() then Ecran.frame:Afficher() end
    end
end)
