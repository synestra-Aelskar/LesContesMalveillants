-- Le lanceur radial des actions (barres du template) et le menu des fenetres
-- (menuTree du template, bouton + colonne + volets, comme Necronicon).
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
local function dernierMessage()
    return __sansCouleur(__sorties[#__sorties] or "")
end

__declencher("PLAYER_LOGIN")

-- ======================================================================
dire("== le lanceur d'actions : les barres du template")
local R = LCM.UI.Radial
local f = R.frame
attendu("le sceau est visible", f:IsShown(), true)
local attendus = { offensives = 4, supports = 4, competences = 0, controles = 6, animation = 3 }
attendu("cinq categories", #R.STRUCTURE, 5)
for _, categorie in ipairs(R.STRUCTURE) do
    attendu("  " .. categorie.id, #(categorie.entrees or {}), attendus[categorie.id])
end
attendu("Animation reservee au MJ", R.Trouver("animation").mjSeulement, true)
attendu("aucune fenetre dans le radial", R.Trouver("fiche"), nil)

dire("== le MJ voit une categorie de plus")
attendu("avec le compagnon MJ", #R.Categories(), 5)
LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = false
attendu("sans le compagnon", #R.Categories(), 4)
LCM._masterCompanion = true
__addonsCharges["LesContesMalveillants_MJ"] = true

dire("== deploiement")
f.sceau:Click("LeftButton")
__avancer(1)
local memeRayon = true
for i = 1, f.nombreCategories do
    if rayon(f.boutonsCategorie[i]) ~= R.RAYON_CATEGORIE then memeRayon = false end
end
attendu("categories sur le cercle", memeRayon, true)
local controles
for i = 1, f.nombreCategories do
    if f.boutonsCategorie[i].cible.id == "controles" then controles = f.boutonsCategorie[i] end
end
controles:Click("LeftButton")
__avancer(1)
attendu("six actions", f.nombreEntrees, 6)
attendu("eventail a 6 branches (textures du modele)",
    tostring(f.secteur.surface.__texture):find("fan%-6%.tga") ~= nil, true)
local premier, dernier = f.boutonsEntree[1], f.boutonsEntree[f.nombreEntrees]
-- Sens horaire de la premiere a la derniere, quelle que soit la categorie.
attendu("dans le sens horaire", premier.rx * dernier.ry - premier.ry * dernier.rx < 0, true)
f.boutonsEntree[1]:Click("LeftButton")
attendu("action pas encore branchee : on previent", dernierMessage():find("pas encore disponible") ~= nil, true)

dire("== clic droit : la selection du personnage")
f.sceau:Click("RightButton")
attendu("fenetre ouverte", LCM.UI.Personnages.frame:IsShown(), true)
LCM.UI.Personnages.frame:Hide()
__avancer(1)

-- ======================================================================
dire("== le menu des fenetres : structure du template")
local M = LCM.UI.Menu
local noms = {}
for _, n in ipairs(M.STRUCTURE) do noms[#noms + 1] = n.label end
dire("   " .. table.concat(noms, " | "))
-- Le template en a neuf : « Combats » (masque) et « Grimoire test » ne sont pas repris.
attendu("sept entrees de premier niveau", #M.STRUCTURE, 7)
attendu("Fiches personnages : six fenetres", #M.Trouver("fiches_personnages").enfants, 6)
attendu("Objets : quatre fenetres (Bourse ajoutee)", #M.Trouver("objets").enfants, 4)
attendu("Outils : six fenetres", #M.Trouver("outils").enfants, 6)
attendu("un dossier ne se lie pas", M.Lier("objets", function() end), false)
attendu("une entree inconnue non plus", M.Lier("inventaire_secret", function() end), false)

dire("== ce qui est branche")
for _, id in ipairs({ "regles", "creation", "fiche", "sante", "expertise", "penetrations_resistances",
                      "equipement", "deplacement", "compendium", "systeme_aelskar", "statistiques", "apprentissage", "inventaires", "metiers",
                      "grimoires", "parametres", "panneau_mj", "incarner",
                      "vendeur", "ressources" }) do
    attendu("  " .. id, M.EstLiee(id), true)
end

dire("== le bouton et la colonne")
local bouton = M.bouton
attendu("le bouton est la", bouton ~= nil and bouton:IsShown(), true)
attendu("36 px", bouton:GetWidth(), 36)
bouton:Click("LeftButton")
__avancer(1)
local col = M.colonne
attendu("la colonne est ouverte", col:IsShown() and col.ouvert, true)
attendu("une icone par entree visible", col.nombre, #M.Visibles())
attendu("colonne sous le bouton", select(3, col:GetPoint(1)), "BOTTOM")

dire("== un dossier ouvre son volet a gauche")
local fiches
for i = 1, col.nombre do if col.boutons[i].noeud.id == "fiches_personnages" then fiches = col.boutons[i] end end
fiches:Click("LeftButton")
local v = M.volet
attendu("volet ouvert", v:IsShown(), true)
attendu("a gauche de l'icone", select(1, v:GetPoint(1)) .. ">" .. select(3, v:GetPoint(1)), "RIGHT>LEFT")
local libelles = {}
for _, b in ipairs(v.boutons) do if b:IsShown() then libelles[#libelles + 1] = b.noeud.label end end
attendu("ses fenetres dans l'ordre du template", table.concat(libelles, ", "),
    "Fiche, Santé, Expertises, Pénétration & Résistances, Statistiques, Apprentissage")
v.boutons[1]:Click("LeftButton")
attendu("la Fiche s'ouvre", LCM.UI.Vues.frames.fiche and LCM.UI.Vues.frames.fiche:IsShown(), true)
attendu("le volet se referme", v:IsShown(), false)
LCM.UI.Vues.frames.fiche:Hide()

fiches:Click("LeftButton")
v.boutons[6]:Click("LeftButton")
attendu("Apprentissage s'ouvre", LCM.UI.Vues.frames.apprentissage:IsShown(), true)
LCM.UI.Vues.frames.apprentissage:Hide()
fiches:Click("LeftButton")
fiches:Click("LeftButton")
attendu("re-clic sur le dossier : referme", v:IsShown(), false)

dire("== le joueur ne voit pas les outils du MJ")
LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = false
local outils = M.Visibles(M.Trouver("outils").enfants)
local ids = {}
for _, n in ipairs(outils) do ids[#ids + 1] = n.id end
attendu("outils du joueur", table.concat(ids, ","), "parametres,vendeur,ressources")
local racine = {}
for _, n in ipairs(M.Visibles()) do racine[#racine + 1] = n.id end
-- Le compendium est consultable par tous, comme dans le template (le
-- joueur y prend sa race) ; seule l'edition est reservee au MJ.
attendu("Systeme d'Aelskar consultable", table.concat(racine, ","):find("systeme_aelskar") ~= nil, true)
LCM._masterCompanion = true
__addonsCharges["LesContesMalveillants_MJ"] = true

dire("== replier")
bouton:Click("LeftButton")
__avancer(1)
attendu("colonne fermee", col:IsShown(), false)

dire("== la documentation")
SlashCmdList.LCM("doc")
local d = LCM.UI.Document.frame
attendu("elle est ouverte", d:IsShown(), true)
attendu("les deux aides (les regles sont une fenetre a part)", #d.documents, 2)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
