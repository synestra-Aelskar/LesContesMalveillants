-- Crossings : le brouillard, et d'ou viennent les noms (3 novembre 2026).
--
-- Deux savoirs distincts, et c'est volontaire :
--
--   * le TERRAIN se decouvre en marchant. Un brouillard garde ce qu'on a vu,
--     dans un rayon donne par l'expertise Vue, et la carte ne montre que ca.
--
--   * les NOMS, eux, ne s'apprennent pas en marchant. On peut traverser le
--     Sahara trois jours : si personne ne vous a dit que c'etait le Sahara,
--     vous n'en savez pas le nom en sortant. Ils viennent d'une connaissance
--     DONNEE — par le MJ aujourd'hui, par un objet demain.
--
-- Le MJ, lui, voit tout. Sauf en mode joueur : la bascule doit valoir pour
-- lui aussi, sinon elle ne sert a rien.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end
local function essai(libelle, fn)
    local ok, err = pcall(fn)
    attendu(libelle, ok and "ok" or tostring(err), "ok")
end

__declencher("PLAYER_LOGIN")
__personnage()
LCM.db.settings.modeJoueur = nil
LCM._masterCompanion = true

local ZG = LCM.Crossings

local function Poser(x, y) __position(y, x, 0) end
local function Tracer(sub, points)
    for _, p in ipairs(points) do
        Poser(p[1], p[2])
        ZG:AddRegionPoint(sub.id)
    end
    return sub
end
local function ZoneDuLieu(place) return ZG:GetPlaceAreas(place.id)[1].sub end
local function Joueur() LCM.db.settings.modeJoueur = true; LCM._masterCompanion = nil end
local function Maitre() LCM.db.settings.modeJoueur = nil; LCM._masterCompanion = true end

local pays = ZG:CreateCountry("Le Vieux Monde")
local proche = ZG:CreateZone("La Combe", pays.id)
local loin = ZG:CreateZone("Les Marches Grises", pays.id)
local village = ZG:CreatePlace(proche.id, "Le Village")
local ruine = ZG:CreatePlace(proche.id, "La Ruine")
local ailleurs = ZG:CreatePlace(loin.id, "Le Donjon")
local V = Tracer(ZoneDuLieu(village), { { 0, 0 }, { 60, 0 }, { 60, 60 }, { 0, 60 } })
local R = Tracer(ZoneDuLieu(ruine), { { 200, 200 }, { 260, 200 }, { 260, 260 }, { 200, 260 } })
local D = Tracer(ZoneDuLieu(ailleurs), { { 900, 900 }, { 960, 900 }, { 960, 960 }, { 900, 960 } })
for _, s in ipairs({ V, R, D }) do ZG:FinishRegion(s.id) end

local perso = __personnage()
LCM.Personnages.Choisir(perso.id)

dire("== le MJ voit tout, meme sans avoir marche")
attendu("il connait sa region", ZG:HasLearnedZoneName(proche.id), true)
attendu("  et son pays", ZG:HasLearnedCountryName(pays.id), true)
attendu("  et le terrain n'a pas de brouillard pour lui", ZG:EstVu(1, 9999, 9999), true)

dire("== en joueur, l'auteur ne sait rien de plus qu'un autre")
-- C'est tout l'interet de la bascule. Le test « je suis l'auteur, donc je
-- sais » la court-circuitait, et le MJ voyait tout son travail.
Joueur()
attendu("il ne connait plus sa region", ZG:HasLearnedZoneName(proche.id), false)
attendu("  ni son pays", ZG:HasLearnedCountryName(pays.id), false)
attendu("  et le terrain lui est voile", ZG:EstVu(1, 9999, 9999), false)

dire("== marcher ne donne AUCUN nom")
ZG.quietUntil = 0
Poser(500, 500); ZG:Tick()
Poser(30, 30); ZG:Tick()
attendu("on est bien entre dans le village", ZG:IsInPlace(village.id), true)
attendu("  son nom reste inconnu", ZG:KnowsPlaceName(village), false)
attendu("  celui de la region aussi", ZG:HasLearnedZoneName(proche.id), false)
attendu("  celui du pays aussi", ZG:HasLearnedCountryName(pays.id), false)

