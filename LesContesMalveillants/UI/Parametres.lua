-- Les parametres.
--
-- Le template declare une fenetre `settings` sans en dire le contenu : il n'y a
-- donc rien a recopier, et cette fenetre montre ce que l'addon sait vraiment
-- regler. Trois sections, et pas une de plus — une fenetre de parametres qui
-- grossit est une fenetre que personne ne lit.
--
-- « Depannage » merite son nom : une fenetre perdue hors de l'ecran et un envoi
-- reseau tombe en route sont les deux pannes qu'on ne peut pas diagnostiquer
-- sans outil, et qui coutent une seance.

local _, LCM = ...
local UI = LCM.UI

local Ecran = {}
UI.Parametres = Ecran

local LARGEUR, HAUTEUR = 460, 420
local LIGNE = 26

local function Construire()
    local f = UI.Fenetre("parametres", "Paramètres", LARGEUR, HAUTEUR, { x = -60, y = 40 })
    Ecran.frame = f

    local y = 0
    local function Titre(texte)
        local h = UI.EnTeteGroupe(f.contenu, texte)
        h:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -y)
        h:SetPoint("TOPRIGHT", f.contenu, "TOPRIGHT", 0, -y)
        h.budget:SetText("")
        y = y + 24
        return h
    end
    local function Case(libelle, onChange)
        local c = UI.Case(f.contenu, libelle, onChange)
        c:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 4, -y)
        y = y + LIGNE
        return c
    end
    local function Bouton(libelle, largeur, onClick)
        local b = UI.Bouton(f.contenu, libelle, largeur, 22, onClick)
        b:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 4, -y)
        y = y + 28
        return b
    end
    local function Ligne(couleur)
        local fs = UI.Texte(f.contenu, "", couleur or UI.C.discret)
        UI.Police(fs, 11)
        fs:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 4, -y)
        fs:SetPoint("TOPRIGHT", f.contenu, "TOPRIGHT", 0, -y)
        y = y + 18
        return fs
    end

    Titre("AFFICHAGE")
    f.sceau = Case("Afficher le sceau du lanceur d'actions", function(coche)
        UI.Radial.Afficher(coche)
    end)
    f.replacer = Bouton("Remettre les fenêtres à leur place", 230, function()
        local nombre = UI.ReplacerFenetres()
        LCM.Ok(string.format("%d fenêtre%s replacée%s.", nombre,
            nombre > 1 and "s" or "", nombre > 1 and "s" or ""))
    end)
    y = y + 8

    Titre("PERSONNAGE")
    f.joue = Ligne(UI.C.texte)
    f.choisir = Bouton("Choisir un personnage", 180, function()
        if UI.Personnages then UI.Personnages.Ouvrir() end
    end)
    y = y + 8

    Titre("DÉPANNAGE")
    f.traces = Case("Traces de développement", function(coche)
        LCM.EnsureDatabase()
        LCM.db.settings.debug = coche or nil
    end)
    f.version = Ligne()
    f.reseau = Ligne()
    f.attente = Ligne()

    function f:Actualiser()
        local radial = UI.Radial and UI.Radial.frame
        self.sceau:Cocher(not (LCM.db.settings and LCM.db.settings.radialCache))

        local moi = LCM.Entities.Self()
        self.joue:SetText(moi and string.format("Tu joues %s.", tostring(moi.name))
                              or "Aucun personnage choisi.")

        self.traces:Cocher(LCM.db.settings and LCM.db.settings.debug or false)
        self.version:SetText(string.format("Version %s — %s", tostring(LCM.version),
            LCM.IsMaster() and "maître du jeu" or "joueur"))

        -- Si le prefixe n'est pas enregistre, RIEN n'arrive, et aucun message
        -- d'erreur ne le dit : c'est exactement le genre de panne muette qu'on
        -- veut pouvoir lire ici.
        local enregistre = true
        if C_ChatInfo and C_ChatInfo.IsAddonMessagePrefixRegistered then
            enregistre = C_ChatInfo.IsAddonMessagePrefixRegistered(LCM.Reseau.PREFIXE) and true or false
        end
        self.reseau:SetText(string.format("Réseau : préfixe %s %s",
            LCM.Reseau.PREFIXE, enregistre and "enregistré" or "|cffe86b6bnon enregistré|r"))

        local attente = LCM.Reseau.EnAttente()
        self.attente:SetText(attente == 0 and "Aucun message en attente."
            or string.format("|cffe8b451%d message(s) incomplet(s)|r — un morceau n'est pas arrivé.", attente))
    end

    function f:Montrer()
        self:Actualiser()
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

LCM.AddCommand("parametres", "ouvre les parametres", function() Ecran.Basculer() end)

LCM.WhenReady(function()
    UI.Menu.Lier("parametres", Ecran.Basculer)
end)
