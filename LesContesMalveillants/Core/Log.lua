-- Sorties chat. Un seul endroit : les messages doivent se ressembler, et on
-- doit pouvoir les couper tous d'un coup.

local _, LCM = ...

local PREFIX = "|cffc8a45eContes|r "
local COLORS = {
    info = "|cffe8dcc0",
    ok = "|cff6fc96f",
    alerte = "|cffe8b451",
    erreur = "|cffe86b6b",
}

local function Emit(kind, text)
    local frame = DEFAULT_CHAT_FRAME
    local color = COLORS[kind] or COLORS.info
    local line = PREFIX .. color .. tostring(text) .. "|r"
    if frame then frame:AddMessage(line) else print(line) end
end

function LCM.Info(text) Emit("info", text) end
function LCM.Ok(text) Emit("ok", text) end
function LCM.Alerte(text) Emit("alerte", text) end
function LCM.Erreur(text) Emit("erreur", text) end

-- Trace de developpement : muette tant que `/lcm debug` ne l'a pas activee.
function LCM.Debug(text)
    if not (LCM.db and LCM.db.settings and LCM.db.settings.debug) then return end
    Emit("info", "|cff888888[debug]|r " .. tostring(text))
end
