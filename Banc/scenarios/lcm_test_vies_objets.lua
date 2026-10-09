-- Les VIES d'un objet, et ses apports qui suivent son etat (9 octobre 2026).
--
-- Avant : un objet tombe a zero d'etat etait detruit, sans recours. Trop dur.
-- Maintenant sa rarete lui donne des vies : a zero il se BRISE, en perd une, et
-- reste reparable. Il n'est detruit que s'il tombe a zero sans vie.
--
-- Et ce qu'il apporte suit son etat : -20 % d'etat, -20 % de statistiques,
-- arrondi au superieur.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()
LCM.db.settings.modeJoueur = nil
LCM._masterCompanion = true

local moi = LCM.Entities.Self()
local O, E = LCM.Objets, LCM.Equilibrage

dire("== la rarete donne les vies")
-- Le bareme est lu par la COULEUR du titre : les jeux d'equilibrage nomment
-- leurs raretes comme ils veulent, la couleur est commune a tous.
local attendues = {
    { "FF8CB8", "Commun (rose)",     0 },
    { "4DE04D", "Inhabituel (vert)", 1 },
    { "4D8CFF", "Rare (bleu)",       1 },
    { "FF9926", "Épique (orange)",   2 },
    { "FF3838", "Légendaire (rouge)", 2 },
    { "BF4DFF", "Mythique (violet)", 3 },
}
for index, cas in ipairs(attendues) do
    local id = "essai_rarete_" .. index
    O.Add({ id = id, label = cas[2], categorie = "arme", couleurTitre = cas[1] })
    attendu(cas[2], O.ViesMax(id), cas[3])
end
O.Add({ id = "essai_unique", label = "Unique", categorie = "arme", couleurTitre = "9999A6" })
attendu("Unique (noir) : illimitees", O.ViesMax("essai_unique"), nil)
attendu("et on sait le dire", O.ViesIllimitees("essai_unique"), true)
-- Une couleur qu'aucune rarete ne declare garde l'ancien comportement.
O.Add({ id = "essai_inconnu", label = "Inconnu", categorie = "arme", couleurTitre = "123456" })
attendu("couleur inconnue : zero vie", O.ViesMax("essai_inconnu"), E.viesParDefaut)

dire("== a zero d'etat, l'objet se brise au lieu d'etre detruit")
-- Un bleu : une vie.
local bleu = "essai_rarete_3"
attendu("equipe", O.Placer(moi, bleu), true)
local maxi = O.EtatMax(bleu)
attendu("il a une vie", (O.Vies(moi, O.Get(bleu))), 1)
local _, detruit, brise = O.Encaisser(moi, bleu, maxi)
attendu("il n'est PAS detruit", detruit, false)
attendu("il s'est brise", brise, true)
attendu("il est toujours porte", O.Porte(moi, bleu), true)
attendu("il ne lui reste plus de vie", (O.Vies(moi, O.Get(bleu))), 0)
attendu("et son etat est a zero", maxi - O.Usure(moi, bleu), 0)

-- Encaisser encore ne coute PAS une seconde vie : on ne perd une vie qu'en
-- TOMBANT a zero, pas a chaque coup une fois qu'on y est.
local _, detruit2 = O.Encaisser(moi, bleu, 5)
attendu("un coup de plus ne detruit pas", detruit2, false)
attendu("et ne reprend pas de vie", (O.Vies(moi, O.Get(bleu))), 0)

dire("== reparer le rend utile, mais ne rend pas la vie")
O.Encaisser(moi, bleu, -maxi)
attendu("repare a neuf", maxi - O.Usure(moi, bleu), maxi)
attendu("la vie perdue reste perdue", (O.Vies(moi, O.Get(bleu))), 0)

dire("== sans vie, le prochain zero le detruit")
local _, detruit3 = O.Encaisser(moi, bleu, maxi)
attendu("detruit", detruit3, true)
attendu("et retire", O.Porte(moi, bleu), false)
-- Detruit, il n'a plus d'histoire : un exemplaire neuf repart entier.
O.Placer(moi, bleu)
attendu("un exemplaire neuf a toutes ses vies", (O.Vies(moi, O.Get(bleu))), 1)
O.Enlever(moi, bleu)

dire("== un rose meurt au premier zero, un noir jamais")
local rose = "essai_rarete_1"
O.Placer(moi, rose)
local _, detruitRose = O.Encaisser(moi, rose, O.EtatMax(rose))
attendu("le rose est detruit tout de suite", detruitRose, true)

O.Placer(moi, "essai_unique")
for _ = 1, 3 do
    O.Encaisser(moi, "essai_unique", O.EtatMax("essai_unique"))
    O.Encaisser(moi, "essai_unique", -O.EtatMax("essai_unique"))
