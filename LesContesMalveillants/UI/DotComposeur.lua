-- Composer un dot : on repartit un pool de points, comme pour un debuff.
--
-- Fenetre a elle, et non une resolution du composeur : le bareme du dot vit en
-- Lua (Data/Equilibrage.lua, Core/Dot.lua), pas dans le DSL importe de
-- Necronicon. Ecrire une seconde resolution de huit cents caracteres aurait
-- ajoute a une dette qu'on cherche a solder (10 octobre 2026).
--
-- Trois rangees : ce qu'on grignote, la duree et les stacks, puis les cibles.
-- Le pool se recalcule a chaque clic — on voit ce qu'il reste pendant qu'on
-- depense, pas apres.

local _, LCM = ...
local UI = LCM.UI
local D = LCM.Dot

local Ecran = {}
UI.DotComposeur = Ecran

-- Ce bouton du radial porte SA fenetre, pas une resolution du composeur. On le
-- declare des le chargement : le composeur verifie cette liste avant de crier
-- qu'un bouton n'a pas d'action, et l'ordre des WhenReady ne doit pas decider
-- lequel des deux parle en premier (10 octobre 2026).
LCM.BoutonsPropres = LCM.BoutonsPropres or {}
LCM.BoutonsPropres.dot = true

local LARGEUR, HAUTEUR = 520, 460
local LIGNE = 26

