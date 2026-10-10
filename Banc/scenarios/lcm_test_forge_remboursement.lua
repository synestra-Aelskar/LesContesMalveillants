-- Ce qu'une statistique baissee rend au pool (11 octobre 2026).
--
-- Regle generale de la forge : passer une stat SOUS sa base ne rend que la
-- MOITIE de son cout. Sinon descendre une stat financerait entierement la
-- montee d'une autre, et le pool ne bornerait plus rien.
--
-- Les RACES font exception, et elles seules : une race se definit autant par
-- ses faiblesses que par ses forces, et ne rembourser que la moitie d'une
-- faiblesse revient a decourager d'en donner. Baisser une stat de 1 dont le
-- point coute 1 rend donc 1.

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
LCM.db.settings.modeJoueur = nil
LCM._masterCompanion = true

local F, E = LCM.Forge, LCM.Equilibrage

dire("== l'équilibrage porte le taux, et l'exception")
attendu("la moitié par défaut", E.forge.remboursement, 0.5)
attendu("les races remboursent en entier", E.forge.remboursementParCategorie.races, 1)

-- Un jeu d'equilibrage minimal sur une categorie donnee : une statistique a
-- 1 point le cout, base 0, et une rarete qui donne un pool.
local function Jeu(categorie)
    return {
        id = "essai_" .. categorie, categorie = categorie,
        raretes = { { id = "commune", label = "Commune", couleur = "FFFFFF", points = 20 } },
        champs = {},
    }
end

-- La statistique sur laquelle on joue : on prend la premiere que la FORGE
-- retient pour cette categorie. Passer par le compendium donnait des champs
-- que la forge ne compte pas, et le bilan restait a zero.
local function PremiereStat(categorie)
    local stats = LCM.Forge.Statistiques(LCM.Compendium.Get(categorie))
    return stats and stats[1]
end

dire("== hors des races, une baisse ne rend que la moitié")
local champArme = PremiereStat("armes")
attendu("on a trouvé une statistique d'arme", champArme ~= nil, true)
if champArme then
    local bilan = F.Bilan(Jeu("armes"), "commune", { [champArme.cle] = -4 }, 1, 10)
    -- Quatre points sous la base, un point coute 1 : la depense brute est de
    -- 4, et le credit retenu la moitie.
    attendu("le crédit est la moitié de la baisse", bilan.credit, 2)
end

dire("== pour une race, elle rend tout")
local champRace = PremiereStat("races")
attendu("on a trouvé une statistique de race", champRace ~= nil, true)
if champRace then
    local bilan = F.Bilan(Jeu("races"), "commune", { [champRace.cle] = -4 }, 1, 10)
    attendu("le crédit est la baisse entière", bilan.credit, 4)
    -- Le cas exact que tu décris : une stat de 1 en moins, un point à 1.
    local un = F.Bilan(Jeu("races"), "commune", { [champRace.cle] = -1 }, 1, 10)
    attendu("baisser de 1 rend 1", un.credit, 1)
end

dire("== et le plafond du pool s'applique toujours")
-- Rembourser en entier ne doit pas permettre de depasser le pool : c'est
-- l'autre moitie de la regle, et elle ne bouge pas.
if champRace then
    local jeu = Jeu("races")
    jeu.raretes[1].points = 3
    local bilan = F.Bilan(jeu, "commune", { [champRace.cle] = -10 }, 1, 10)
    attendu("le crédit brut suit la baisse", bilan.credit, 10)
    attendu("mais le pool le plafonne", bilan.creditRetenu, 3)
    attendu("et le reste est perdu", bilan.creditPerdu, 7)
end

dire("== le taux se règle en séance, comme tout le reste")
-- C'est un vecteur d'equilibrage : il se change par son chemin, sans toucher
-- au code ni republier.
attendu("on passe les races à la moitié",
    LCM.Reglages.Definir("forge.remboursementParCategorie.races", 0.5), true)
if champRace then
    local bilan = F.Bilan(Jeu("races"), "commune", { [champRace.cle] = -4 }, 1, 10)
    attendu("  et elles remboursent comme les autres", bilan.credit, 2)
end
LCM.Reglages.Retirer("forge.remboursementParCategorie.races")
if champRace then
    local bilan = F.Bilan(Jeu("races"), "commune", { [champRace.cle] = -4 }, 1, 10)
    attendu("remis par défaut, elles remboursent tout", bilan.credit, 4)
end

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
