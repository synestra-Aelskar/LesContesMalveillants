-- Les outils autorises d'un point de recolte (le MJ, 2 novembre 2026) : un
-- TYPE d'outil lie a une ligne de metier — « Pioche est liée à Mineur ».
-- Lie, il est OBLIGATOIRE pour la ligne ; « consommé », il se perd a chaque
-- tentative, comme dans les coffres.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

LCM.Brouillons.Set("ressources", { id = "pierre_outils", label = "Pierre témoin" })
__declencher("PLAYER_LOGIN")
__personnage()
local R, M = LCM.Recolte, LCM.Metiers
local moi = LCM.Entities.Self()
-- Le contenu temoin : un type d'outil, une pioche de ce type, un mineur Rose.
LCM.Listes.Add({ id = "pioche_temoin", liste = "outils", label = "Pioche témoin" })
LCM.Objets.Add({ id = "pioche_objet_temoin", label = "Pioche de fer témoin",
    categorie = "outil", type = "pioche_temoin", etat = { courant = 10, max = 10 } })
local PIOCHE = "objets/pioche_objet_temoin"
M.Gagner(moi, "mineur", M.XPPourNiveau(1) - M.XP(moi, "mineur"))
local vraiDes = LCM.Roll.Des
LCM.Roll.Des = function() return 15 end

local def = { id = "filon_outils", label = "Filon témoin", limite = 0,
    metiers = { { id = "mineur", bonus = true, dd = 5, fatigue = 0 } },
    outils = { { type = "pioche_temoin", metier = "mineur" } },
    ressources = { { entree = "ressources/inexistante", min = 1, max = 1, chance = 100 } } }

dire("== la pioche est exigée pour le Mineur")
local r, raison = R.Jet(moi, def)
attendu("sans pioche : refusé", r, nil)
attendu("  et l'on dit ce qui manque", tostring(raison):find("Pioche témoin (Mineur)", 1, true) ~= nil, true)
attendu("une pioche au sac", LCM.Inventaire.Deposer(moi, PIOCHE, 1), true)
r = R.Jet(moi, def)
attendu("avec la pioche : le jet part", r and r.reussi, true)
attendu("  la pioche n'est pas consommée", LCM.OutilsRequis.SacTotal(moi, PIOCHE), 1)

dire("== consommée : elle se perd à la tentative")
def.outils[1].consomme = true
r = R.Jet(moi, def)
attendu("le jet part", r ~= nil, true)
attendu("  la pioche est partie", LCM.OutilsRequis.SacTotal(moi, PIOCHE), 0)
attendu("  le résultat le dit", r and r.outilsPerdus and r.outilsPerdus[1], PIOCHE)
def.outils[1].consomme = nil

dire("== « Usure outils » sur la ligne : la pioche s'use d'un cran")
-- La meme case que les methodes d'un coffre (le MJ, 3 novembre 2026).
LCM.Inventaire.Deposer(moi, PIOCHE, 1)
r = R.Jet(moi, def)
attendu("sans la case : rien ne s'use", r and r.outilsUses, nil)
def.metiers[1].usureOutils = true
r = R.Jet(moi, def)
attendu("avec la case : la pioche est usée", r and r.outilsUses and r.outilsUses[1], PIOCHE)
attendu("  et gardée", LCM.OutilsRequis.SacTotal(moi, PIOCHE), 1)
def.metiers[1].usureOutils = nil
LCM.Inventaire.Prendre(moi, PIOCHE)

dire("== « toutes les lignes » et la ligne sans métier")
local libre = { id = "filon_libre", label = "Filon libre", limite = 0,
    metiers = { { id = R.METIER_AUCUN, bonus = false, dd = 0 } },
    outils = { { type = "pioche_temoin" } },
    ressources = def.ressources }
attendu("un outil pour toutes les lignes vaut aussi sans métier", (R.Jet(moi, libre)), nil)
LCM.Inventaire.Deposer(moi, PIOCHE, 1)
attendu("  avec la pioche, ça passe", R.Jet(moi, libre) ~= nil, true)
local autre = { id = "filon_autre", label = "Filon autre", limite = 0,
    metiers = { { id = "mineur", bonus = true, dd = 5 } },
    outils = { { type = "pioche_temoin", metier = "bucheron" } },
    ressources = def.ressources }
