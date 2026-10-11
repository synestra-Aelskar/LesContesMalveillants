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

dire("== la Puissance gonfle les dégâts DÉCLARÉS")
-- `Pas.declare` est le seul endroit par ou une action sort : c'est la que son
-- jet se lance et que ses valeurs se figent. Un seul branchement, donc.
local function declarer(nature, tags)
    local ctx = { entity = moi, vars = {}, journal = {}, effets = {}, nom = nature,
                  cibles = nil }
    -- On s'arrete a la declaration : pas de cible, donc rien ne part sur le
    -- reseau. C'est le calcul qu'on verifie, pas l'envoi.
    A.Pas.declare({ nature = nature, declareTags = tags, announce = "" }, ctx, function() end)
    return ctx
end

poser("puissance", 20)
local d = declarer("Attaque simple", "Total Normal=100 ; Total Critique=200")
attendu("+10 % sur le total normal", d.declaration.valeurs["Total Normal"], "110")
attendu("  et sur le critique aussi", d.declaration.valeurs["Total Critique"], "220")
attendu("  le journal le dit",
    table.concat(d.journal, " | "):find("Puissance : %+10 %%") ~= nil, true)

d = declarer("Brise-armure", "Total Normal=100")
attendu("le brise-armure en profite", d.declaration.valeurs["Total Normal"], "110")
d = declarer("Perce-armure", "Total Normal=100")
attendu("le perce-armure, non", d.declaration.valeurs["Total Normal"], "100")
d = declarer("Soin", "Total Normal=100")
attendu("un soin non plus", d.declaration.valeurs["Total Normal"], "100")

poser("puissance", 0)
d = declarer("Attaque simple", "Total Normal=100")
attendu("sans Puissance, rien ne bouge", d.declaration.valeurs["Total Normal"], "100")

dire("== et la Projection aide le jet qui PRODUIT la répulsion")
-- A ne pas confondre avec une parade : ici on agit, on ne subit pas.
poser("projection", 8)
poser("adresse", 0)
d = declarer("Répulsion", "Rand Résultat={jet:Adresse}")
local rand = tonumber(d.declaration.valeurs["Rand Résultat"]) or 0
-- Le de est aleatoire ; ce qu'on verifie, c'est que les deux points de
-- Projection s'y ajoutent.
local ctxNu = { entity = moi, vars = {}, journal = {}, effets = {}, nom = "Soin" }
A.Pas.declare({ nature = "Soin", declareTags = "Rand Résultat={jet:Adresse}", announce = "" },
    ctxNu, function() end)
attendu("la répulsion est bien produite", d.declaration.nature, "Répulsion")
attendu("le jet porte le supplément",
    rand >= 2 and rand <= (tonumber(ctxNu.declaration.valeurs["Rand Résultat"]) or 0) + 2 + 15, true)
-- L'annonce attend la declaration pour partir : sans cible, elle reste en
-- file dans le contexte. C'est la qu'on la lit.
-- On rejoue la declaration en interceptant les annonces a la source : selon
-- qu'il y a des cibles ou non, elles partent ou restent en file, et ce n'est
-- pas ce qu'on teste ici.
local dites = {}
local annoncerVrai = A.Annoncer
A.Annoncer = function(texte, ctx) dites[#dites + 1] = tostring(texte) return annoncerVrai(texte, ctx) end
declarer("Répulsion", "Rand Résultat={jet:Adresse}")
A.Annoncer = annoncerVrai
attendu("et il est annoncé",
    table.concat(dites, " | "):find("Projection 8") ~= nil, true)
poser("projection", 0)

dire("== le bonus de parade se lit dans le décompte du jet")
-- Il etait accole apres coup, a cote d'un total qui ne le comptait pas : on
-- lisait « Adresse : 7 » pour un jet qui en valait dix.
poser("equilibre", 4) poser("acrobaties", 9) poser("evasion", 12)
local attendu37 = X.BonusParade(moi, "adresse")
attendu("le bonus brut vaut 3,7", string.format("%.1f", attendu37), "3.7")

local recu = { entity = moi, vars = {}, journal = {}, effets = {},
               paquet = { n = "Attaque simple" } }
local total, texte = A.JetFormule("{jet:Adresse}", recu)

-- Arrondi VERS LE BAS : 3,7 donne 3.
attendu("le décompte nomme les expertises",
    texte and texte:find("Expertises : %+3") ~= nil, true)
attendu("  et il n'y a plus de bloc accolé",
    texte and texte:find("Acrobaties 9") == nil, true)

-- Le total ECRIT est la somme des parts ECRITES. Deux appels lanceraient deux
-- dés différents : c'est la cohérence d'UNE ligne qu'on vérifie, et c'est
-- précisément ce qui manquait — un total qui ne comptait pas ce qu'il annonce.
local ecrit = tonumber(texte and texte:match("Adresse : (-?%d+)"))
attendu("le total écrit est celui qu'on rend", ecrit, total)
-- Seulement ce qui est DANS la parenthese : « Adresse : 12 » au-dehors, c'est
-- le total lui-meme, il ne s'additionne pas a ses propres parts.
local dedans = tostring(texte):match("%((.-)%)") or ""
local somme = 0
for part in dedans:gmatch("([%+%-]?%d+)") do
    somme = somme + (tonumber(part) or 0)
end
attendu("et il est la somme de ses parts", somme, ecrit)

-- Hors réception, rien ne change : parer, c'est subir.
local enAttaque = { entity = moi, vars = {} }
local a1 = A.JetFormuleBrut("{jet:Adresse}", enAttaque)
local a2, texteAttaque = A.JetFormule("{jet:Adresse}", enAttaque)
attendu("un jet d'attaque ne porte rien",
    texteAttaque and texteAttaque:find("Expertises") == nil, true)
poser("equilibre", 0) poser("acrobaties", 0) poser("evasion", 0)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
