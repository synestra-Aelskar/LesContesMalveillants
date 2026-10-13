-- Une seconde action dans le meme composeur : les cases de types (penetrations)
-- sont creees a la premiere et resservent. Jusqu'au 13 octobre 2026, leur clic
-- jugeait avec le composeur de la PREMIERE action : apres une action couteuse,
-- cocher une penetration ne faisait plus rien, sauf pour les types deja pris
-- la premiere fois.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()
local E = LCM.Entities
local moi = E.Self()
E.Set_Value(moi, "pen_tranchant", 2)
E.Set_Value(moi, "pen_perforant", 2)
local R = LCM.UI.Radial

local f
local function choisir(libelle)
    for _, b in ipairs(f.boutons) do
        if b:IsShown() and b.o and b.o.label == libelle then b:Click() return true end
    end
    for _, c in ipairs(f.cases) do
        if c:IsShown() and c.o and c.o.label == libelle then c:Click() return true end
    end
    return false
end
-- Avance jusqu'a la question des penetrations physiques.
local function jusquAuxPenetrations(poids)
    choisir("Corps a corps") f.suivant:Click()
    choisir(poids) f.suivant:Click()
    choisir("Rand Adresse") f.suivant:Click()
    choisir("Brutale (Force)") f.suivant:Click()
    return f.question:GetText():find("Penetrations physiques", 1, true) ~= nil
end
local function coche(libelle)
    for _, c in ipairs(f.cases) do
        if c:IsShown() and c.o and c.o.label == libelle then return f.composeur:EstChoisie(f.q, c.o.id) end
    end
end

dire("== premiere action : puissante, on coche Tranchant, puis on renonce")
R.Trouver("attaque_simple").onClick()
f = LCM.UI.Composeur.frame
attendu("arrive aux penetrations", jusquAuxPenetrations("CaC puissant"), true)
choisir("Tranchant")
attendu("Tranchant coche", coche("Tranchant"), true)
local premier = f.composeur
f.fermer:Click()

dire("== seconde action, avec 1 PA : une attaque legere")
-- Il ne reste qu'un PA : la premiere composition (2 PA engages) ne passerait
-- plus, la seconde (1 PA) oui.
E.SetGauge(moi, "pa", 1)
R.Trouver("attaque_simple").onClick()
attendu("un nouveau composeur", f.composeur ~= premier, true)
attendu("arrive aux penetrations", jusquAuxPenetrations("CaC leger"), true)
choisir("Perforant")
attendu("un type que la premiere n'avait pas se coche", coche("Perforant"), true)
choisir("Tranchant")
attendu("un type qu'elle avait aussi", coche("Tranchant"), true)
f.fermer:Click()

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
