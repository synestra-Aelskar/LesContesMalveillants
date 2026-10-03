-- Sacs et sacoches : ou l'on peut les porter, et ce qu'ils contiennent.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()   -- ce scenario joue un personnage : il le dit
local I, S = LCM.Inventaire, LCM.Sacs

dire("== la nature d'un sac")
S.Add({ id = "grand_sac", label = "Grand sac", nature = "sac", places = 20 })
S.Add({ id = "petit_sac", label = "Petit sac", nature = "sac", places = 10 })
S.Add({ id = "grande_sacoche", label = "Grande sacoche", nature = "sacoche", places = 15 })
S.Add({ id = "sans_nature", label = "Sans nature", places = 8 })
attendu("un sac", S.Nature("grand_sac"), "sac")
attendu("une sacoche", S.Nature("grande_sacoche"), "sacoche")
attendu("sans precision, c'est un sac", S.Nature("sans_nature"), "sac")

dire("== l'encombrement : sa case, plus les siennes")
attendu("un sac de 10 occupe 11 cases", S.Encombrement("petit_sac"), 11)
attendu("une sacoche de 15 en occupe 16", S.Encombrement("grande_sacoche"), 16)

dire("== ou l'on porte quoi")
local moi = LCM.Entities.Self()
moi.inventaire = nil
attendu("un sac dans un emplacement de sac", (I.Poser(moi, "sacs", 1, "grand_sac")), true)
attendu("une sacoche aussi", (I.Poser(moi, "sacs", 2, "grande_sacoche")), true)
attendu("une sacoche dans un emplacement de sacoche",
    (I.Poser(moi, "saccoches", 1, "grande_sacoche")), true)
local ok, raison = I.Poser(moi, "saccoches", 2, "petit_sac")
attendu("un sac dans une sacoche : refus", ok, false)
attendu("et on dit pourquoi", tostring(raison):find("emplacement de sac") ~= nil, true)

dire("== ce qu'un contenant accepte")
local sacoche = I.Emplacement(moi, "saccoches", 1)
ok, raison = I.Ranger(moi, "saccoches", 1, 1, "sacs/petit_sac", 1)
attendu("un sac dans une sacoche : refus", ok, false)
attendu("et on le dit", tostring(raison):find("sacoche ne contient") ~= nil, true)
ok, raison = I.Ranger(moi, "saccoches", 1, 1, "sacs/grande_sacoche", 1)
attendu("une sacoche dans une sacoche : refus aussi", ok, false)

dire("== dans un sac, si ca tient")
-- Le grand sac a 20 places. Un sac de 10 en coute 11 : ca passe.
attendu("un sac de 10 dans un sac de 20", (I.Ranger(moi, "sacs", 1, 1, "sacs/petit_sac", 1)), true)
local reste = I.CasesLibres(I.Emplacement(moi, "sacs", 1))
attendu("il reste neuf places", reste, 9)
-- Une sacoche de 15 en coute 16 : elle ne tient plus.
ok, raison = I.Ranger(moi, "sacs", 1, 2, "sacs/grande_sacoche", 1)
attendu("une sacoche de 15 ne tient plus", ok, false)
attendu("et on dit combien il faudrait", tostring(raison):find("16 places libres") ~= nil, true)

dire("== la sacoche de depart")
local neuf = LCM.Personnages.Creer("Nouveau", { race = "humain", niveau = 5 })
local depart = I.Emplacement(neuf, "saccoches", 1)
attendu("elle est la", depart and depart.sac, "sacoche_de_depart")
attendu("cinq places", S.Get("sacoche_de_depart").places, 5)
attendu("c'est une sacoche", S.Nature("sacoche_de_depart"), "sacoche")
attendu("elle ne s'empile pas", S.Get("sacoche_de_depart").pileMax, 1)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
