-- L'attaque du MJ, remaniee le 1er novembre 2026.
--
-- Trois demandes, trois verifications :
--
--   * le degat CRITIQUE n'est plus obligatoire. Un champ vide laisse passer
--     « Suivant » et vaut le degat normal ;
--   * « Perce-armure » devient « Brise / Perce » : deux parts a cocher, en
--     pourcent du degat, dont la somme ne peut pas depasser cent. Le
--     brise-armure impose ensuite une part sur l'armure, comme le
--     perce-armure en impose une en sante ;
--   * le jet oppose se coche. Sans lui, la cible encaisse les degats normaux
--     sans qu'aucun jet ne lui soit demande.

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
LCM._masterCompanion = true
__addonsCharges["LesContesMalveillants_MJ"] = true

local A = LCM.Actions
local R = LCM.UI.Radial

-- On lit les questions telles que le bouton les porte : c'est la source de
-- verite, et le composeur n'est qu'un affichage par-dessus.
local bouton = LCM.ActionsBoutons.Get("attaque_mj")
attendu("le bouton existe", bouton ~= nil, true)
local compose
for _, etape in ipairs(bouton.feuilles[1].etapes) do
    if etape.type == "compose" then compose = etape end
end
local questions = A.LireQuestions(compose.questionsText)
local parLabel = {}
for _, q in ipairs(questions) do parLabel[q.label] = q end

dire("== le degat critique est facultatif")
local critique
for label, q in pairs(parLabel) do
    if label:find("critique", 1, true) then critique = q end
end
attendu("la question existe", critique ~= nil, true)
attendu("  elle est declaree facultative", critique.facultatif, true)
attendu("  et retombe sur le degat normal", critique.defaut, "{var:dmgN}")

dire("== Brise / Perce est une repartition")
local repart
for label, q in pairs(parLabel) do
    if q.mode == "repartition" then repart = q end
