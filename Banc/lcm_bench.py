"""Banc de test des Contes Malveillants, hors WoW.

Charge l'addon dans un Lua 5.1 avec une API WoW simulee, puis execute un
scenario Lua passe en argument. Aucun fichier du jeu n'est ecrit.

    python scenarios/lcm_bench.py scenarios/lcm_<scenario>.lua

La simulation des cadres est volontairement structurelle : elle retient la
hierarchie, les ancrages, les tailles, les textes et la visibilite — de quoi
verifier qu'une fenetre est bien construite, sans pretendre dessiner quoi que
ce soit.
"""
from lupa.lua51 import LuaRuntime
import io, os, sys

ADDONS = ['LesContesMalveillants', 'LesContesMalveillants_MJ']

# Ou trouver les dossiers d'addon. Dans l'ordre :
#   1. --addons <chemin>, ou la variable d'environnement LCM_ADDONS ;
#   2. un dossier parent du banc qui contient deja LesContesMalveillants/
#      (c'est le cas quand on travaille depuis le depot) ;
#   3. le chemin Epsilon habituel.
# Sans ca, le banc ne marche que sur la machine ou il a ete ecrit.
DEFAUT = 'F:/WOW EPSILON/Epsilon/Epsilon/_retail_/Interface/AddOns/'


def racine_addons(argv=None):
    argv = argv if argv is not None else sys.argv
    for index, arg in enumerate(argv):
        if arg == '--addons' and index + 1 < len(argv):
            return argv[index + 1]
        if arg.startswith('--addons='):
            return arg.split('=', 1)[1]
    depuis_env = os.environ.get('LCM_ADDONS')
    if depuis_env:
        return depuis_env
    ici = os.path.dirname(os.path.abspath(__file__))
    for _ in range(4):
        if os.path.isdir(os.path.join(ici, ADDONS[0])):
            return ici
        parent = os.path.dirname(ici)
        if parent == ici:
            break
        ici = parent
    return DEFAUT


ROOT = racine_addons()