local function Construire()
    local f = UI.Fenetre("dot", "Composer un dot", LARGEUR, HAUTEUR, { x = 0, y = -30 })
    Ecran.frame = f
    f.choix = { rounds = 0, stacks = 0 }

    -- ----- la source et le niveau : ce qui fait le pool ---------------------
    f.sourceLabel = UI.Texte(f.contenu, "Source", UI.C.discret, "GameFontNormalSmall")
    f.sourceLabel:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 6, -4)
    f.source = UI.Bouton(f.contenu, "— statistique —", 150, 22, function(self)
        local options = {}
        for _, id in ipairs(LCM.Equilibrage.dot.sources or {}) do
            local p
            for _, prim in ipairs(LCM.Equilibrage.primaires) do if prim.id == id then p = prim end end
            options[#options + 1] = { id = id, label = p and p.label or id }
        end
        Ecran.choixSource = Ecran.choixSource or UI.Choix("dot_source", "Source")
        Ecran.choixSource:Proposer(self, options, function(id)
            f.choix.source = id
            for _, o in ipairs(options) do if o.id == id then self.label:SetText(o.label) end end
            f:Rendre()
        end)
    end)
    f.source:SetPoint("LEFT", f.sourceLabel, "RIGHT", 8, 0)

    f.penLabel = UI.Texte(f.contenu, "Pénétration moyenne", UI.C.discret, "GameFontNormalSmall")
    f.penLabel:SetPoint("LEFT", f.source, "RIGHT", 14, 0)
    f.pen = UI.Champ(f.contenu, 46, 22, function() f:Rendre() end)
    f.pen:SetPoint("LEFT", f.penLabel, "RIGHT", 6, 0)
    f.pen:SetNumeric(true)

    f.niveauLabel = UI.Texte(f.contenu, "Niveau", UI.C.discret, "GameFontNormalSmall")
    f.niveauLabel:SetPoint("LEFT", f.pen, "RIGHT", 12, 0)
    f.niveau = UI.Champ(f.contenu, 36, 22, function() f:Rendre() end)
    f.niveau:SetPoint("LEFT", f.niveauLabel, "RIGHT", 6, 0)
    f.niveau:SetNumeric(true)

    -- Le compte, toujours visible : on depense en le regardant.
    f.pool = UI.Texte(f.contenu, "", UI.C.titre)
    UI.Police(f.pool, 13)
    f.pool:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 6, -34)
    f.pool:SetPoint("RIGHT", f.contenu, "RIGHT", -6, 0)
    f.pool:SetJustifyH("LEFT")

    -- ----- les pools a repartir ---------------------------------------------
    f.zone = UI.Defilement(f.contenu)
    f.zone:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -58)
    f.zone:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", -4, 76)
    f.lignes = {}

    -- Une rangee : un libelle, ce qu'elle coute, et les deux boutons.
    local function Rangee(rang)
        local l = f.lignes[rang]
        if l then return l end
        l = CreateFrame("Frame", nil, f.zone.contenu)
        l:SetHeight(LIGNE - 2)
        if UI.SurfaceLigne then UI.SurfaceLigne(l) end
        l.nom = UI.Texte(l, "", UI.C.texte)
        UI.Police(l.nom, 12)
        l.nom:SetPoint("LEFT", l, "LEFT", 8, 0)
        l.plus = UI.Bouton(l, "+", 22, 20, function()
            f.choix[l.cle] = (tonumber(f.choix[l.cle]) or 0) + 1
            if not f:Tient() then f.choix[l.cle] = f.choix[l.cle] - 1
                LCM.Alerte("le pool n'y suffit pas.") end
            f:Rendre()
        end)
        l.plus:SetPoint("RIGHT", l, "RIGHT", -8, 0)
        l.valeur = UI.Texte(l, "0", UI.C.titre)
        UI.Police(l.valeur, 12)
        l.valeur:SetPoint("RIGHT", l.plus, "LEFT", -8, 0)
        l.valeur:SetWidth(24)
        l.valeur:SetJustifyH("CENTER")
        l.moins = UI.Bouton(l, "-", 22, 20, function()
            f.choix[l.cle] = math.max(0, (tonumber(f.choix[l.cle]) or 0) - 1)
            f:Rendre()
        end)
        l.moins:SetPoint("RIGHT", l.valeur, "LEFT", -4, 0)
        l.effet = UI.Texte(l, "", UI.C.discret, "GameFontNormalSmall")
        l.effet:SetPoint("RIGHT", l.moins, "LEFT", -10, 0)
        l.effet:SetJustifyH("RIGHT")
        f.lignes[rang] = l
        return l
    end

    -- ----- le pied -----------------------------------------------------------
    f.nomLabel = UI.Texte(f.contenu, "Nom", UI.C.discret, "GameFontNormalSmall")
    f.nomLabel:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 6, 46)
    f.nom = UI.Champ(f.contenu, 180, 22, nil)
    f.nom:SetPoint("LEFT", f.nomLabel, "RIGHT", 8, 0)

    f.etat = UI.Texte(f.contenu, "", UI.C.discret, "GameFontNormalSmall")
    f.etat:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 6, 16)
    f.etat:SetPoint("RIGHT", f.contenu, "RIGHT", -200, 0)
    f.etat:SetJustifyH("LEFT")

    f.declarer = UI.Bouton(f.contenu, "Déclarer", 120, 24, function() f:Declarer() end)
    f.declarer:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", -6, 12)
    f.annuler = UI.Bouton(f.contenu, "Annuler", 90, 24, function() f:Hide() end)
    f.annuler:SetPoint("RIGHT", f.declarer, "LEFT", -6, 0)

    -- ----- le calcul ---------------------------------------------------------
    function f:Entree()
        return { source = self.choix.source,
                 penMoyenne = tonumber(self.pen:GetText()) or 0,
                 niveau = tonumber(self.niveau:GetText()) or 0 }
    end

    function f:Tient()
        local pool = D.Pool(LCM.Entities.Self(), self:Entree())
        return (D.Cout(self.choix)) <= pool
    end

    function f:Rendre()
        local pool = D.Pool(LCM.Entities.Self(), self:Entree())
        local cout, detail = D.Cout(self.choix)
        self.pool:SetText(string.format("Pool : %d  ·  dépensé %d  ·  reste %d", pool, cout, pool - cout))
        local couleur = cout > pool and UI.C.plein or UI.C.titre
        self.pool:SetTextColor(couleur[1], couleur[2], couleur[3])

        local compose = D.Composer(self.choix)
        local rang, y = 0, 0
        local function Poser(cle, libelle, prix, effet)
            rang = rang + 1
            local l = Rangee(rang)
            l.cle = cle
            l.nom:SetText(string.format("%s  (%d pt%s)", libelle, prix, prix > 1 and "s" or ""))
            l.valeur:SetText(tostring(self.choix[cle] or 0))
            l.effet:SetText(effet or "")
            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", self.zone.contenu, "TOPLEFT", 0, -y)
            l:SetPoint("TOPRIGHT", self.zone.contenu, "TOPRIGHT", 0, -y)
            l:Show()
            y = y + LIGNE
        end
        for _, cible in ipairs(D.Cibles()) do
            local points = tonumber(self.choix[cible.id]) or 0
            local effet
            if points > 0 then
                effet = cible.plat and string.format("%d par round", cible.plat * points)
                    or string.format("%d %% par round", math.ceil(cible.taux * points * 100 - 1e-9))
                if cible.zonee then effet = effet .. " (note)" end
            end
            Poser(cible.id, cible.label, cible.cout, effet)
        end
        Poser("rounds", "Rounds", LCM.Equilibrage.dot.coutRound,
            string.format("%d round%s", compose.rounds, compose.rounds > 1 and "s" or ""))
        Poser("stacks", "Stacks", LCM.Equilibrage.dot.coutStack,
            string.format("%d stack%s", compose.stacks, compose.stacks > 1 and "s" or ""))
        for index = rang + 1, #self.lignes do self.lignes[index]:Hide() end
        self.zone:Regler(math.max(1, y))

        local pret = #compose.morsures > 0 and cout <= pool
        self.etat:SetText(#compose.morsures == 0 and "Choisis au moins une jauge à grignoter."
            or (cout > pool and "Le pool n'y suffit pas." or "Prêt."))
        self.declarer:Selectionner(pret)
    end

    -- ----- envoyer -----------------------------------------------------------
    function f:Declarer()
        local compose = D.Composer(self.choix)
        if #compose.morsures == 0 then LCM.Alerte("ce dot ne grignote rien.") return end
        if not self:Tient() then LCM.Alerte("le pool n'y suffit pas.") return end
        local nom = LCM.Trim and LCM.Trim(self.nom:GetText()) or self.nom:GetText()
        if nom == "" then nom = "Dot" end

        Ecran.choixCibles = Ecran.choixCibles or UI.ChoixJoueurs("dot")
        Ecran.choixCibles:Proposer(string.format("Sur qui poser « %s » ?", nom), function(noms)
            if #noms == 0 then return false, "choisis au moins une cible." end
            -- Le jet du lanceur : c'est lui que la dissipation devra battre, et
            -- c'est de lui que part la decroissance du rand.
            local jet = LCM.Roll.Field(LCM.Entities.Self(), "esprit")
            local valeur = jet and jet.total or 0
            local paquet = {
                t = "dot_" .. tostring(GetTime and math.floor(GetTime() * 100) or 0),
                nom = nom, a = LCM.PlayerId(),
                rp = LCM.Identite.NomEnJeu(LCM.Entities.Self()),
                deb = 1, js = "Esprit", jr = valeur, ct = "etat",
                dt = self.choix,
            }
            for _, cible in ipairs(noms) do
                LCM.Reseau.Envoyer("etat", paquet, "WHISPER", cible)
            end
            LCM.Ok(string.format("« %s » envoyé à %s (jet %d).", nom, table.concat(noms, ", "), valeur))
            f:Hide()
            return true
        end)
    end

    function f:Montrer()
        self.choix = { rounds = 0, stacks = 0, source = self.choix and self.choix.source }
        self:Rendre()
        self:Show()
    end

    return f
end

function Ecran.Fenetre()
    if not Ecran.frame then Construire() end
    return Ecran.frame
end

function Ecran.Ouvrir()
    local f = Ecran.Fenetre()
    f:Montrer()
    return f
end

LCM.WhenReady(function()
    if UI.Radial and UI.Radial.Lier then UI.Radial.Lier("dot", Ecran.Ouvrir) end
end)

LCM.AddCommand("dot", "compose un dot", function() Ecran.Ouvrir() end)
