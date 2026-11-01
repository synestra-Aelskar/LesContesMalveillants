-- L'initiative qui bouge PENDANT le combat (1er novembre 2026).
--
-- Un buff ou un debuff d'initiative ne relancait rien : le score fige au
-- lancement restait le meme tout le combat. Il doit maintenant se DEPLACER de
-- l'ecart, sans relancer le de — « 10 + 4 d'initiative » plus un buff de 4
-- fait 18, avec le meme de.
--
-- Et surtout, il ne doit jamais rendre un tour : seules les entrees qui n'ont
-- pas encore joue dans le round se retrient. Au mieux le changement retarde le
-- moment de jeu, au pire il n'agit qu'au round suivant, quand l'ordre se refait
-- en entier.

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
__groupe({})

local C, I, T = LCM.Combat, LCM.Incarnation, LCM.EtatsTemporaires

-- Quatre PNJ : le MJ les tient tous, donc il lit leurs bonus et peut arbitrer
-- sans passer par le reseau.
local gardes, ids = {}, {}
for index = 1, 4 do
    gardes[index] = I.Instancier(LCM.PNJ.list[1].id, "Garde " .. index)
    ids[index] = gardes[index].id
end
-- Sans le MJ : quatre entrees qu'il tient toutes, et rien d'aleatoire
-- de plus dans l'ordre.
local etat = C.Inviter({ pnj = ids, moi = false })
attendu("quatre combattants", #etat.entrees, 4)

-- Des scores choisis plutot que tires : le de du lancement est aleatoire, et
-- ce qu'on verifie ici c'est l'ECART, pas le jet.
local parId = {}
for _, entree in ipairs(etat.entrees) do parId[entree.id] = entree end
for index, valeur in ipairs({ 20, 15, 10, 5 }) do parId[ids[index]].v = valeur end
C.Trier(etat.entrees)
local function place(id)
    for index, entree in ipairs(etat.entrees) do if entree.id == id then return index end end
end
local function score(id) return parId[id].v end
attendu("ordre de depart", table.concat({ place(ids[1]), place(ids[2]), place(ids[3]), place(ids[4]) }, ","),
    "1,2,3,4")

dire("== un buff deplace le score, il ne relance pas le de")
C.Avancer(1)
etat = C.Etat()   -- Avancer applique une COPIE : la reference change
attendu("le deuxieme joue", etat.c, 2)
T.Poser(gardes[4], { nom = "Hate", rounds = 3, bonus = { initiative = 8 } })
etat = C.Etat()
parId = {}
for _, entree in ipairs(etat.entrees) do parId[entree.id] = entree end
attendu("le quatrieme gagne exactement 8", score(ids[4]), 13)
attendu("et personne d'autre ne bouge", score(ids[1]) .. "," .. score(ids[2]) .. "," .. score(ids[3]),
    "20,15,10")

dire("== il ne peut remonter que parmi ceux qui n'ont pas joue")
-- 13 passe devant 10, mais pas devant 15 ni 20 : ces deux-la ont deja joue, ou
-- jouent en ce moment. Rejouer dans le round est le seul interdit.
attendu("le quatrieme passe troisieme", place(ids[4]), 3)
attendu("l'ancien troisieme recule", place(ids[3]), 4)
attendu("celui qui a joue garde sa place", place(ids[1]), 1)
attendu("celui qui joue aussi", place(ids[2]), 2)
attendu("  et c'est toujours son tour", etat.c, 2)

dire("== un debuff sur celui qui joue ne lui prend pas son tour")
T.Poser(gardes[2], { nom = "Lourdeur", rounds = 3, bonus = { initiative = -12 }, debuff = true })
etat = C.Etat()
parId = {}
for _, entree in ipairs(etat.entrees) do parId[entree.id] = entree end
attendu("son score tombe a 3", score(ids[2]), 3)
attendu("il reste a sa place", place(ids[2]), 2)
attendu("  et finit son tour", etat.c, 2)

dire("== au round suivant, l'ordre se refait en entier")
local round = etat.r
for _ = 1, 4 do C.Avancer(1) end
etat = C.Etat()
attendu("un round de plus", etat.r ~= round, true)
attendu("le premier reste premier", place(ids[1]), 1)
attendu("le quatrieme, monte a 13, passe deuxieme", place(ids[4]), 2)
attendu("le troisieme suit", place(ids[3]), 3)
attendu("et celui qu'on a alourdi ferme la marche", place(ids[2]), 4)

dire("== sans changement, rien ne bouge")
local avant = score(ids[1])
T.Poser(gardes[1], { nom = "Marque", rounds = 2, bonus = { force = 3 } })
etat = C.Etat()
parId = {}
for _, entree in ipairs(etat.entrees) do parId[entree.id] = entree end
attendu("un bonus qui ne touche pas l'initiative ne la touche pas", score(ids[1]), avant)

C.Terminer()
dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
