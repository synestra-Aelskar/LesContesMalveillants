-- Le sceau et ses deux couronnes : les actions (barres du template, clic
-- droit) et les fenetres (menuTree du template, clic gauche). Jusqu'au
-- 3 octobre 2026, les fenetres avaient leur bouton et leur colonne a part.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end
local function rayon(bouton)
    local _, _, _, x, y = bouton:GetPoint(1)
    return math.floor(math.sqrt(x * x + y * y) + 0.5)
end

__declencher("PLAYER_LOGIN")
__personnage()   -- ce scenario joue un personnage : il le dit

-- ======================================================================
dire("== le lanceur d'actions : les barres du template")
local R = LCM.UI.Radial
local f = R.frame
local A, F = f.couronnes.actions, f.couronnes.fenetres
attendu("le sceau est visible", f:IsShown(), true)
local attendus = { offensives = 4, supports = 4, competences = 0, controles = 6, animation = 3 }
attendu("les categories du radial", #R.STRUCTURE, 6)
for _, categorie in ipairs(R.STRUCTURE) do
    attendu("  " .. categorie.id, #(categorie.entrees or {}), attendus[categorie.id])
end
attendu("Animation reservee au MJ", R.Trouver("animation").mjSeulement, true)
attendu("aucune fenetre dans les actions", R.Trouver("fiche"), nil)

dire("== le MJ voit une categorie de plus")
attendu("avec le compagnon MJ", #R.Categories(), 6)
LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = false
attendu("sans le compagnon", #R.Categories(), 5)
LCM._masterCompanion = true
__addonsCharges["LesContesMalveillants_MJ"] = true

dire("== clic droit : les actions")
f.sceau:Click("RightButton")
__avancer(1)
attendu("couronne des actions ouverte", A.ouvert and A.orbite:IsShown(), true)
attendu("celle des fenetres non", F.ouvert, false)
local memeRayon = true
for i = 1, A.nombreCategories do
    if rayon(A.boutonsCategorie[i]) ~= R.RAYON_CATEGORIE then memeRayon = false end
end
attendu("categories sur le cercle", memeRayon, true)
-- Le 3 octobre 2026 : categories et entrees a la meme taille (40 et 52
-- avant, deux tailles qui ne semblaient pas du meme menu).
attendu("categories a la taille commune", A.boutonsCategorie[1]:GetWidth(), R.VIGNETTE)
-- La vignette dessinee deborde du bouton (cadre 64/48) : un anneau ne doit
-- pas toucher l'autre, legende de la categorie comprise (~16 px dessous).
local demi = R.VIGNETTE * 64 / 48 / 2
attendu("les deux anneaux ne se touchent pas",
    R.RAYON_CATEGORIE + demi + 16 < R.RAYON_ACTION - demi, true)
local controles
for i = 1, A.nombreCategories do
    if A.boutonsCategorie[i].cible.id == "controles" then controles = A.boutonsCategorie[i] end
end
controles:Click("LeftButton")
__avancer(1)
attendu("six actions", A.nombreEntrees, 6)
attendu("entrees a la meme taille", A.boutonsEntree[1]:GetWidth(), A.boutonsCategorie[1]:GetWidth())
-- Le cadre dore d'un bouton est dessine sous son icone : si l'eventail
-- tombe au meme niveau, son cuir peut le recouvrir (3 octobre 2026).
attendu("l'eventail passe sous les entrees", A.secteur:GetFrameLevel() < A.boutonsEntree[1]:GetFrameLevel(), true)
attendu("le fond sous l'eventail", A.fond:GetFrameLevel() < A.secteur:GetFrameLevel(), true)
attendu("le sceau devant tout", f.sceau:GetFrameLevel() > A.boutonsEntree[1]:GetFrameLevel(), true)
attendu("eventail a 6 branches (textures du modele)",
    tostring(A.secteur.surface.__texture):find("fan%-6%.tga") ~= nil, true)
local premier, dernier = A.boutonsEntree[1], A.boutonsEntree[A.nombreEntrees]
-- Sens horaire de la premiere a la derniere, quelle que soit la categorie.
attendu("dans le sens horaire", premier.rx * dernier.ry - premier.ry * dernier.rx < 0, true)
-- Repulsion est branchee depuis le 2 octobre 2026 : elle ouvre le composeur
-- au lieu de prevenir qu'elle n'existe pas.
attendu("la premiere est Repulsion", A.boutonsEntree[1].cible.id, "repulsion")
A.boutonsEntree[1]:Click("LeftButton")
attendu("elle ouvre le composeur", LCM.UI.Composeur.frame:IsShown(), true)
-- La couronne ne se referme PLUS sur un clic (3 octobre 2026) : on consulte
-- rarement une seule feuille, et il fallait rouvrir le sceau puis redescendre
-- dans la categorie entre chaque. Elle se ferme au sceau, ou par Radial.Fermer.
attendu("et la couronne reste ouverte", A.ouvert, true)
LCM.UI.Composeur.frame:Hide()
__avancer(1)

dire("== Maj + clic : la selection du personnage")
__touches.shift = true
f.sceau:Click("LeftButton")
__touches.shift = false
attendu("fenetre ouverte", LCM.UI.Personnages.frame:IsShown(), true)
attendu("aucune couronne ouverte", F.ouvert or A.ouvert, false)
LCM.UI.Personnages.frame:Hide()
__avancer(1)

-- ======================================================================
dire("== le menu des fenetres : structure du template")
local M = LCM.UI.Menu
local noms = {}
for _, n in ipairs(M.STRUCTURE) do noms[#noms + 1] = n.label end
dire("   " .. table.concat(noms, " | "))
-- Le template en a neuf : « Combats » (masque) et « Grimoire test » ne sont
-- pas repris. « Creation Personnage » est parti le 2 octobre 2026 : le
-- dossier ne contenait plus que les Regles, qui ont rejoint Outils.
-- Sept depuis le 3 octobre 2026 : le hub du compendium est remonte d'un cran
-- pour liberer une branche dans « Outils », qui en avait deja huit (le maximum
-- qu'un eventail sait dessiner) et devait accueillir l'Atelier.
attendu("six entrees de premier niveau (Compendium retire le 3 octobre)", #M.STRUCTURE, 6)
attendu("Personnage : six fenetres et le level-up conditionnel", #M.Trouver("fiches_personnages").enfants, 7)
attendu("Objets : quatre fenetres (Bourse ajoutee)", #M.Trouver("objets").enfants, 4)
attendu("Outils : sept fenetres (les Regles s'y sont ajoutees)", #M.Trouver("outils").enfants, 7)
attendu("un dossier ne se lie pas", M.Lier("objets", function() end), false)
attendu("une entree inconnue non plus", M.Lier("inventaire_secret", function() end), false)

dire("== ce qui est branche")
-- « creation » n'est plus au menu : on cree un personnage depuis la selection.
for _, id in ipairs({ "regles", "fiche", "sante", "expertise", "penetrations_resistances", "montee_niveau",
                      "equipement", "deplacement", "systeme_aelskar", "statistiques", "apprentissage", "inventaires", "metiers",
                      "grimoires", "parametres", "panneau_mj", "incarner",
                      "vendeur", "ressources" }) do
    attendu("  " .. id, M.EstLiee(id), true)
end

dire("== clic gauche : la couronne des fenetres")
attendu("plus de bouton a part", M.bouton, nil)
f.sceau:Click("LeftButton")
__avancer(1)
attendu("couronne des fenetres ouverte", F.ouvert and F.orbite:IsShown(), true)
attendu("une categorie par entree visible", F.nombreCategories, #M.Visibles())

dire("== un dossier s'ouvre en eventail")
local function categorie(c, id)
    for i = 1, c.nombreCategories do
        if c.boutonsCategorie[i].cible.id == id then return c.boutonsCategorie[i] end
    end
end
local fiches = categorie(F, "fiches_personnages")
fiches:Click("LeftButton")
__avancer(1)
local libelles = {}
for i = 1, F.nombreEntrees do libelles[#libelles + 1] = F.boutonsEntree[i].cible.label end
attendu("ses fenetres dans l'ordre du template", table.concat(libelles, ", "),
    "Fiche, Santé, Expertises, Pénétration & Résistances, Statistiques, Apprentissage")
attendu("eventail a 6 branches",
    tostring(F.secteur.surface.__texture):find("fan%-6%.tga") ~= nil, true)
F.boutonsEntree[1]:Click("LeftButton")
attendu("la Fiche s'ouvre", LCM.UI.Vues.frames.fiche and LCM.UI.Vues.frames.fiche:IsShown(), true)
attendu("la couronne reste ouverte", F.ouvert, true)
LCM.UI.Vues.frames.fiche:Hide()
__avancer(1)

f.sceau:Click("LeftButton")
__avancer(1)
categorie(F, "fiches_personnages"):Click("LeftButton")
__avancer(1)
F.boutonsEntree[6]:Click("LeftButton")
attendu("Apprentissage s'ouvre", LCM.UI.Vues.frames.apprentissage:IsShown(), true)
LCM.UI.Vues.frames.apprentissage:Hide()
__avancer(1)

dire("== une fenetre seule s'ouvre d'un clic sur sa categorie")
f.sceau:Click("LeftButton")
__avancer(1)
local grimoires = categorie(F, "grimoires")
attendu("Grimoires est une categorie", grimoires ~= nil, true)
grimoires:Click("LeftButton")
attendu("pas d'eventail, et la couronne reste ouverte", F.ouvert, true)
__avancer(1)
for _, fenetre in ipairs(LCM.UI.fenetres or {}) do fenetre:Hide() end

dire("== une seule couronne a la fois")
-- Du 3 octobre 2026, quelques heures, les deux pouvaient etre ouvertes cote a
-- cote. Abandonne : ouvrir l'une referme l'autre.
f.sceau:Click("LeftButton")
__avancer(1)
attendu("le voile pourpre est retire", F.boutonsCategorie[1].magie.fond, nil)
attendu("Aelskar conserve son icone", M.Trouver("systeme_aelskar").icone,
    "Interface\\ICONS\\achievement_zone_stormpeaks_03")
categorie(F, "outils"):Click("LeftButton")
__avancer(1)
f.sceau:Click("RightButton")
attendu("ouvrir les actions ferme les fenetres", F.ouvert, false)
attendu("les actions sont ouvertes", A.ouvert, true)
__avancer(1)
attendu("les fenetres ont fini de se replier", F.orbite:IsShown(), false)
attendu("les actions restent", A.orbite:IsShown(), true)
f.sceau:Click("LeftButton")
__avancer(1)
attendu("et inversement", (not A.ouvert) and F.ouvert and not A.orbite:IsShown(), true)
attendu("la reouverte repart sans eventail", F.nombreEntrees, 0)
-- Echap ferme celle qui est ouverte.
F.orbite:Hide()
attendu("Echap : tout est ferme", F.ouvert or A.ouvert, false)
f.sceau:Click("RightButton")
f.sceau:Click("RightButton")
__avancer(1)
attendu("re-clic droit : les actions se referment", A.ouvert or A.orbite:IsShown(), false)

dire("== le joueur ne voit pas les outils du MJ")
LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = false
local outils = M.Visibles(M.Trouver("outils").enfants)
local ids = {}
for _, n in ipairs(outils) do ids[#ids + 1] = n.id end
-- Vendeur et Ressources sont passes au MJ le 3 octobre 2026 : ils s'ouvrent
-- quand le MJ met un point en jeu, pas quand un joueur veut faire ses courses.
attendu("outils du joueur", table.concat(ids, ","), "regles,parametres")
attendu("Systeme d'Aelskar reserve au MJ", M.Trouver("systeme_aelskar").mjSeulement, true)
f.sceau:Click("LeftButton")
__avancer(1)
attendu("la couronne du joueur n'a pas Systeme d'Aelskar", categorie(F, "systeme_aelskar"), nil)
f.sceau:Click("LeftButton")
__avancer(1)
LCM._masterCompanion = true
__addonsCharges["LesContesMalveillants_MJ"] = true

dire("== la commande et le raccourci ouvrent les fenetres")
SlashCmdList.LCM("fenetres")
__avancer(1)
attendu("/lcm fenetres", F.ouvert, true)
LCM_ToggleMenu()
__avancer(1)
attendu("le raccourci la referme", F.ouvert, false)

dire("== la documentation")
SlashCmdList.LCM("doc")
local d = LCM.UI.Document.frame
attendu("elle est ouverte", d:IsShown(), true)
attendu("les deux aides (les regles sont une fenetre a part)", #d.documents, 2)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