end
local _, detruitNoir = O.Encaisser(moi, "essai_unique", O.EtatMax("essai_unique"))
attendu("le noir ne meurt jamais", detruitNoir, false)
attendu("et il est toujours la", O.Porte(moi, "essai_unique"), true)
O.Encaisser(moi, "essai_unique", -O.EtatMax("essai_unique"))
O.Enlever(moi, "essai_unique")

dire("== ce qu'un objet apporte suit son etat")
-- Une arme a +10 en force, d'etat 10 : chaque point d'usure lui coute 10 %.
O.Add({ id = "essai_apport", label = "Lame d'essai", categorie = "arme",
        couleurTitre = "BF4DFF", etat = { max = 10 }, bonus = { force = 10 } })
O.Placer(moi, "essai_apport")
local objet = O.Get("essai_apport")
attendu("neuve : tout", O.ApportSelonEtat(moi, objet, 10), 10)
O.Encaisser(moi, "essai_apport", 2)          -- 8/10, soit 80 %
attendu("a 80 % : huit", O.ApportSelonEtat(moi, objet, 10), 8)
attendu("et la fiche le voit", LCM.Effets.Bonus(moi, "force"), 8)
-- ARRONDI AU SUPERIEUR : 5 x 0,7 = 3,5 donne 4, pas 3.
O.Encaisser(moi, "essai_apport", 1)          -- 7/10
attendu("a 70 %, 5 donne 4 (arrondi au superieur)", O.ApportSelonEtat(moi, objet, 5), 4)
attendu("et 10 donne 7", O.ApportSelonEtat(moi, objet, 10), 7)
-- Un MALUS suit la meme pente, sinon s'abimer rendrait meilleur.
attendu("un malus faiblit aussi", O.ApportSelonEtat(moi, objet, -4), -3)
-- Brise : il n'apporte plus rien tant qu'on ne l'a pas repare.
O.Encaisser(moi, "essai_apport", 10)
attendu("brise : plus rien", O.ApportSelonEtat(moi, objet, 10), 0)
attendu("la fiche non plus", LCM.Effets.Bonus(moi, "force"), 0)
O.Encaisser(moi, "essai_apport", -10)
attendu("repare : tout revient", LCM.Effets.Bonus(moi, "force"), 10)

-- Le detail par source suit la meme regle : il ne doit pas annoncer un total
-- que le jet n'appliquera pas.
O.Encaisser(moi, "essai_apport", 3)
local vu
for _, part in ipairs(LCM.Effets.Detail(moi, "force")) do
    if part.nom == "objet" then vu = part.total end
end
attendu("le detail dit la meme chose", vu, LCM.Effets.Bonus(moi, "force"))

dire("== un objet brise se voit")
-- Brise = etat a zero, mais survivant. On le DEDUIT de l'etat : pas de drapeau
-- a tenir a jour, donc rien qui puisse mentir apres une reparation.
local violet = O.Get("essai_apport")
O.Encaisser(moi, "essai_apport", -O.EtatMax(violet))
attendu("neuf : pas brise", O.EstBrise(moi, violet), false)
O.Encaisser(moi, "essai_apport", O.EtatMax(violet))
attendu("a zero : brise", O.EstBrise(moi, violet), true)
attendu("mais toujours porte", O.Porte(moi, "essai_apport"), true)

-- Sur la fiche : la marque devant le nom, le nom en rouge, l'icone teintee.
local fe = LCM.UI.Vues.Fenetre("equipement")
fe:Montrer(moi)
fe:Afficher("arme")
local cont
for _, bloc in ipairs(fe.pages.arme.blocs) do if bloc.conteneur then cont = bloc.conteneur end end
local porte
for _, e in ipairs(cont.emplacements) do
    if e.elementId == "essai_apport" and not porte then porte = e end
end
attendu("l'emplacement le porte", porte ~= nil, true)
attendu("la marque est devant le nom",
    __sansCouleur(porte.nom:GetText()):find("%[BRISÉ%] Lame d'essai") ~= nil, true)
-- Le banc retient la teinte dans __vertex (il n'expose pas de getter).
local teinte = porte.icone.__vertex
attendu("l'icone est teintee de rouge",
    teinte ~= nil and teinte[2] < 0.5 and teinte[3] < 0.5 and teinte[1] > 0.9, true)

-- Repare au-dessus de zero : la marque s'en va toute seule.
O.Encaisser(moi, "essai_apport", -1)
attendu("repare : plus brise", O.EstBrise(moi, violet), false)
cont:Actualiser(moi)
attendu("la marque a disparu",
    __sansCouleur(porte.nom:GetText()):find("BRISÉ") ~= nil, false)
local teinte2 = porte.icone.__vertex
attendu("et l'icone a repris sa couleur",
    teinte2 ~= nil and teinte2[1] == 1 and teinte2[2] == 1 and teinte2[3] == 1, true)
fe:Hide()

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