end
attendu("la question existe", repart ~= nil, true)
attendu("  deux parts", #repart.options, 2)
attendu("  lues sur le degat normal", repart.base, "{var:dmgN}")
local vars = {}
for _, o in ipairs(repart.options) do vars[#vars + 1] = o.set:match("var%s*=%s*([%w_]+)") end
table.sort(vars)
attendu("  qui nomment leurs variables", table.concat(vars, ","), "briseArmure,perceArmure")

dire("== le jet oppose se choisit")
local oppose = parLabel["La cible oppose-t-elle un jet ?"]
attendu("la question existe", oppose ~= nil, true)
local stat = parLabel["Stat de l'attaque (ce que la cible opposera)"]
attendu("la stat ne se demande qu'avec un jet", stat and stat.showIf, "var:jetOppose == oui")

dire("== au composeur : on passe le critique sans rien taper")
R.Trouver("attaque_mj").onClick()
local f = LCM.UI.Composeur.frame
local c = f.composeur
local function allerA(motif)
    for _ = 1, 12 do
        if f.question:GetText():find(motif, 1, true) then return true end
        if not f.suivant:IsEnabled() then return false end
        f.suivant:Click()
    end
    return false
end
attendu("la premiere question est le degat normal", f.question:GetText():find("Dégât normal", 1, true) ~= nil, true)
-- Comme une frappe au clavier : le champ previent le composeur, qui reevalue
-- « Suivant » sans refaire tout le rendu (le curseur y survit).
c:Saisir(f.q, "40")
LCM.UI.Composeur.Rendre()
attendu("on peut avancer", f.suivant:IsEnabled(), true)
f.suivant:Click()
attendu("on arrive au critique", f.question:GetText():find("critique", 1, true) ~= nil, true)
attendu("  « Suivant » est deja ouvert, sans rien taper", f.suivant:IsEnabled(), true)
attendu("  et le critique vaut le normal", c.ctx.vars.dmgC, 40)
attendu("  le recapitulatif le dit", c:Choix(f.q), "40 (par défaut)")
f.suivant:Click()

dire("== la repartition Brise / Perce")
attendu("on y est", f.question:GetText():find("Brise / Perce", 1, true) ~= nil, true)
local qr = f.q
local brise, perce = qr.options[1], qr.options[2]
attendu("la barre se lit sur 40", c:Base(qr), 40)
c:Part(qr, brise.id, 30)
c:Part(qr, perce.id, 30)
attendu("soixante pour cent engages", (c:Repartition(qr)), 60)
attendu("  la brise passe en variable", c.ctx.vars.briseArmure, 30)
attendu("  la perce aussi", c.ctx.vars.perceArmure, 30)
LCM.UI.Composeur.Rendre()
attendu("  et « Suivant » reste ouvert", f.suivant:IsEnabled(), true)
c:Part(qr, perce.id, 80)
LCM.UI.Composeur.Rendre()
attendu("au-dela de cent, on ne passe plus", f.suivant:IsEnabled(), false)
c:Part(qr, perce.id, 20)
LCM.UI.Composeur.Rendre()
attendu("  revenu a cinquante, on repasse", f.suivant:IsEnabled(), true)
c:Part(qr, brise.id, nil)
attendu("une part decochee vaut zero, pas rien", c.ctx.vars.briseArmure, 0)
f.fermer:Click()

dire("== le brise-armure impose une part sur l'armure")
-- Le jeton `recu:` lit `ctx.paquet.valeurs` ; on le monte a la main plutot que
-- de rejouer tout un echange reseau.
local ctx = { vars = {}, entity = LCM.Entities.Self(),
              paquet = { valeurs = { ["Brise armure"] = 40, ["Perce armure"] = 0 } } }
attendu("quarante pour cent", A.BrisePourcentage(ctx), 40)
attendu("sur dix points, quatre partent sur l'armure", A.BriseMinimum(ctx, 10), 4)
attendu("arrondi au superieur", A.BriseMinimum(ctx, 11), 5)
attendu("sans brise-armure, rien n'est impose",
    A.BriseMinimum({ vars = {}, paquet = { valeurs = {} } }, 10), 0)
-- Et il ne depasse jamais ce qu'on encaisse : cent pour cent de dix, c'est dix.
local tout = { vars = {}, paquet = { valeurs = { ["Brise armure"] = 100 } } }
attendu("borne au montant", A.BriseMinimum(tout, 10), 10)

dire("== la reception reconnait une attaque sans jet oppose")
-- La branche posee en tete de « Defense (auto v3) » : sans elle, le joueur se
-- voyait quand meme demander un jet.
local function recuAvec(valeurs) return { vars = {}, entity = LCM.Entities.Self(), paquet = { valeurs = valeurs } } end
attendu("« non » prend la branche qui fait encaisser",
    A.Condition("recu:Jet oppose contient non", recuAvec({ ["Jet oppose"] = "non" })), true)
attendu("« oui » ne la prend pas",
    A.Condition("recu:Jet oppose contient non", recuAvec({ ["Jet oppose"] = "oui" })), false)
-- Une declaration d'avant ce changement ne porte pas le tag du tout : elle
-- doit continuer a passer par les branches de jet.
attendu("une vieille declaration ne la prend pas non plus",
    A.Condition("recu:Jet oppose contient non", recuAvec({})), false)
-- Et elle doit etre la PREMIERE branche : la premiere vraie l'emporte.
local defense = LCM.ActionsBoutons.Get("defense_auto_v3")
attendu("la reception existe", defense ~= nil, true)
-- Le pas « Stat utilisée » : on le cherche dans toutes les feuilles, la
-- reception en compte plusieurs et leur ordre n'est pas garanti.
local function Trouver(noeud, id, profondeur)
    if type(noeud) ~= "table" or (profondeur or 0) > 8 then return nil end
    if noeud.id == id then return noeud end
    for _, valeur in pairs(noeud) do
        local trouve = Trouver(valeur, id, (profondeur or 0) + 1)
        if trouve then return trouve end
    end
    return nil
end
local pas = Trouver(defense.feuilles, "st_parC")
attendu("le pas du jet oppose existe", pas ~= nil, true)
attendu("et notre branche passe avant les siennes", pas and pas.branches[1] and pas.branches[1].id, "b_parSubir")

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
