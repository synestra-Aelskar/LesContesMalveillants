-- Autorisations de lecture des traits, gerees par le MJ et envoyees a la
-- demande. Les definitions restent dans l'addon commun ; les joueurs ne
-- voient que les identifiants coches pour eux dans les interfaces du jeu.

local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end

local Acces = {}
MJ.AccesTraits = Acces
LCM.AccesTraits = Acces

local function Cle(joueur)
    local nom = tostring(joueur or ""):match("^([^-]+)") or tostring(joueur or "")
    return (nom:lower():gsub("%s+", ""))
end

local function Base()
    _G.LCM_MJ_DB = type(_G.LCM_MJ_DB) == "table" and _G.LCM_MJ_DB or {}
    _G.LCM_MJ_DB.traitsAutorises = type(_G.LCM_MJ_DB.traitsAutorises) == "table"
        and _G.LCM_MJ_DB.traitsAutorises or {}
    return _G.LCM_MJ_DB.traitsAutorises
end

function Acces.Liste(joueur)
    local tous = Base()[Cle(joueur)] or {}
    local ids = {}
    for id, autorise in pairs(tous) do
        if autorise and LCM.Traits.Get(id) then ids[id] = true end
    end
    return ids
end

function Acces.Envoyer(joueur)
    joueur = tostring(joueur or "")
    if joueur == "" then return false end
    return LCM.Reseau.Envoyer("traits_acces", { ids = Acces.Liste(joueur) }, "WHISPER", joueur,
        { etale = true })
end

function Acces.Definir(joueur, traitId, autorise)
    joueur, traitId = tostring(joueur or ""), tostring(traitId or "")
    if joueur == "" or not LCM.Traits.Get(traitId) then return false end
    local base = Base()
    local cle = Cle(joueur)
    base[cle] = type(base[cle]) == "table" and base[cle] or {}
    if autorise then base[cle][traitId] = true else base[cle][traitId] = nil end
    Acces.Envoyer(joueur)
    return true
end

LCM.WhenReady(function()
    LCM.Reseau.Ecouter("traits_acces_demande", function(expediteur)
        if LCM.Reseau.DansLeGroupe(expediteur) then Acces.Envoyer(expediteur) end
    end)
end)
