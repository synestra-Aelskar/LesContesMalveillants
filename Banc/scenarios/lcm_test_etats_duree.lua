-- La DUREE decide du logement d'un etat (le MJ, 24 octobre 2026).
--
--   * sans duree, un etat impose par le MJ n'a rien de temporaire : il rejoint
--     les etats PORTES, dans l'emplacement de son conteneur ;
--   * avec une duree, il va dans la liste des etats temporaires et compte ses
--     rounds ;
--   * changer la duree en seance le DEPLACE d'une liste a l'autre.
--
-- Et ce qu'un etat coute a lever au campement : son nombre de points NEGATIFS,
-- et non le pool de sa rarete.
--
-- Contenu TEMOIN : jeu et etats d'essai, jamais ceux de la campagne.

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
local moi = LCM.Entities.Self()
local T = LCM.EtatsTemporaires

-- Un jeu d'equilibrage temoin : sans lui, une entree n'a pas de prix, et le
-- campement renvoie « c'est au MJ de le retirer » au lieu d'un cout.
LCM.Forge.Add({ id = "jeu_duree_temoin", label = "Jeu durée témoin", categorie = "etats",
    raretes = { { id = "commun", label = "Commun", points = 200, couleur = "FF8CB8" } },
    champs = {} })

LCM.Etats.Add({ id = "vertige_temoin", label = "Vertige témoin", categorie = "etat",
    forge = "jeu_duree_temoin/commun", bonus = { force = -6 } })
LCM.Etats.Add({ id = "souffle_temoin", label = "Souffle témoin", categorie = "etat",
    forge = "jeu_duree_temoin/commun", bonus = { force = 4 } })

local vertige = LCM.Etats.Get("vertige_temoin")
local souffle = LCM.Etats.Get("souffle_temoin")

local function Porte(id)
    for _, porte in ipairs(LCM.Etats.Ids(moi, "etat")) do
        if porte == id then return true end
    end
    return false
end
local function Temporaire(nom)
    for _, e in ipairs(T.Liste(moi)) do if e.nom == nom then return e end end
    return nil
end
local function Vider()
    local liste = T.Liste(moi)
    for i = #liste, 1, -1 do T.RetirerForce(moi, liste[i].nom) end
    for _, id in ipairs(LCM.Etats.Ids(moi, "etat")) do LCM.Etats.Enlever(moi, id) end
end

dire("== sans duree, l'etat impose est PORTE")
Vider()
local ok, raison = T.Imposer(moi, vertige, nil)
attendu("l'état est posé " .. tostring(raison), ok, true)
attendu("  il est porté", Porte("vertige_temoin"), true)
attendu("  et pas dans les temporaires", Temporaire("Vertige témoin"), nil)

dire("== avec une duree, il est TEMPORAIRE")
Vider()
attendu("l'état est posé", T.Imposer(moi, vertige, 3), true)
attendu("  il n'est pas porté", Porte("vertige_temoin"), false)
local pose = Temporaire("Vertige témoin")
attendu("  il est temporaire", pose ~= nil, true)
attendu("  avec sa durée", pose and pose.restant, 3)

dire("== changer la duree deplace l'etat")
attendu("une autre durée", T.FixerDuree(moi, "Vertige témoin", 5), true)
attendu("  elle est posée", Temporaire("Vertige témoin").restant, 5)
attendu("plus de durée", T.FixerDuree(moi, "Vertige témoin", nil, "vertige_temoin"), true)
attendu("  il quitte les temporaires", Temporaire("Vertige témoin"), nil)
attendu("  et rejoint les états portés", Porte("vertige_temoin"), true)
attendu("une durée rendue", T.FixerDuree(moi, "Vertige témoin", 2, "vertige_temoin"), true)
attendu("  il quitte les états portés", Porte("vertige_temoin"), false)
attendu("  et redevient temporaire", Temporaire("Vertige témoin").restant, 2)

dire("== une duree qui n'en est pas une est refusee")
local refus, pourquoi = T.FixerDuree(moi, "Vertige témoin", 0)
attendu("zéro round est refusé", refus, false)
attendu("  et elle dit pourquoi", tostring(pourquoi):find("entier positif") ~= nil, true)
attendu("  la durée d'avant tient", Temporaire("Vertige témoin").restant, 2)
attendu("un état absent est refusé", select(1, T.FixerDuree(moi, "Rien du tout", 3)), false)

dire("== le cout en PS, ce sont les points NEGATIFS")
-- -6 de Force au cout par defaut (1/pt), rembourses de moitie : 3 points
-- negatifs, donc 3 PS a 1 PS le point.
attendu("l'état témoin retire 3 pts", LCM.Campement.PointsNegatifs(vertige), 3)
attendu("  et se lève pour 3 PS", LCM.Campement.CoutEtat(vertige), 3)
attendu("un état qui ne retire rien ne coûte rien", LCM.Campement.CoutEtat(souffle), 0)
local sansJeu = { id = "sans_jeu_temoin", label = "Sans jeu témoin", bonus = { force = -2 } }
attendu("sans jeu d'équilibrage, pas de prix", LCM.Campement.CoutEtat(sansJeu), nil)

dire("== un pourcentage se paie 1 point pour 5 %")
local jeu = LCM.Forge.Get("jeu_duree_temoin")
local enPoints = LCM.Forge.Bilan(jeu, "commun", { force = -40 })
local enPourcent = LCM.Forge.Bilan(jeu, "commun", { force = -40 }, nil, nil, nil, { "force" })
attendu("40 points rendent 20", enPoints.credit, 20)
attendu("40 % n'en rendent que 4", enPourcent.credit, 4)
attendu("  soit cinq fois moins", enPoints.credit / enPourcent.credit, 5)

Vider()
if ko == 0 then dire("TOUT PASSE") else dire(ko .. " ECHEC(S)") end