PRELUDE = r'''
-- ===== API WoW simulee ====================================================
local sorties = {}
_G.__sorties = sorties

DEFAULT_CHAT_FRAME = { AddMessage = function(self, texte) sorties[#sorties + 1] = tostring(texte) end }

-- Le groupe simule : __groupe({"Nytherah-Apertus", ...}) le compose.
local groupe = {}
_G.__groupe = function(membres) groupe = membres or {} end
function GetNumGroupMembers() return #groupe end
function IsInRaid() return #groupe > 2 end
function UnitName(unit)
    local index = tostring(unit):match("^raid(%d+)$") or tostring(unit):match("^party(%d+)$")
    if index then
        local nom = groupe[tonumber(index)]
        if not nom then return nil end
        local court, royaume = nom:match("^(.-)%-(.+)$")
        if court then return court, royaume end
        return nom, ""
    end
    return "Reika"
end
function UnitFullName(unit) return "Reika", "Apertus" end
function GetAddOnMetadata(addon, champ) if champ == "Version" then return "0.1.0" end return nil end
-- L'horloge est pilotable : la repousse d'un stock se verifie en avancant le
-- temps, pas en attendant.
local horloge = 1000
function GetTime() return horloge end
function __temps(secondes) horloge = secondes end
function __avancerTemps(secondes) horloge = horloge + secondes end

local addonsCharges = {}
_G.__addonsCharges = addonsCharges
C_AddOns = { IsAddOnLoaded = function(nom) return addonsCharges[nom] == true end }

UIParent = nil  -- remplace plus bas par un vrai cadre simule

local tousLesCadres = {}
_G.__cadres = tousLesCadres

local function NouvelleRegion(kind, parent)
    local r = {
        __kind = kind,
        __points = {},
        __shown = true,
        __children = {},
        __regions = {},
        parent = parent,
    }
    function r:SetPoint(...) local p = {...} self.__points[#self.__points + 1] = p return self end
    function r:ClearAllPoints() self.__points = {} end
    function r:GetPoint(i) local p = self.__points[i or 1] if p then return unpack(p) end end
    function r:GetNumPoints() return #self.__points end
    function r:SetSize(w, h) self.__w, self.__h = w, h end
    function r:SetWidth(w) self.__w = w end
    function r:SetHeight(h) self.__h = h end
    function r:GetWidth() return self.__w or 0 end
    function r:GetHeight() return self.__h or 0 end
    -- Pas de geometrie d'ecran simulee : un bord vaut 0, assez pour les calculs relatifs.
    function r:GetTop() return 0 end
    function r:GetLeft() return 0 end
    -- Survol : le scenario pose __survol sur le cadre « sous la souris ».
    function r:IsMouseOver() return self.__survol == true end
    function r:GetRight() return 0 end
    function r:GetBottom() return 0 end
    -- Afficher et masquer declenchent OnShow / OnHide, comme dans le jeu : des
    -- fenetres s'en servent pour se ranger ou revenir au premier plan.
    --
    -- Comme dans le jeu, l'evenement descend aux enfants affiches : masquer une
    -- fenetre declenche le OnHide de ce qu'elle contient (une liste de choix
    -- s'y accroche pour se refermer).
    local function Propager(cadre, script)
        for _, enfant in ipairs(cadre.__children or {}) do
            if enfant.__shown == true then
                local fn = enfant.__scripts and enfant.__scripts[script]
                if fn then fn(enfant) end
                Propager(enfant, script)
            end
        end
    end
    local function Visibilite(self, visible)
        local avant = self.__shown == true
        self.__shown = visible and true or false
        if avant == self.__shown then return end
        local script = visible and "OnShow" or "OnHide"
        local fn = self.__scripts and self.__scripts[script]
        if fn then fn(self) end
        Propager(self, script)
    end
    function r:Show() Visibilite(self, true) end
    function r:Hide() Visibilite(self, false) end
    function r:SetShown(v) Visibilite(self, v) end
    function r:IsShown() return self.__shown == true end
    function r:IsVisible() return self.__shown == true end
    function r:SetAlpha(a) self.__alpha = a end
    function r:GetAlpha() return self.__alpha or 1 end
    function r:SetText(t) self.__text = t end
    function r:GetText() return self.__text end
    function r:SetTexture(t) self.__texture = t end
    function r:GetTexture() return self.__texture end
    function r:SetDesaturated(v) self.__desature = v and true or false end
    function r:IsDesaturated() return self.__desature == true end
    function r:SetColorTexture(...) self.__color = {...} end
    function r:SetVertexColor(...) self.__vertex = {...} end
    function r:SetTextColor(...) self.__textColor = {...} end
    function r:GetTextColor() local c = self.__textColor or { 1, 1, 1, 1 } return c[1], c[2], c[3], c[4] or 1 end
    function r:SetJustifyH(v) self.__justifyH = v end
    function r:SetJustifyV(v) self.__justifyV = v end
    function r:SetFontObject() end
    function r:SetFont(chemin, taille, contour) self.__font = { chemin, taille, contour } end
    function r:GetFont() local f = self.__font or {} return f[1], f[2], f[3] end
    function r:SetAllPoints(other) self.__allPoints = other or self.parent end
    function r:SetTexCoord(...) self.__texCoord = {...} end
    function r:SetRotation(a) self.__rotation = a end
    function r:GetRotation() return self.__rotation or 0 end
    function r:AddMaskTexture(m) self.__masks = self.__masks or {} self.__masks[#self.__masks + 1] = m end
    function r:GetCenter() return (self.__w or 0) / 2, (self.__h or 0) / 2 end
    function r:SetDrawLayer() end
    function r:SetWordWrap() end
    -- Mesure approchee d'un texte qui passe a la ligne : 6 px par caractere,
    -- 12 px par ligne. Assez pour verifier qu'un bloc grandit avec son texte,
    -- pas pour juger d'un pixel.
    function r:GetStringHeight()
        local texte = tostring(self.__text or "")
        if texte == "" then return 0 end
        local largeur = self.__w or 0
        local lignes = 0
        for morceau in (texte .. "\n"):gmatch("([^\n]*)\n") do
            local n = 1
            if largeur > 0 then n = math.max(1, math.ceil(#morceau * 6 / largeur)) end
            lignes = lignes + n
        end
        return lignes * 12
    end
    function r:GetStringWidth() return #tostring(self.__text or "") * 6 end
    function r:SetNonSpaceWrap() end
    function r:SetMaxLines() end
    return r
end

local function NouveauCadre(kind, nom, parent, template)
    local f = NouvelleRegion(kind or "Frame", parent)
    f.__name = nom
    f.__template = template
    f.__events = {}
    f.__scripts = {}
    function f:CreateTexture(n, layer)
        local t = NouvelleRegion("Texture", self)
        self.__regions[#self.__regions + 1] = t
        return t
    end
    function f:CreateFontString(n, layer, inherits)
        local t = NouvelleRegion("FontString", self)
        self.__regions[#self.__regions + 1] = t
        return t
    end
    function f:RegisterEvent(e) self.__events[e] = true end
    function f:UnregisterEvent(e) self.__events[e] = nil end
    function f:UnregisterAllEvents() self.__events = {} end
    function f:SetScript(quoi, fn) self.__scripts[quoi] = fn end
    function f:GetScript(quoi) return self.__scripts[quoi] end
    function f:HookScript(quoi, fn)
        local avant = self.__scripts[quoi]
        self.__scripts[quoi] = function(...) if avant then avant(...) end fn(...) end
    end
    function f:SetMovable() end
    function f:SetResizable() end
    function f:EnableMouse() end
    function f:EnableMouseWheel() end
    function f:RegisterForDrag() end
    function f:RegisterForClicks() end
    function f:StartMoving() end
    function f:StopMovingOrSizing() end
    -- Redimensionnement : retenu (bornes, poignee tiree), pas simule.
    function f:StartSizing(coin) self.__sizing = coin end
    function f:SetResizeBounds(l, h) self.__resizeBounds = { l, h } end
    function f:SetClampedToScreen() end
    -- Rognage des enfants (zone de texte multiligne) : retenu, pas simule.
    function f:SetClipsChildren(v) self.__clips = v and true or false end
    function f:DoesClipChildren() return self.__clips == true end
    function f:SetFrameStrata(v) self.__strata = v end
    function f:SetFrameLevel(v) self.__level = v end
    function f:GetFrameLevel() return self.__level or 1 end
    function f:SetToplevel() end
    function f:Raise() end
    function f:SetScale(s) self.__scale = s end
    function f:GetScale() return self.__scale or 1 end
    function f:GetEffectiveScale() return self.__scale or 1 end
    function f:GetName() return self.__name end
    function f:SetBackdrop() end
    function f:SetScrollChild(c) self.__scrollChild = c end
    function f:GetChildren() return unpack(self.__children) end
    function f:GetRegions() return unpack(self.__regions) end
    function f:SetChecked(v) self.__checked = v and true or false end
    function f:GetChecked() return self.__checked == true end
    function f:SetEnabled(v) self.__enabled = v and true or false end
    function f:IsEnabled() return self.__enabled ~= false end
    function f:Disable() self.__enabled = false end
    function f:Enable() self.__enabled = true end
    function f:SetNormalTexture() end
    function f:SetAutoFocus() end
    function f:SetFocus() end
    function f:ClearFocus() end
    function f:HighlightText() end
    function f:SetNumeric() end
    function f:SetMaxLetters(n) self.__maxLetters = n end
    function f:SetCursorPosition() end
    function f:SetTextInsets() end
    function f:SetMultiLine() end
    function f:Saisir(texte)
        -- Simule une frappe : pose le texte puis previent la fenetre.
        self:SetText(texte)
        local fn = self.__scripts.OnTextChanged
        if fn then fn(self, true) end
    end
    function f:SetHighlightTexture() end
    function f:GetFontString() return self.__fontString end
    function f:CreateMaskTexture(n, layer)
        local t = NouvelleRegion("MaskTexture", self)
        self.__regions[#self.__regions + 1] = t
        return t
    end
    function f:Click(bouton)
        local fn = self.__scripts.OnClick
        if fn then fn(self, bouton or "LeftButton") end
    end
    function f:Molette(delta)
        local fn = self.__scripts.OnMouseWheel
        if fn then fn(self, delta) end
    end
    if parent and parent.__children then
        parent.__children[#parent.__children + 1] = f
    end
    tousLesCadres[#tousLesCadres + 1] = f
    -- Comme dans le jeu, un cadre nomme devient une globale.
    if type(nom) == "string" and nom ~= "" then _G[nom] = f end
    return f
end

function CreateFrame(kind, nom, parent, template)
    return NouveauCadre(kind, nom, parent, template)
end

UIParent = NouveauCadre("Frame", "UIParent", nil, nil)
UIParent:SetSize(1920, 1080)

function __declencher(event, ...)
    for _, f in ipairs(tousLesCadres) do
        if f.__events and f.__events[event] and f.__scripts.OnEvent then
            f.__scripts.OnEvent(f, event, ...)
        end
    end
end

-- Parcourt un cadre et ses descendants : pratique pour verifier une fenetre.
function __descendants(cadre, sortie)
    sortie = sortie or {}
    if type(cadre) ~= "table" then return sortie end
    for _, enfant in ipairs(cadre.__children or {}) do
        sortie[#sortie + 1] = enfant
        __descendants(enfant, sortie)
    end
    return sortie
end

function __textes(cadre, sortie)
    sortie = sortie or {}
    if type(cadre) ~= "table" then return sortie end
    for _, region in ipairs(cadre.__regions or {}) do
        if region.__text and region.__text ~= "" then sortie[#sortie + 1] = region.__text end
    end
    for _, enfant in ipairs(cadre.__children or {}) do __textes(enfant, sortie) end
    return sortie
end

-- ===== Chat et messages d'addon ==========================================
-- Les envois sont retenus ; __reseauBoucle(true) les rend immediatement au
-- destinataire, comme s'ils avaient fait l'aller-retour.
local envois = {}
_G.__envois = envois
local boucle = false
local prefixesEnregistres = {}
_G.__prefixes = prefixesEnregistres

function __reseauBoucle(actif, expediteur)
    boucle = actif and true or false
    _G.__expediteurBoucle = expediteur or "Nytherah-Apertus"
end

C_ChatInfo = {
    RegisterAddonMessagePrefix = function(p) prefixesEnregistres[p] = true return true end,
    IsAddonMessagePrefixRegistered = function(p) return prefixesEnregistres[p] == true end,
    SendAddonMessage = function(prefixe, message, canal, cible)
        envois[#envois + 1] = { prefixe = prefixe, message = message, canal = canal, cible = cible,
                                taille = #message }
        if boucle then
            __declencher("CHAT_MSG_ADDON", prefixe, message, canal, _G.__expediteurBoucle)
        end
        return true
    end,
}
function SendAddonMessage(p, m, c, t) return C_ChatInfo.SendAddonMessage(p, m, c, t) end

-- Le plus gros message envoye : de quoi verifier qu'on reste sous la limite.
function __plusGrosEnvoi()
    local max = 0
    for _, e in ipairs(envois) do if e.taille > max then max = e.taille end end
    return max
end

local lienInsere
function ChatEdit_GetActiveWindow() return _G.__chatOuvert end
function ChatEdit_InsertLink(lien) lienInsere = lien return _G.__chatOuvert ~= nil end
function __dernierLien() return lienInsere end

-- SetItemRef et son crochet : on garde la liste des crochets et on les appelle.
local crochets = {}
function SetItemRef(lien, texte, bouton) for _, fn in ipairs(crochets) do fn(lien, texte, bouton) end end
function hooksecurefunc(nom, fn)
    if nom == "SetItemRef" then crochets[#crochets + 1] = fn end
end
function __cliquerLien(lien) SetItemRef(lien, lien, "LeftButton") end

UISpecialFrames = {}
function InCombatLockdown() return false end
function IsShiftKeyDown() return __touches and __touches.shift == true end
function IsControlKeyDown() return __touches and __touches.ctrl == true end
function IsAltKeyDown() return __touches and __touches.alt == true end
-- Un scenario simule une touche tenue : __touches = { ctrl = true }.
__touches = {}
-- Boutons de souris tenus : __souris = { LeftButton = true }.
__souris = {}
function IsMouseButtonDown(b) return __souris[b or "LeftButton"] == true end

-- Selecteur de couleur du jeu : le scenario lit ce qui a ete demande et
-- peut rappeler swatchFunc pour simuler un choix.
ColorPickerFrame = NouveauCadre("Frame", "ColorPickerFrame", nil, nil)
function ColorPickerFrame:SetupColorPickerAndShow(info) self.__info = info self:Show() end
function ColorPickerFrame:GetColorRGB() local i = self.__info or {} return i.r or 1, i.g or 1, i.b or 1 end
function GetCursorPosition() return 0, 0 end

GameTooltip = NouveauCadre("GameTooltip", "GameTooltip", nil, nil)
function GameTooltip:SetOwner(o) self.__owner = o end
function GameTooltip:GetOwner() return self.__owner end
function GameTooltip:SetText(t) self.__text = t end
function GameTooltip:AddLine(t) self.__lines = self.__lines or {} self.__lines[#self.__lines + 1] = t end
function GameTooltip:ClearLines() self.__lines = {} end

-- Fait tourner les animations : appelle OnUpdate sur tous les cadres qui en
-- ont un. `__avancer(1)` suffit a terminer n'importe quelle transition.
function __avancer(secondes, pas)
    pas = pas or 0.05
    local reste = secondes or 1
    while reste > 0 do
        local dt = math.min(pas, reste)
        for _, f in ipairs(tousLesCadres) do
            local fn = f.__scripts and f.__scripts.OnUpdate
            if fn then fn(f, dt) end
        end
        reste = reste - dt
    end
end

SLASH_LCM1, SLASH_LCM2 = nil, nil
SlashCmdList = {}

function __sansCouleur(texte)
    return (tostring(texte or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end
'''

