-- Ce que les expertises APPORTENT (11 octobre 2026).
--
-- A ne pas confondre avec `apportsExpertises`, qui dit ce qui NOURRIT une
-- expertise. Ici, c'est l'inverse : ce qu'elle change ailleurs une fois
-- acquise. Le template ne les portait pas, elles etaient passees a la trappe.
--
-- On compte sur la valeur TOTALE (investi + apports + bonus portes) : c'est ce
-- que « une bonne expertise » veut dire, et la fatigue lit deja l'Endurance
-- ainsi.

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

local X, A = LCM.Expertises, LCM.Actions
local moi = LCM.Entities.Self()

-- Les valeurs de fiche se posent par l'entite, pas en ecrivant dans la table :
-- c'est `entity.values` qui fait foi, et les formules n'iraient pas chercher
-- ailleurs.
local function poser(id, v) LCM.Entities.Set_Value(moi, id, v) end

-- Les expertises recoivent des apports d'autres statistiques : pour savoir ce
-- qu'on teste, on part d'une fiche a zero.
for _, id in ipairs({ "force", "mystique", "perception", "adresse", "esprit", "constitution" }) do
    poser(id, 0)
end

dire("== les Résistances allègent la part obligatoire")
-- Resister, ce n'est pas encaisser moins : c'est choisir ou l'on encaisse.
poser("resistance", 0)
attendu("sans Résistances, rien n'est allégé", X.PartObligatoire(moi, 10), 10)
poser("resistance", 25)
attendu("25 points allègent de moitié", string.format("%.2f", X.AllegementObligatoire(moi)), "0.50")
local reste, libere = X.PartObligatoire(moi, 10)
-- L'exemple donne par le MJ : 40 degats dont 10 obligatoires en sante, qui
-- tombent a 5.
attendu("  10 obligatoires tombent à 5", reste, 5)
attendu("  et 5 sont libérés", libere, 5)
poser("resistance", 10)
attendu("10 points allègent de 20 %", (X.PartObligatoire(moi, 10)), 8)
poser("resistance", 60)
attendu("l'allègement plafonne à tout", string.format("%.2f", X.AllegementObligatoire(moi)), "1.00")
attendu("  et la part obligatoire disparaît", (X.PartObligatoire(moi, 10)), 0)
attendu("sans part obligatoire, rien à alléger", (X.PartObligatoire(moi, 0)), 0)
poser("resistance", 25)

dire("== et c'est bien le perce-armure qui en profite")
-- `PerceMinimum` est l'endroit ou la part obligatoire se decide.
-- Le pourcentage vient des valeurs du paquet recu ; on le pose a la main pour
-- ne pas dependre d'une resolution entiere.
local ctx = { entity = moi, vars = {}, journal = {}, effets = {},
              paquet = { n = "Perce-armure", valeurs = { ["Perce armure"] = "25" } } }
attendu("25 % de 40 font 10, allégés de moitié : 5", A.PerceMinimum(ctx, 40), 5)
poser("resistance", 0)
attendu("sans Résistances, les 10 restent", A.PerceMinimum(ctx, 40), 10)
poser("resistance", 25)

dire("== les parades suivent la statistique opposée")
poser("equilibre", 10) poser("acrobaties", 10)
attendu("Équilibre et Acrobaties portent l'Adresse", (X.BonusParade(moi, "adresse")), 2)
attendu("  et pas l'Esprit", (X.BonusParade(moi, "esprit")), 0)
poser("elementaire", 10) poser("cosmique", 0)
attendu("l'Élémentaire porte l'Esprit", (X.BonusParade(moi, "esprit")), 1)
poser("cosmique", 10)
attendu("  le Cosmique s'y ajoute", (X.BonusParade(moi, "esprit")), 2)
-- L'Evasion porte les DEUX, et plus fort.
poser("evasion", 5)
attendu("l'Évasion porte l'Adresse", (X.BonusParade(moi, "adresse")), 3)
attendu("  et l'Esprit", (X.BonusParade(moi, "esprit")), 3)
attendu("mais rien d'autre", (X.BonusParade(moi, "force")), 0)

dire("== le détail nomme ce qui a aidé")
local bonus, detail = X.BonusParade(moi, "adresse")
attendu("trois expertises répondent", #detail, 3)
local noms = {}
for _, d in ipairs(detail) do noms[#noms + 1] = d.label end
attendu("  et on les nomme", table.concat(noms, ", "), "Acrobaties, Équilibre, Évasion")

dire("== parer, c'est SUBIR : hors réception, aucun bonus")
local enDefense = { entity = moi, vars = {}, paquet = { n = "Attaque simple" } }
local enAttaque = { entity = moi, vars = {} }
attendu("en défense, l'Adresse est aidée", (A.BonusParade(enDefense, "adresse")), 3)
attendu("en attaque, non", (A.BonusParade(enAttaque, "adresse")), 0)
attendu("et un champ qu'aucune expertise ne porte",
    (A.BonusParade(enDefense, "constitution")), 0)

dire("== ce qu'on produit : dégâts, portée, jet")
poser("puissance", 20)
attendu("Puissance 20 : +10 % de dégâts",
    string.format("%.2f", X.BonusDegats(moi, "attaque_simple")), "0.10")
attendu("  sur le brise-armure aussi",
    string.format("%.2f", X.BonusDegats(moi, "brise_armure")), "0.10")
attendu("  mais pas sur le perce-armure", X.BonusDegats(moi, "perce_armure"), 0)
poser("projection", 8)
attendu("Projection 8 : +4 yards de répulsion", X.BonusPortee(moi, "repulsion"), 4)
attendu("  et +2 au jet", (X.BonusAction(moi, "repulsion")), 2)
attendu("  rien sur l'attraction", X.BonusPortee(moi, "attraction"), 0)

dire("== l'Endurance alimentait déjà la fatigue, et on ne la double pas")
-- Elle est dans la formule de la jauge depuis le depart (Data/Fiche.lua) :
-- +1 point de fatigue par point TOTAL. La demande etait deja satisfaite.
local avant = LCM.Entities.Gauge(moi, "fatigue").max
poser("endurance", (tonumber(LCM.Entities.Get_Value(moi, "endurance")) or 0) + 10)
local apres = LCM.Entities.Gauge(moi, "fatigue").max
attendu("dix points d'Endurance font dix de fatigue", apres - avant, 10)
attendu("et aucun effet d'expertise ne s'en mêle",
    LCM.Equilibrage.effetsExpertises.endurance, nil)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