LCM.Inventaire.Prendre(moi, PIOCHE)
attendu("un outil lié à une AUTRE ligne n'est pas exigé", R.Jet(moi, autre) ~= nil, true)

dire("== le voyage : paquet et lecture")
local paquet = R.Paquet(def, {})
local lu = R.Lire(LCM.Reseau.Decoder(LCM.Reseau.Encoder(paquet)))
attendu("les outils voyagent", lu.outils and lu.outils[1].type, "pioche_temoin")
attendu("  avec leur lien", lu.outils and lu.outils[1].metier, "mineur")
attendu("un point sans outil n'en porte pas", R.Lire(R.Paquet({ id = "x", label = "x" }, {})).outils, nil)

dire("== l'export garde les outils")
-- Le DD et la fatigue par metier s'etaient perdus ici une fois : l'export
-- ne gardait que les champs qu'il connaissait.
local okC, construit = pcall(LCM.Points.Construire, { id = "point_outils_export", nature = "ressource",
    label = "Filon exporté", recolte = { ressources = { { entree = "ressources/pierre_outils", min = 1, max = 1 } },
        metiers = { { id = "mineur", bonus = true, dd = 5, usureOutils = true } }, rayon = 3,
        outils = { { type = "pioche_temoin", metier = "mineur", consomme = true },
                   { type = "type_efface_temoin" } } } })
attendu("l'export passe", okC, true)
local exp = okC and construit.recolte.outils
attendu("  l'outil et son lien", exp and (exp[1].type .. "/" .. exp[1].metier .. "/" .. tostring(exp[1].consomme)),
    "pioche_temoin/mineur/true")
attendu("  un type supprimé est laissé de côté", exp and #exp, 1)
attendu("  la case « Usure outils » de la ligne", okC and construit.recolte.metiers[1].usureOutils, true)

dire("== l'écran du MJ")
local f = LCM.UI.Recoltes.Fenetre()
f:Montrer()
f:Nouveau()
local c = f.creation
c.nom:Saisir("Filon à pioche")
c.metier:Click()
for _, ligne in ipairs(f.choixMetier.lignes) do
    if ligne:IsShown() and ligne.choix == "mineur" then ligne:Click() end
end
attendu("le tableau des outils est là", c.tableauOutils ~= nil and c.ajouterOutil ~= nil, true)
c.ajouterOutil:Click()
local o = f.travail.recolte.outils[1]
attendu("« + Ajouter un outil » ouvre une ligne", o ~= nil, true)
attendu("  liée par défaut à la première ligne de métier", o and o.metier, "mineur")
c.lignesOutils[1].type:Definir("pioche_temoin")
c.lignesOutils[1].type.choisir("pioche_temoin")
c.lignesOutils[1].consomme:Click()
attendu("la case « consommé »", f.travail.recolte.outils[1].consomme, true)
attendu("la ligne de métier a sa case « Usure outils »", c.lignesMetiers[1].usure ~= nil, true)
c.lignesMetiers[1].usure:Click()
attendu("  cochée, elle se retient", f.travail.recolte.metiers[1].usureOutils, true)
f.travail.recolte.ressources = { { entree = "ressources/pierre_outils", min = 1, max = 1, chance = 100 } }
f.travail.recolte.rayon = 3
local recolte, raison = f:Valider()
attendu("la validation garde l'outil " .. tostring(raison), recolte and recolte.outils and recolte.outils[1].type, "pioche_temoin")
attendu("  son lien et sa consommation", recolte and (recolte.outils[1].metier .. "/" .. tostring(recolte.outils[1].consomme)), "mineur/true")
attendu("la validation garde l'usure", recolte and recolte.metiers[1].usureOutils, true)
-- Le metier retire, l'outil qui lui etait lie est refuse : on dit pourquoi,
-- on ne le delie pas en douce.
table.remove(f.travail.recolte.metiers, 1)
recolte, raison = f:Valider()
attendu("lié à un métier retiré : refusé", recolte, nil)
attendu("  et l'on dit pourquoi", tostring(raison):find("plus autorisé", 1, true) ~= nil, true)
f:Hide()

LCM.Roll.Des = vraiDes
M.Gagner(moi, "mineur", -M.XP(moi, "mineur"))
print(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