CHARGEUR = """
    function(src, nom, chemin, ns)
        local f, e = loadstring(src, chemin)
        if not f then return e end
        local ok, err = pcall(f, nom, ns)
        if not ok then return err end
        return nil
    end
"""


def charger(chemin_scenario):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(PRELUDE)
    runner = lua.eval(CHARGEUR)

    for addon in ADDONS:
        toc = os.path.join(ROOT, addon, addon + '.toc')
        base = os.path.dirname(toc)
        fichiers = []
        for ligne in io.open(toc, encoding='utf-8-sig'):
            l = ligne.strip()
            if l and not l.startswith('#'):
                fichiers.append(os.path.join(base, l.replace(chr(92), '/')))
        lua.execute('__ns = __ns or {}')
        lua.execute('__ns["%s"] = __ns["%s"] or {}' % (addon, addon))
        espace = lua.eval('__ns["%s"]' % addon)
        for f in fichiers:
            src = io.open(f, encoding='utf-8').read()
            err = runner(src, addon, os.path.relpath(f, ROOT), espace)
            if err:
                print('ERREUR au chargement de ' + os.path.relpath(f, ROOT))
                print('   ' + str(err))
                return None
        lua.execute('__addonsCharges["%s"] = true' % addon)

    src = io.open(chemin_scenario, encoding='utf-8').read()
    err = lua.eval("""
        function(src, chemin)
            local f, e = loadstring(src, chemin)
            if not f then return "syntaxe : " .. tostring(e) end
            local ok, err = pcall(f)
            if not ok then return err end
            return nil
        end
    """)(src, os.path.basename(chemin_scenario))
    if err:
        print('ERREUR dans le scenario : ' + str(err))
        return None
    return lua


if __name__ == '__main__':
    arguments = [a for a in sys.argv[1:] if not a.startswith('--')]
    if sys.argv[1:2] and sys.argv[1] == '--addons':
        arguments = arguments[1:]
    if not arguments:
        print('usage: lcm_bench.py <scenario.lua> [--addons <dossier AddOns>]')
        sys.exit(2)
    print('AddOns : ' + ROOT)
    sys.exit(0 if charger(arguments[0]) is not None else 1)
