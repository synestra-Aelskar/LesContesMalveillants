-- Les mecaniques de DEFENSE (11 octobre 2026).
--
-- On n'y investit pas pour agir mais pour encaisser. Deux sortes, et elles ne
-- se melangent pas : la Defense retire un pourcentage des DEGATS, les autres
-- ajoutent au JET de defense contre les actions auxquelles on resiste.

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

local D, E = LCM.Defenses, LCM.Equilibrage
local moi = LCM.Entities.Self()

dire("== la liste existe, et chaque défense dit contre quoi elle vaut")
attendu("sept défenses", #E.defenses, 7)
local attendues = {
    defense = "attaque_simple", resilience_mentale = "confusion", esprit_libre = "provocation",
    courage = "peur", insensible = "dot", stable = "attraction", agilite = "immobilisation",
}
for id, contre in pairs(attendues) do
    local d = D.Get(id)
    attendu("  " .. id, d ~= nil, true)
    local trouve = false
    for _, c in ipairs(d and d.contre or {}) do if c == contre then trouve = true end end
    attendu("    tient " .. contre, trouve, true)
end

dire("== elles ont un champ de fiche, et il est dans le bon dossier")
attendu("le champ se nomme def_courage", D.Field("courage"), "def_courage")
local cat
for _, c in ipairs(LCM.Compendium.categories) do if c.id == "traits" then cat = c end end
local dossier, autres = 0, 0
for _, champ in ipairs(LCM.Compendium.Champs(cat)) do
    if champ.dossier == "Mécanique de défense" then dossier = dossier + 1 end
    if champ.dossier == "Autres" and tostring(champ.cle):find("^def_") then autres = autres + 1 end
end
attendu("les sept sont dans leur dossier", dossier, 7)
attendu("et aucune dans « Autres »", autres, 0)

dire("== on y investit à la création, sur le budget des mécaniques")
local lignes = LCM.Creation.Lignes("mecaniques")
local nDef = 0
for _, l in ipairs(lignes) do if tostring(l.id):find("^def_") then nDef = nDef + 1 end end
attendu("les sept sont proposées", nDef, 7)
attendu("avec les mécaniques de compétence", #lignes, #E.mecaniques + 7)
-- Meme plafond que les mecaniques de competence : c'est le meme budget.
local brouillon = { niveau = 5 }
attendu("et le même plafond",
    LCM.Creation.Plafond(brouillon, "mecaniques", "def_courage"),
    LCM.Creation.Plafond(brouillon, "mecaniques", "meca_attaque_simple"))

dire("== le bonus au jet de défense suit les points investis")
moi.def_courage = 4
attendu("Courage 4 contre la peur", (D.BonusRand(moi, "peur")), 2)
attendu("  et contre l'intimidation aussi", (D.BonusRand(moi, "intimidation")), 2)
attendu("  mais pas contre la confusion", (D.BonusRand(moi, "confusion")), 0)
moi.def_resilience_mentale = 3
attendu("Résilience 3 contre la confusion", (D.BonusRand(moi, "confusion")), 1.5)
attendu("  contre le contrôle mental", (D.BonusRand(moi, "controle_mental")), 1.5)
attendu("  contre l'illusion", (D.BonusRand(moi, "illusion")), 1.5)
moi.def_insensible = 2
attendu("Insensible 2 contre le dot", (D.BonusRand(moi, "dot")), 1)
attendu("  et contre le debuff", (D.BonusRand(moi, "debuff")), 1)
moi.def_stable = 6
attendu("Stable 6 contre la répulsion", (D.BonusRand(moi, "repulsion")), 3)
moi.def_agilite = 1
attendu("Agilité 1 contre l'entrave", (D.BonusRand(moi, "entrave")), 0.5)
moi.def_esprit_libre = 5
attendu("Esprit libre 5 contre la provocation", (D.BonusRand(moi, "provocation")), 2.5)

dire("== le détail dit d'où vient le bonus")
-- Un jet qui monte sans qu'on sache pourquoi est un jet qu'on soupconne.
local bonus, detail = D.BonusRand(moi, "peur")
attendu("une seule défense répond", #detail, 1)
attendu("  et elle se nomme", detail[1] and detail[1].label, "Courage")
attendu("  avec ses points", detail[1] and detail[1].points, 4)
attendu("le résumé se lit", (D.Resume(moi, "peur")), "Courage 4 (+2)")

dire("== la Défense, elle, retire des dégâts")
moi.def_defense = 5
attendu("5 points font 15 %", string.format("%.2f", (D.Reduction(moi, "attaque_simple"))), "0.15")
attendu("  contre le perce-armure aussi",
    string.format("%.2f", (D.Reduction(moi, "perce_armure"))), "0.15")
attendu("  et le brise-armure", string.format("%.2f", (D.Reduction(moi, "brise_armure"))), "0.15")
attendu("mais pas contre la peur", (D.Reduction(moi, "peur")), 0)
attendu("et elle ne touche pas au jet", (D.BonusRand(moi, "attaque_simple")), 0)

dire("== ce qui passe quand même")
local restant, evite = D.Encaisses(moi, "attaque_simple", 100)
attendu("100 dégâts, 15 % retirés", restant, 85)
attendu("  et 15 évités", evite, 15)
-- On arrondit au SUPERIEUR ce qui reste : une reduction ne doit pas effacer
-- une attaque qui a touche.
attendu("7 dégâts en laissent 6", (D.Encaisses(moi, "attaque_simple", 7)), 6)
attendu("1 dégât en laisse 1", (D.Encaisses(moi, "attaque_simple", 1)), 1)
attendu("sans défense, rien ne change", (D.Encaisses(moi, "peur", 40)), 40)

dire("== et elle ne rend jamais invulnérable")
moi.def_defense = 100
attendu("cent points plafonnent",
    string.format("%.2f", (D.Reduction(moi, "attaque_simple"))), "0.90")
attendu("il passe toujours quelque chose", (D.Encaisses(moi, "attaque_simple", 100)), 10)
attendu("et au moins un point", (D.Encaisses(moi, "attaque_simple", 2)), 1)
moi.def_defense = 0

dire("== une mécanique sans défense dédiée n'en a pas")
-- On ne se defend pas contre un soin, et c'est voulu.
for _, id in ipairs({ "soin", "bouclier", "creation", "buff" }) do
    attendu("  " .. id, #D.Contre(id), 0)
end

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
