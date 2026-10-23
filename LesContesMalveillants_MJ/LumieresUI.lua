-- Le constructeur des lanternes et des cristaux.
--
-- Repris du panneau d'edition d'OmegaSurvive (Omega_Hub/Modules/Survive/Core/
-- DB/EditPanel.lua, et DatabaseSchema.lua pour les libelles), a la demande du
-- MJ le 23 octobre 2026 : « Nouvelle entree » et « Forger » ouvrent ce
-- panneau-ci pour ces deux categories, comme la Forge pour les autres.
--
-- Meme disposition que chez Survive : une colonne principale (nom,
-- description, valeur, « Desactivable », « Aura ? »)
-- et deux volets qui s'ouvrent a sa droite quand on coche — « Desactivation »
-- (canaux, phrases de desactivation et leur effet, phrases d'activation) et
-- « Aura » (conditions d'application et de retrait, une commande chacune).
-- Memes refus a la validation, avec les memes phrases.
--
-- Ce qui change, et pourquoi :
--   * le panneau n'a pas son propre stockage : il ECRIT les champs texte que
--     Core/Lanternes.lua sait lire (« condition : commande : phrase », une
--     regle par ligne). La regle reste une, que l'entree vienne d'ici, de la
--     base commune ou d'un fichier ;
--   * « Desactivable » et « Aura ? » ne sont pas enregistres : une entree qui a
--     des phrases EST desactivable, une qui a des regles a une aura. Decocher
--     vide la partie correspondante, comme Survive enregistrait des listes
--     vides ;
--   * une ICONE en plus (ecart) : l'entree se range dans les sacs de l'addon,
--     et une case de sac montre une icone ;
--   * « Vérification inventaire ? » et son ID d'item sont retires (le MJ,
--     23 octobre 2026) : une lanterne ou un cristal n'existe que dans les
--     sacs LCM, l'addon le verifie TOUJOURS ;
--   * « Consommable ? » est retire (le MJ, 23 octobre 2026) : changer de
--     cristal en prend toujours un neuf dans les sacs, et un cristal se
--     detruit tout seul a 0 %. La case ne disait plus rien ;
--   * « Desactivable » et « Aura ? » ne sont proposes que pour une lanterne
--     (le MJ, 23 octobre 2026) : c'est la lanterne qu'on allume et qu'on
--     eteint, pas son combustible ;
--   * « reactif » devient « cristal », le nom de la categorie dans l'addon ;
--   * « Max stack » en plus pour un cristal (le MJ, 23 octobre 2026) :
--     combien en tient une poignee, c'est-a-dire une case de sac. C'est la
--     pile maximale de toute entree (`pileMax`) ; vide, pas de limite. Les
--     cristaux ENTAMES n'y sont pas tenus : dans « Cristaux en cours
--     d'usage », ils s'empilent tous par modele ;
--   * un deux-points est refuse dans une phrase et une commande : c'est le
--     separateur du texte enregistre.
local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end
local UI = LCM.UI
local Ecran = {}
MJ.LumieresUI = Ecran
LCM.LumieresUI = Ecran

local LARGEUR = 320          -- EP_W de Survive
local LARGEUR_VOLET = 320    -- EP_SIDE_W
local MARGE = 14
local CHAMP = LARGEUR - 2 * MARGE
local RANGEES_MAX = 5        -- EP_PHRASE_MAX_ROWS, et le maximum de regles d'aura
-- L'habillage d'une fenetre deborde de 34 a droite (CLAUDE.md, « Le fond
-- d'une fenetre passe SOUS ses bordures ») : le volet s'ecarte d'autant, plus
-- les 10 de Survive (EP_SIDE_GAP).
local ECART_VOLET = 44

local TYPES = {
    lanternes = {
        famille = "lanternes", registre = "Lanternes",
        creer = "Nouvelle lanterne", modifier = "Modifier la lanterne",
        valeur = "multiplicateur", libelleValeur = "Multiplicateur de temps", defaut = "1",
        regles = true,
    },
    cristaux = {
        famille = "cristaux", registre = "Cristaux",
        creer = "Nouveau cristal", modifier = "Modifier le cristal",
        valeur = "duree", libelleValeur = "Durée d'activation (minutes)", defaut = "60",
        pile = true,
    },
}

-- Les conditions de Survive, dans son ordre, sur les cles de Core/Lanternes.
local CONDITIONS = {
    { id = "allumer",  label = "Si le joueur active l'élément" },
    { id = "eteindre", label = "Si le joueur désactive l'élément" },
    { id = "vide",     label = "Si l'élément n'a plus de ressource" },
    { id = "pause",    label = "Si une phrase de désactivation est reçue" },
    { id = "reprise",  label = "Si une phrase d'activation est reçue" },
}
local function LibelleCondition(id)
    for _, c in ipairs(CONDITIONS) do if c.id == id then return c.label end end
    return tostring(id or "")
end
local function DemandePhrase(condition) return condition == "pause" or condition == "reprise" end

local EFFETS = {
    { id = "pause",    label = "Pause uniquement" },
    { id = "eteindre", label = "Pause + forcer OFF" },
}
local function LibelleEffet(id) return id == "eteindre" and EFFETS[2].label or EFFETS[1].label end

-- Les canaux de Survive, dans son ordre ; a droite, le mot que lit le Core.
local CANAUX = {
    { mot = "raid",   label = "Raid",         canal = "RAID" },
    { mot = "groupe", label = "Groupe",       canal = "GROUP" },
    { mot = "alerte", label = "Raid Warning", canal = "RAID_WARNING" },
}

local function Texte(v) return (tostring(v or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

local function Construire()
    local f = UI.Fenetre("constructeur_lumieres", "Nouvelle lanterne", LARGEUR + 24, 420, { x = -180, y = 40 })
    local c = f.contenu

    local function Aide(parent, texte)
        local fs = UI.Texte(parent, texte, UI.C.discret, "GameFontNormalSmall")
        fs:SetWidth(CHAMP)
        fs:SetJustifyH("LEFT")
        fs:SetJustifyV("TOP")
        return fs
    end
    local function Libelle(parent, texte)
        return UI.Texte(parent, texte, UI.C.libelle, "GameFontNormalSmall")
    end
    local function Poser(w, parent, y, x)
        w:ClearAllPoints()
        w:SetPoint("TOPLEFT", parent, "TOPLEFT", x or MARGE, -y)
    end

    -- ----- Colonne principale ------------------------------------------------
    f.lblNom = Libelle(c, "Nom")
    f.nom = UI.Champ(c, CHAMP, 22)
    f.nom:SetMaxLetters(120)

    f.lblIcone = Libelle(c, "Icône")
    f.icone = UI.Bouton(c, "Choisir", 115, 22, function(self)
        Ecran.selecteur = Ecran.selecteur or UI.SelecteurIcone("lumieres")
        Ecran.selecteur:Proposer(self, function(chemin)
            f.travail.icone = chemin
            f:AfficherIcone()
        end)
    end)
    f.apercuIcone = f.icone:CreateTexture(nil, "ARTWORK")
    f.apercuIcone:SetSize(22, 22)
    f.apercuIcone:SetPoint("LEFT", f.icone, "RIGHT", 8, 0)

    f.lblDesc = Libelle(c, "Description")
    f.description = UI.Zone(c, CHAMP, 90)
    f.description.saisie:SetMaxLetters(512)


    f.lblValeur = Libelle(c, "")
    f.valeur = UI.Champ(c, CHAMP, 22)
    f.valeur:SetMaxLetters(12)

    f.lblPile = Libelle(c, "Max stack")
    f.pile = UI.Champ(c, CHAMP, 22)
    f.pile:SetMaxLetters(6)
    f.aidePile = Aide(c, "Combien en tient une poignée (une case de sac). Vide : pas de limite.")

    f.desactivable = UI.Case(c, "Désactivable", function() f:Disposer() end)
    f.aideDesactivable = Aide(c, "Si coché, l'objet surveille des canaux et peut se désactiver automatiquement.")
    f.aura = UI.Case(c, "Aura ?", function() f:Disposer() end)
    f.aideAura = Aide(c, "Si coché, vous pouvez définir des règles d'application et de retrait d'aura exécutées via des commandes raid.")

    f.erreur = UI.Texte(c, "", { 1, 0.4, 0.35 }, "GameFontNormalSmall")
    f.erreur:SetWidth(CHAMP)
    f.erreur:SetJustifyH("LEFT")
    local moitie = math.floor((CHAMP - 6) / 2)
    f.valider = UI.Bouton(c, "Valider", moitie, 22, function() f:Valider() end)
    f.annuler = UI.Bouton(c, "Annuler", moitie, 22, function() f:Hide() end)
    f.valider:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", MARGE, 4)
    f.annuler:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -MARGE, 4)
    f.filetBas = UI.Filet(c)
    f.filetBas:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 34)
    f.filetBas:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 34)

    -- ----- Les volets ---------------------------------------------------------
    local function Volet(titre)
        local v = CreateFrame("Frame", nil, f)
        v:SetWidth(LARGEUR_VOLET)
        v:EnableMouse(true)
        v.fond = UI.Aplat(v, { 0.045, 0.038, 0.03, 0.98 })
        v.fond:SetAllPoints(v)
        UI.BordureFine(v, 0.5)
        v.titre = UI.Texte(v, titre, UI.C.titre)
        v.titre:SetPoint("TOP", v, "TOP", 0, -13)
        v.filet = UI.Filet(v)
        v.filet:SetPoint("TOPLEFT", v, "TOPLEFT", 0, -36)
        v.filet:SetPoint("TOPRIGHT", v, "TOPRIGHT", 0, -36)
        v:Hide()
        return v
    end
    f.voletDesactivation = Volet("Désactivation")
    f.voletAura = Volet("Aura")
    local vd, va = f.voletDesactivation, f.voletAura

    local function Separateur(parent)
        local s = UI.Filet(parent)
        s:Hide()
        return s
    end

    vd.lblCanaux = Libelle(vd, "Canaux de désactivation")
    vd.canaux = {}
    for _, def in ipairs(CANAUX) do
        local case = UI.Case(vd, def.label)
        case.mot = def.mot
        vd.canaux[#vd.canaux + 1] = case
    end

    -- Les rangees se creent une fois, ici ; Disposer ne fait que les placer.
    -- Une entree qui en aurait plus (ecrite a la main avant ce panneau) en fait
    -- creer d'autres a l'ouverture, pour que rien ne se perde a l'enregistrement.
    vd.pauses, vd.reprises = {}, {}
    local function RangeePause(i)
        if vd.pauses[i] then return vd.pauses[i] end
        local r = { effet = "pause" }
        r.texte = UI.Champ(vd, CHAMP, 22)
        r.texte:SetMaxLetters(200)
        r.effetListe = UI.Deroulant(vd, 160, 22, function() return EFFETS end,
            function(id) r.effet = id end)
        r.sep = Separateur(vd)
        vd.pauses[i] = r
        return r
    end
    local function RangeeReprise(i)
        if vd.reprises[i] then return vd.reprises[i] end
        local r = { texte = UI.Champ(vd, CHAMP, 22), sep = Separateur(vd) }
        r.texte:SetMaxLetters(200)
        vd.reprises[i] = r
        return r
    end
    vd.lblPauses = Libelle(vd, "Phrases de désactivation")
    vd.plusPause = UI.BoutonSigne(vd, 18, function()
        f.nPauses = math.min(math.max(RANGEES_MAX, #vd.pauses), f.nPauses + 1)
        RangeePause(f.nPauses)
        f:Disposer()
    end)
    vd.plusPause:Signe("+", "Ajouter une phrase de désactivation")
    vd.sepSection = Separateur(vd)
    vd.lblReprises = Libelle(vd, "Phrases d'activation")
    vd.plusReprise = UI.BoutonSigne(vd, 18, function()
        f.nReprises = math.min(math.max(RANGEES_MAX, #vd.reprises), f.nReprises + 1)
        RangeeReprise(f.nReprises)
        f:Disposer()
    end)
    vd.plusReprise:Signe("+", "Ajouter une phrase d'activation")

    -- Les phrases qu'une regle d'aura peut viser : celles ecrites a l'instant
    -- dans le volet Desactivation, comme chez Survive.
    local function PhrasesDe(condition)
        local out, rangs, n = {}, condition == "pause" and vd.pauses or vd.reprises,
            condition == "pause" and f.nPauses or f.nReprises
        for i = 1, n do
            local t = Texte(rangs[i] and rangs[i].texte:GetText())
            if t ~= "" then out[#out + 1] = { id = t, label = t } end
        end
        return out
    end

    va.poser, va.retirer = {}, {}
    local function RangeeAura(liste, i, defaut)
        if liste[i] then return liste[i] end
        local r = { condition = defaut, phrase = "" }
        r.conditionListe = UI.Deroulant(va, CHAMP, 22, function() return CONDITIONS end, function(id)
            r.condition = id
            if not DemandePhrase(id) then r.phrase = "" end
            f:Disposer()
        end)
        r.commande = UI.Champ(va, CHAMP, 22)
        r.commande:SetMaxLetters(200)
        r.phraseListe = UI.Deroulant(va, CHAMP, 22, function() return PhrasesDe(r.condition) end,
            function(id) r.phrase = id end)
        r.sep = Separateur(va)
        liste[i] = r
        return r
    end
    va.lblPoser = Libelle(va, "Conditions d'application")
    va.plusPoser = UI.BoutonSigne(va, 18, function()
        f.nPoser = math.min(math.max(RANGEES_MAX, #va.poser), f.nPoser + 1)
        RangeeAura(va.poser, f.nPoser, "allumer")
        f:Disposer()
    end)
    va.plusPoser:Signe("+", "Ajouter une condition d'application")
    va.sepSection = Separateur(va)
    va.lblRetirer = Libelle(va, "Conditions de retrait")
    va.plusRetirer = UI.BoutonSigne(va, 18, function()
        f.nRetirer = math.min(math.max(RANGEES_MAX, #va.retirer), f.nRetirer + 1)
        RangeeAura(va.retirer, f.nRetirer, "eteindre")
        f:Disposer()
    end)
    va.plusRetirer:Signe("+", "Ajouter une condition de retrait")

    for i = 1, RANGEES_MAX do
        RangeePause(i)
        RangeeReprise(i)
        RangeeAura(va.poser, i, "allumer")
        RangeeAura(va.retirer, i, "eteindre")
    end

    -- ----- Disposition (RefreshEditPanelLayout de Survive) ---------------------
    local function Rangees(liste, n, fn)
        for i, r in ipairs(liste) do fn(r, i <= n, i) end
    end

    function f:DisposerDesactivation(montre)
        vd:SetShown(montre)
        if not montre then return end
        local y = 50
        Poser(vd.lblCanaux, vd, y)
        y = y + 18
        for _, case in ipairs(vd.canaux) do
            Poser(case, vd, y)
            y = y + 22
        end
        y = y + 4
        Poser(vd.lblPauses, vd, y)
        vd.plusPause:ClearAllPoints()
        vd.plusPause:SetPoint("LEFT", vd.lblPauses, "RIGHT", 10, 0)
        y = y + 18
        Rangees(vd.pauses, self.nPauses, function(r, visible, i)
            r.texte:SetShown(visible)
            r.effetListe:SetShown(visible)
            r.sep:Hide()
            if not visible then return end
            Poser(r.texte, vd, y)
            Poser(r.effetListe, vd, y + 26)
            r.effetListe:Definir(r.effet, LibelleEffet(r.effet))
            y = y + 56
            if i < self.nPauses then
                r.sep:ClearAllPoints()
                r.sep:SetPoint("TOPLEFT", vd, "TOPLEFT", 18, -y)
                r.sep:SetPoint("TOPRIGHT", vd, "TOPRIGHT", -18, -y)
                r.sep:Show()
                y = y + 10
            end
        end)
        y = y + 2
        vd.sepSection:ClearAllPoints()
        vd.sepSection:SetPoint("TOPLEFT", vd, "TOPLEFT", MARGE, -y)
        vd.sepSection:SetPoint("TOPRIGHT", vd, "TOPRIGHT", -MARGE, -y)
        vd.sepSection:Show()
        y = y + 18
        Poser(vd.lblReprises, vd, y)
        vd.plusReprise:ClearAllPoints()
        vd.plusReprise:SetPoint("LEFT", vd.lblReprises, "RIGHT", 10, 0)
        y = y + 18
        Rangees(vd.reprises, self.nReprises, function(r, visible, i)
            r.texte:SetShown(visible)
            r.sep:Hide()
            if not visible then return end
            Poser(r.texte, vd, y)
            y = y + 28
            if i < self.nReprises then
                r.sep:ClearAllPoints()
                r.sep:SetPoint("TOPLEFT", vd, "TOPLEFT", 18, -y)
                r.sep:SetPoint("TOPRIGHT", vd, "TOPRIGHT", -18, -y)
                r.sep:Show()
                y = y + 10
            end
        end)
        vd:SetHeight(math.max(170, y + 18))
        vd:ClearAllPoints()
        vd:SetPoint("TOPLEFT", self, "TOPRIGHT", ECART_VOLET, 0)
    end

    local function DisposerRegles(liste, n, y)
        Rangees(liste, n, function(r, visible, i)
            r.conditionListe:SetShown(visible)
            r.commande:SetShown(visible)
            r.phraseListe:SetShown(visible and DemandePhrase(r.condition))
            r.sep:Hide()
            if not visible then return end
            Poser(r.conditionListe, va, y)
            r.conditionListe:Definir(r.condition, LibelleCondition(r.condition))
            y = y + 30
            Poser(r.commande, va, y)
            y = y + 28
            if DemandePhrase(r.condition) then
                -- Comme Survive : la premiere phrase disponible par defaut.
                local phrases = PhrasesDe(r.condition)
                if r.phrase == "" and phrases[1] then r.phrase = phrases[1].id end
                Poser(r.phraseListe, va, y)
                r.phraseListe:Definir(r.phrase, r.phrase ~= "" and r.phrase or "Choisir une phrase")
                y = y + 30
            end
            if i < n then
                r.sep:ClearAllPoints()
                r.sep:SetPoint("TOPLEFT", va, "TOPLEFT", 18, -y)
                r.sep:SetPoint("TOPRIGHT", va, "TOPRIGHT", -18, -y)
                r.sep:Show()
                y = y + 8
            end
            y = y + 6
        end)
        return y
    end

    function f:DisposerAura(montre)
        va:SetShown(montre)
        if not montre then return end
        local y = 50
        Poser(va.lblPoser, va, y)
        va.plusPoser:ClearAllPoints()
        va.plusPoser:SetPoint("LEFT", va.lblPoser, "RIGHT", 10, 0)
        y = DisposerRegles(va.poser, self.nPoser, y + 20)
        va.sepSection:ClearAllPoints()
        va.sepSection:SetPoint("TOPLEFT", va, "TOPLEFT", MARGE, -y)
        va.sepSection:SetPoint("TOPRIGHT", va, "TOPRIGHT", -MARGE, -y)
        va.sepSection:Show()
        y = y + 16
        Poser(va.lblRetirer, va, y)
        va.plusRetirer:ClearAllPoints()
        va.plusRetirer:SetPoint("LEFT", va.lblRetirer, "RIGHT", 10, 0)
        y = DisposerRegles(va.retirer, self.nRetirer, y + 20)
        va:SetHeight(math.max(170, y + 18))
        -- Sous le volet Desactivation s'il est ouvert, comme chez Survive.
        local haut = vd:IsShown() and (vd:GetHeight() + 8) or 0
        va:ClearAllPoints()
        va:SetPoint("TOPLEFT", self, "TOPRIGHT", ECART_VOLET, -haut)
    end

    function f:Disposer()
        local t = self.type
        local y = 8
        Poser(self.lblNom, c, y)
        Poser(self.nom, c, y + 18)
        y = y + 52
        Poser(self.lblIcone, c, y + 5)
        Poser(self.icone, c, y, 60)
        y = y + 32
        Poser(self.lblDesc, c, y)
        Poser(self.description, c, y + 18)
        y = y + 18 + 90 + 12

        self.lblValeur:SetText(t.libelleValeur)
        Poser(self.lblValeur, c, y)
        Poser(self.valeur, c, y + 18)
        y = y + 56
        local avecPile = t.pile == true
        for _, w in ipairs({ self.lblPile, self.pile, self.aidePile }) do w:SetShown(avecPile) end
        if avecPile then
            Poser(self.lblPile, c, y)
            Poser(self.pile, c, y + 18)
            Poser(self.aidePile, c, y + 44)
            y = y + 74
        end
        local regles = t.regles == true
        for _, w in ipairs({ self.desactivable, self.aideDesactivable, self.aura, self.aideAura }) do
            w:SetShown(regles)
        end
        if regles then
            Poser(self.desactivable, c, y)
            y = y + 22
            Poser(self.aideDesactivable, c, y)
            y = y + 28
            Poser(self.aura, c, y)
            y = y + 22
            Poser(self.aideAura, c, y)
            y = y + 34
        end
        Poser(self.erreur, c, y)
        y = y + 24

        self:SetHeight(math.max(280, self.insetHaut + y + 40 + self.insetBas))
        self:DisposerDesactivation(regles and self.desactivable:EstCochee())
        self:DisposerAura(regles and self.aura:EstCochee())
    end

    function f:AfficherIcone()
        local icone = self.travail and self.travail.icone
        self.icone.label:SetText(icone and "Changer" or "Choisir")
        local chemin = icone and (tostring(icone):find("[/\\]") and icone or ("Interface\\Icons\\" .. icone))
        self.apercuIcone:SetTexture(chemin)
        self.apercuIcone:SetShown(chemin ~= nil)
    end

    -- ----- Lecture d'une entree --------------------------------------------------
    function f:Remplir(element)
        local L = LCM.Lanterne
        local e = element or {}
        self.nom:SetText(e.label or "")
        self.description:SetText(e.description or "")
        local v = e[self.type.valeur]
        self.valeur:SetText(v and tostring(v) or self.type.defaut)
        self.pile:SetText(e.pileMax and tostring(e.pileMax) or "")
        self:AfficherIcone()

        local pauses = L.LirePhrases(e.phrasesPause, true)
        local reprises = L.LirePhrases(e.phrasesReprise, false)
        local okC, canaux = pcall(L.LireCanaux, e.id, e.canaux, error)
        canaux = okC and canaux or {}
        local okP, poser = pcall(L.LireAuras, e.id, "", e.aurasPosees, error)
        local okR, retirer = pcall(L.LireAuras, e.id, "", e.aurasRetirees, error)
        poser, retirer = okP and poser or {}, okR and retirer or {}

        self.desactivable:Cocher(#pauses > 0 or #reprises > 0 or next(canaux) ~= nil)
        self.aura:Cocher(#poser > 0 or #retirer > 0)
        for _, case in ipairs(vd.canaux) do
            local canal
            for _, def in ipairs(CANAUX) do if def.mot == case.mot then canal = def.canal end end
            case:Cocher(canaux[canal] == true)
        end

        self.nPauses = math.max(1, #pauses)
        for i = 1, math.max(self.nPauses, #vd.pauses) do
            local r, p = RangeePause(i), pauses[i]
            r.texte:SetText(p and p.texte or "")
            r.effet = (p and p.eteindre) and "eteindre" or "pause"
        end
        self.nReprises = math.max(1, #reprises)
        for i = 1, math.max(self.nReprises, #vd.reprises) do
            local r, p = RangeeReprise(i), reprises[i]
            r.texte:SetText(p and p.texte or "")
        end
        local function Regles(liste, regles, defaut)
            for i = 1, math.max(#regles, #liste) do
                local r, regle = RangeeAura(liste, i, defaut), regles[i]
                r.condition = regle and regle.condition or defaut
                r.commande:SetText(regle and regle.commande or "")
                r.phrase = regle and regle.phrase or ""
            end
            return math.max(1, #regles)
        end
        self.nPoser = Regles(va.poser, poser, "allumer")
        self.nRetirer = Regles(va.retirer, retirer, "eteindre")
    end

    -- ----- Validation (epSaveCallback de Survive) ------------------------------
    local function Refus(texte)
        f.erreur:SetText(texte)
        return false
    end

    local function SansDeuxPoints(texte) return not texte:find(":", 1, true) end

    -- Les regles d'un cote, en texte. nil et la raison si une rangee est a
    -- moitie remplie, comme chez Survive.
    local function ReglesEnTexte(liste, n)
        local lignes = {}
        for i = 1, n do
            local r = liste[i]
            -- La condition a toujours une valeur (la liste en impose une) : une
            -- rangee sans commande est une rangee laissee vide, qu'on ignore.
            local commande = Texte(r.commande:GetText())
            if commande ~= "" then
                if not SansDeuxPoints(commande) then
                    return nil, "Une commande d'aura ne peut pas contenir « : » (c'est le séparateur des règles)."
                end
                if DemandePhrase(r.condition) and r.phrase == "" then
                    return nil, "Choisissez une phrase pour chaque règle d'aura liée aux phrases."
                end
                local ligne = r.condition .. " : " .. commande
                if DemandePhrase(r.condition) then ligne = ligne .. " : " .. r.phrase end
                lignes[#lignes + 1] = ligne
            end
        end
        return lignes
    end

    function f:Valider()
        local t = self.type
        local label = Texte(self.nom:GetText())
        if label == "" then return Refus("Le nom de l'objet est obligatoire.") end
        local valeur = tonumber(Texte(self.valeur:GetText()))
        if not valeur or valeur <= 0 then return Refus("La valeur numérique doit être supérieure à zéro.") end
        local pile
        if t.pile and Texte(self.pile:GetText()) ~= "" then
            pile = tonumber(Texte(self.pile:GetText()))
            if not pile or pile < 1 or pile ~= math.floor(pile) then
                return Refus("Le max stack doit être un nombre entier, 1 au moins (vide : pas de limite).")
            end
        end

        local canaux, pauses, reprises = {}, {}, {}
        if t.regles and self.desactivable:EstCochee() then
            for _, case in ipairs(vd.canaux) do
                if case:EstCochee() then canaux[#canaux + 1] = case.mot end
            end
            for i = 1, self.nPauses do
                local r = vd.pauses[i]
                local p = Texte(r.texte:GetText())
                if p ~= "" then
                    if not SansDeuxPoints(p) then
                        return Refus("Une phrase ne peut pas contenir « : » (c'est le séparateur des règles).")
                    end
                    pauses[#pauses + 1] = r.effet == "eteindre" and (p .. " : eteindre") or p
                end
            end
            for i = 1, self.nReprises do
                local p = Texte(vd.reprises[i].texte:GetText())
                if p ~= "" then
                    if not SansDeuxPoints(p) then
                        return Refus("Une phrase ne peut pas contenir « : » (c'est le séparateur des règles).")
                    end
                    reprises[#reprises + 1] = p
                end
            end
            if #canaux == 0 then return Refus("Renseignez au moins un canal à lire.") end
            if #pauses == 0 then return Refus("Renseignez au moins une phrase de désactivation.") end
            if #reprises == 0 then return Refus("Renseignez au moins une phrase d'activation.") end
        end

        local poser, retirer = {}, {}
        if t.regles and self.aura:EstCochee() then
            local raison
            poser, raison = ReglesEnTexte(va.poser, self.nPoser)
            if not poser then return Refus(raison) end
            retirer, raison = ReglesEnTexte(va.retirer, self.nRetirer)
            if not retirer then return Refus(raison) end
            if #poser == 0 then return Refus("Renseignez au moins une condition d'application d'aura.") end
            if #retirer == 0 then return Refus("Renseignez au moins une condition de retrait d'aura.") end
        end

        local def = self.travail
        def.label = label
        def.description = Texte(self.description.saisie:GetText()) ~= "" and self.description.saisie:GetText() or nil
        -- Les champs d'avant, que plus rien ne lit : une entree reprise les perd.
        def.verifInventaire, def.itemId = nil, nil
        -- Le champ d'avant, que plus rien ne lit : une entree reprise le perd.
        def.consommable = nil
        def[t.valeur] = valeur
        if t.pile then def.pileMax = pile end
        def.canaux = #canaux > 0 and table.concat(canaux, ", ") or nil
        def.phrasesPause = #pauses > 0 and table.concat(pauses, "\n") or nil
        def.phrasesReprise = #reprises > 0 and table.concat(reprises, "\n") or nil
        def.aurasPosees = #poser > 0 and table.concat(poser, "\n") or nil
        def.aurasRetirees = #retirer > 0 and table.concat(retirer, "\n") or nil

        local ok, raison = LCM.Brouillons.Enregistrer(t.famille, def, self.nouveau)
        if not ok then return Refus(tostring(raison)) end
        self.erreur:SetText("")
        if UI.Compendium and UI.Compendium.Actualiser then UI.Compendium.Actualiser() end
        self:Hide()
        return true
    end

    function f:Editer(categorie, element)
        self.type = TYPES[categorie and categorie.famille or ""] or TYPES.lanternes
        self.nouveau = element == nil
        self.travail = element and LCM.Copie(element) or {
            id = LCM.Brouillons.NouvelIdentifiant(),
            icone = categorie and categorie.icone,
        }
        self:Titre(self.nouveau and self.type.creer or self.type.modifier)
        self.erreur:SetText("")
        self:Remplir(element)
        self:Disposer()
        self:Show()
        UI.Devant(self)
    end

    f:Hide()
    return f
end

-- Appele par l'editeur du compendium (categorie.editeur = "LumieresUI").
function Ecran.Editer(element, categorie)
    Ecran.frame = Ecran.frame or Construire()
    Ecran.frame:Editer(categorie, element)
    return true
end