dire("== un nom DONNE s'apprend, et se reprend")
Maitre()
ZG:MarkLearnedZoneName(proche.id, true)
ZG:MarkLearnedSubZoneName(village.id, true)
Joueur()
attendu("la region donnee est connue", ZG:HasLearnedZoneName(proche.id), true)
attendu("  le lieu donne aussi", ZG:KnowsPlaceName(village), true)
attendu("  mais pas ce qu'on n'a pas donne", ZG:KnowsPlaceName(ruine), false)
attendu("  ni la region voisine", ZG:HasLearnedZoneName(loin.id), false)
Maitre(); ZG:ForgetLearnedZoneName(proche.id); Joueur()
attendu("et un nom repris redevient inconnu", ZG:HasLearnedZoneName(proche.id), false)

dire("== le brouillard se leve la ou l'on passe")
-- La portee, c'est la perception visuelle : 20 yards par point de Vue, avec
-- un plancher de 10 — une Vue nulle, ou negative sous un malus, ne rend pas
-- aveugle. Sans plancher la portee tombait a zero et plus rien ne se
-- devoilait : le brouillard passait pour une panne.
LCM.Entities.Set_Value(perso, "vue", 0)
attendu("sans Vue, il reste le plancher", ZG:RayonDeVue(), 10)
LCM.Entities.Set_Value(perso, "vue", -5)
attendu("une Vue negative ne rend pas aveugle", ZG:RayonDeVue(), 10)
LCM.Entities.Set_Value(perso, "vue", 8)
attendu("8 points de Vue : 160 yards", ZG:RayonDeVue(), 160)
LCM.Entities.Set_Value(perso, "vue", 3)
attendu("3 points de Vue : 60 yards", ZG:RayonDeVue(), 60)

ZG:OublierDecouvertes()
attendu("tout oublie : on ne voit plus rien", ZG:EstVu(1, 30, 30), false)
Poser(30, 30); ZG:Tick()
attendu("on voit sous ses pieds", ZG:EstVu(1, 30, 30), true)
-- Un disque, pas un carre : a 59 yards on voit, a 61 non.
attendu("  et jusqu'au bout de la portee", ZG:EstVu(1, 30, 88), true)
attendu("  mais pas au-dela", ZG:EstVu(1, 30, 95), false)
-- En diagonale, le coin du carre serait a 60 : le disque, lui, s'arrete avant.
attendu("  le coin en diagonale reste voile", ZG:EstVu(1, 74, 74), false)
attendu("  et le lointain plus encore", ZG:EstVu(1, 400, 400), false)

-- On marche : le chemin reste derriere nous.
for d = 60, 240, 30 do Poser(d, d); ZG:Tick() end
attendu("le chemin parcouru est devoile", ZG:EstVu(1, 150, 150), true)
attendu("  jusqu'a son bout", ZG:EstVu(1, 240, 240), true)
attendu("  mais pas de cote", ZG:EstVu(1, 150, 400), false)

dire("== /lcm reset map rend la page blanche")
-- Reservee au MJ, en deux temps : effacer des mois de decouvertes ne doit pas
-- tenir a une faute de frappe.
Maitre()
ZG:MarkLearnedZoneName(proche.id, true)
Joueur()
Poser(30, 30); ZG:Tick()
attendu("on a de quoi oublier", ZG:EstVu(1, 30, 30), true)
attendu("  et un nom donne", ZG:HasLearnedZoneName(proche.id), true)

Maitre()
essai("le premier appel ne fait qu'avertir", function() SlashCmdList["LCM"]("reset map") end)
Joueur()
attendu("rien n'est efface", ZG:EstVu(1, 30, 30), true)

Maitre()
essai("le second efface", function() SlashCmdList["LCM"]("reset map") end)
Joueur()
attendu("le brouillard est retombe", ZG:EstVu(1, 30, 30), false)
attendu("  et les noms sont oublies", ZG:HasLearnedZoneName(proche.id), false)

-- Sans argument, elle explique au lieu d'effacer.
Poser(30, 30); ZG:Tick()
Maitre()
essai("sans argument, elle explique", function() SlashCmdList["LCM"]("reset") end)
Joueur()
attendu("  et n'efface rien", ZG:EstVu(1, 30, 30), true)

-- Et un joueur ne l'a pas : c'est une commande de MJ.
essai("un joueur ne peut pas l'appeler", function() SlashCmdList["LCM"]("reset map") end)
essai("  deux fois non plus", function() SlashCmdList["LCM"]("reset map") end)
attendu("  rien n'a bouge", ZG:EstVu(1, 30, 30), true)

Maitre()
dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
