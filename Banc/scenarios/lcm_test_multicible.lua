-- Le prix d'une attaque MULTICIBLE (le MJ, 21 octobre 2026).
--
-- Le choix « Multicible » ne coute plus rien par lui-meme : c'est le NOMBRE de
-- cibles qui se paie, selon un bareme qui n'est pas lineaire.
--
--     cibles   1    2    3    4    5    6     au-dela
--     PA      +0   +0   +1   +1   +2   +2     2 + 0,5 par cible de plus
--     PF       2    5    8   12   16   20    20 + 4   par cible de plus
--
-- Viser plus large ne revient jamais moins cher, par cible, que viser moyen :
-- le cout marginal est de 3 PF, puis de 4, et il y reste.
--
-- Ce que ca remplace : « pa=1 pac=1/3 pfc=1 ». Le « /3 » n'a jamais voulu dire
-- « une cible sur trois » — le lecteur de couts s'arrete au premier nombre et
-- lisait 1, le diviseur n'etant ecrit nulle part. Une attaque sur trois cibles
-- coutait donc 1 + 3 PA la ou le MJ croyait en payer 1 + 1.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()
local A, UI = LCM.Actions, LCM.UI

dire("== le bareme, palier par palier")
local VOULU = {
    [1] = { 0, 2 }, [2] = { 0, 5 }, [3] = { 1, 8 },
    [4] = { 1, 12 }, [5] = { 2, 16 }, [6] = { 2, 20 },
}
for n = 1, 6 do
    local pa, pf = A.Bareme("multicible", n)
    attendu(string.format("%d cible(s)", n), pa .. " PA / " .. pf .. " PF",
        VOULU[n][1] .. " PA / " .. VOULU[n][2] .. " PF")
end

dire("== au-dela du dernier palier")
-- 2 PA + 0,5 par cible de plus ; 20 PF + 4 par cible de plus — le MEME rythme
-- que la fin de la table. La premiere ecriture n'en ajoutait que 2, et viser
-- dix cibles revenait alors moins cher PAR CIBLE que d'en viser six
-- (corrige le 23 octobre 2026).
for _, essai in ipairs({ { 7, 2.5, 24 }, { 8, 3, 28 }, { 10, 4, 36 }, { 16, 7, 60 } }) do
    local pa, pf = A.Bareme("multicible", essai[1])
    attendu(string.format("%d cibles", essai[1]), pa .. " PA / " .. pf .. " PF",
        essai[2] .. " PA / " .. essai[3] .. " PF")
end
attendu("aucune cible : rien", (A.Bareme("multicible", 0)), 0)
attendu("un bareme inconnu : rien du tout", (A.Bareme("berlingots", 3)), nil)

dire("== l'action demande le bareme, ou s'en passe")
local ctx = { vars = { baremeCibles = "multicible" } }
local pa, pf = A.Supplement(ctx, 4, false)
attendu("avec le bareme", pa .. "/" .. pf, "1/12")
-- Monocible : on ne paie qu'une cible, quoi qu'on en coche.
pa, pf = A.Supplement(ctx, 4, true)
attendu("monocible, on n'en paie qu'une", pa .. "/" .. pf, "0/2")
-- Sans bareme, le cout lineaire que l'action declare.
local lineaire = { vars = { _coutPAC = 1, _coutPFC = 2 } }
pa, pf = A.Supplement(lineaire, 3, false)
attendu("sans bareme, le coût déclaré", pa .. "/" .. pf, "3/6")
-- Et sans rien : la regle historique, une cible au-dela de la premiere.
local rien = { vars = {} }
pa, pf = A.Supplement(rien, 3, false)
attendu("sans rien, la règle historique", pa .. "/" .. pf, "2/2")
attendu("  monocible, rien", (A.Supplement(rien, 3, true)), 0)

dire("== le bouton d'attaque le demande")
-- Les trois boutons de la famille attaque (simple, perce-armure,
-- brise-armure) partagent le meme bloc de ciblage.
local boutons = { "attaque_simple", "perce_armure", "brise_armure" }
-- DuBouton prend le nom du BOUTON ; Get prend l'identifiant de l'action.
local function Questions(def)
    for _, feuille in ipairs(def and def.feuilles or {}) do
        for _, e in ipairs(feuille.etapes or {}) do
            if e.questionsText and e.questionsText ~= "" then return e.questionsText end
        end
    end
    return ""
end
for _, nom in ipairs(boutons) do
    local def = LCM.ActionsBoutons.DuBouton(nom)
    attendu(nom .. " : le bouton existe", def ~= nil, true)
    local texte = Questions(def)
    attendu(nom .. " : multicible demande le barème",
        texte:find("baremeCibles=multicible", 1, true) ~= nil, true)
    attendu("  et ne coûte plus rien par lui-même",
        texte:find("Multicible | pa=1", 1, true), nil)
end

dire("== un demi-PA s'écrit « 2,5 », pas « 3 »")
-- Le debit, lui, ne s'arrondit pas : afficher 3 ferait lire un prix qu'on ne
-- paie pas.
attendu("sept", UI.Nombre(2.5), "2,5")
attendu("entier", UI.Nombre(2), "2")
attendu("rien", UI.Nombre(nil), "?")

dire("== la fenêtre de ciblage l'annonce")
local f = UI.Resolution.cibles or (UI.Resolution.Cibler and nil)
-- On ouvre la fenetre par la porte normale, avec un contexte minimal.
UI.Resolution.Cibler({ vars = { baremeCibles = "multicible", _coutPA = 1, _coutPF = 2 },
    entity = LCM.Entities.Self(), declaration = { nature = "Attaque" } }, false, function() end)
f = UI.Resolution.cibles
attendu("la fenêtre est là", f ~= nil and f:IsShown(), true)
attendu("  et elle se dit multicible", f.mode:GetText(), "multicible")
f:Hide()

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
