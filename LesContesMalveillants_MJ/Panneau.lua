-- Le panneau du maitre du jeu.
--
-- Il vit dans le COMPAGNON, et pas dans l'addon principal : c'est la seule
-- protection qui vaille. Un joueur n'a pas ce dossier, donc il n'a pas ce
-- code — le reste (verifications, droits) n'arrete que les curieux.
--
-- Pour l'instant : la liste du groupe, la fiche de chacun sur demande, et
-- l'acces a la fenetre de combat. La
-- consultation est a sens unique, et le joueur consulte en est prevenu
-- (Core/Fiches.lua) : on regarde par-dessus l'epaule, pas dans le dos.

local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end

local UI = LCM.UI
local Ecran = {}
UI.PanneauMJ = Ecran
MJ.Panneau = Ecran

local LARGEUR, HAUTEUR = 560, 460
local LIGNE = 26

-- Le groupe, vu d'ici. Hors groupe, la liste est vide et la fenetre le dit —
-- plutot que de laisser croire a une panne.
local function Groupe()
    local out = {}
    if not (GetNumGroupMembers and UnitName) then return out end
    local nombre = GetNumGroupMembers() or 0
    if nombre == 0 then return out end
    local prefixe = (IsInRaid and IsInRaid()) and "raid" or "party"
    local moi = LCM.PlayerId()
    for index = 1, nombre do
        local nom, royaume = UnitName(prefixe .. index)
        if nom then
            local complet = (royaume and royaume ~= "" and (nom .. "-" .. royaume)) or nom
            if complet ~= moi then out[#out + 1] = complet end
        end
    end
    table.sort(out)
    return out
end
Ecran.Groupe = Groupe

local function Construire()
    local f = UI.Fenetre("panneau_mj", "Panel MJ", LARGEUR, HAUTEUR, { x = 40, y = 20 })
    Ecran.frame = f

    f.rafraichir = UI.Bouton(f.contenu, "Rafraîchir le groupe", 160, 22, function() f:Afficher() end)
    f.rafraichir:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)

    f.etat = UI.Texte(f.contenu, "", UI.C.discret)
    UI.Police(f.etat, 11)
    f.etat:SetPoint("LEFT", f.rafraichir, "RIGHT", 10, 0)

    -- Le combat se mene depuis ici, comme l'initiative dans la fenetre du MJ
    -- de Necronicon : le menu suit le template, qui n'a pas de fenetre de
    -- combat. Resolu au clic : Combat.lua se charge apres ce fichier.
    f.combat = UI.Bouton(f.contenu, "Combat", 100, 22, function()
        if UI.CombatMJ then UI.CombatMJ.Basculer() end
    end)
    f.combat:SetPoint("TOPRIGHT", f.contenu, "TOPRIGHT", 0, 0)

    f.zone = UI.Defilement(f.contenu)
    f.zone:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -30)
    f.zone:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 0)
    -- Pourquoi on donne : le meme pour tout le monde a la fin d'une scene, donc
    -- une seule case pour la tablee plutot qu'une par joueur.
    f.raisonLabel = UI.Texte(f.contenu, "Motif :", UI.C.discret)
    UI.Police(f.raisonLabel, 11)
    f.raison = UI.Champ(f.contenu, 220, 20, nil)
    f.raison:SetPoint("TOPRIGHT", f.contenu, "TOPRIGHT", 0, -28)
    f.raisonLabel:SetPoint("RIGHT", f.raison, "LEFT", -6, 0)

    f.lignes = {}

    f.vide = UI.Texte(f.contenu, "", UI.C.discret)
    UI.Police(f.vide, 11)
    f.vide:SetPoint("CENTER", f.zone, "CENTER", 0, 0)
    f.vide:SetJustifyH("CENTER")

    function f:Afficher()
        local membres = Groupe()
        local y, nombre = 0, 0
        for rang, joueur in ipairs(membres) do
            local l = self.lignes[rang]
            if not l then
                l = CreateFrame("Frame", nil, self.zone.contenu)
                l:SetHeight(LIGNE - 2)
                if UI.SurfaceLigne then UI.SurfaceLigne(l) end
                l.nom = UI.Texte(l, "", UI.C.texte)
                UI.Police(l.nom, 12)
                l.nom:SetPoint("LEFT", l, "LEFT", 6, 0)
                l.etat = UI.Texte(l, "", UI.C.discret)
                UI.Police(l.etat, 10)
                l.etat:SetPoint("LEFT", l.nom, "RIGHT", 10, 0)
                l.consulter = UI.Bouton(l, "Consulter", 90, 18, function()
                    local cible = self.lignes[rang].joueur
                    local entity = LCM.Fiches.Recue(cible)
                    if entity then
                        UI.Fiche.Fenetre():Montrer(entity)
                        return
                    end
                    local ok, raison = LCM.Fiches.Demander(cible)
                    if not ok then LCM.Alerte(tostring(raison)) return end
                    LCM.Info(string.format("fiche demandee a %s…", cible))
                end)
                l.consulter:SetPoint("RIGHT", l, "RIGHT", -6, 0)
                -- Donner de l'experience : le montant se tape a cote du nom,
                -- et le bouton l'envoie. Pas de menu, pas de fenetre a part —
                -- c'est un geste de fin de scene, repete, sur plusieurs
                -- joueurs d'affilee.
                l.xp = UI.Champ(l, 48, 18, nil)
                l.xp:SetPoint("RIGHT", l.consulter, "LEFT", -6, 0)
                l.xp:SetNumeric(true)
                l.donner = UI.Bouton(l, "+ XP", 50, 18, function()
                    local ligne = self.lignes[rang]
                    local montant = tonumber(ligne.xp:GetText())
                    if not montant or montant <= 0 then
                        LCM.Alerte("indique d'abord combien d'expérience.")
                        return
                    end
                    local ok, raison = LCM.Experience.Envoyer(ligne.joueur, montant, f.raison:GetText())
                    if not ok then LCM.Alerte(tostring(raison)) return end
                    LCM.Ok(string.format("%d XP envoyés à %s.", montant, ligne.joueur))
                    ligne.xp:SetText("")
                end)
                l.donner:SetPoint("RIGHT", l.xp, "LEFT", -4, 0)
                self.lignes[rang] = l
            end
            l.joueur = joueur
            l.nom:SetText(joueur)
            local recue, perimee = LCM.Fiches.Recue(joueur)
            l.etat:SetText(recue and "fiche reçue" or (perimee and "fiche périmée" or ""))
            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", self.zone.contenu, "TOPLEFT", 0, -y)
            l:SetPoint("TOPRIGHT", self.zone.contenu, "TOPRIGHT", 0, -y)
            l:Show()
            y = y + LIGNE
            nombre = rang
        end
        for rang = nombre + 1, #self.lignes do self.lignes[rang]:Hide() end

        self.zone:Regler(y)
        self.nombreAffiche = nombre
        self.vide:SetText(nombre > 0 and "" or "Personne dans le groupe.")
        self.etat:SetText(string.format("%d joueur%s", nombre, nombre > 1 and "s" or ""))
    end

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
    UI.Menu.Lier("panneau_mj", Ecran.Basculer)
    -- Une fiche qui arrive pendant que le panneau est ouvert s'y affiche.
    LCM.Fiches.onRecue = function(joueur, entity)
        LCM.Info(string.format("fiche de %s reçue.", tostring(joueur)))
        if Ecran.frame and Ecran.frame:IsShown() then Ecran.frame:Afficher() end
        UI.Fiche.Fenetre():Montrer(entity)
    end
end)
