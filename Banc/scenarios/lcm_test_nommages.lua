-- Les Nommages (2 novembre 2026) : l'echelle des paliers, une seule pour tout
-- le jeu (difficultes, couleurs des metiers, grille d'XP). Ce sont des
-- REGLAGES d'equilibrage — en texte pour les noms et les couleurs — et non du
-- contenu : rien au compendium (le MJ). Renommer, recolorer, ajouter,
-- retirer, reordonner ; ce qui s'y refere suit.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()
local N, D, M, R = LCM.Nommages, LCM.Difficultes, LCM.Metiers, LCM.Reglages
local p = LCM.UI.PanneauMJ.Basculer()
p:Onglet("equilibrage")
local page = p.pages.equilibrage
local NM = LCM.UI.PanneauMJ.Nommages

dire("== l'échelle de départ")
local depart = N.Liste()
attendu("sept paliers", #depart, 7)
attendu("Rose en bas", depart[1].nom, "Rose")
attendu("Noir en haut", depart[7].nom, "Noir")
attendu("rien de réglé", N.Reglee(), false)
attendu("les difficultés les lisent", D.Couleurs()[7].nom, "Noir")
attendu("les métiers n'en prennent que six", #D.CouleursMetier(), 6)
attendu("pas de catégorie au compendium", LCM.Compendium.Get("liste_paliers"), nil)

dire("== des réglages en texte, et seulement là")
attendu("un nom se règle", (R.Definir("nommages.7.nom", "Ténèbres")), true)
attendu("  il est lu", N.Get(7).nom, "Ténèbres")
attendu("  c'est une surcharge à exporter", R.Surcharges()["nommages.7.nom"], "Ténèbres")
attendu("un nom vide est refusé", (R.Definir("nommages.7.nom", "  ")), false)
attendu("ailleurs, du texte reste refusé", (R.Definir("pv.base", "abc")), false)
R.Retirer("nommages.7.nom")
attendu("revenir au fichier", N.Get(7).nom, "Noir")

dire("== l'éditeur")
page:Choisir("nommages")
local ed = page.nommages
attendu("l'éditeur s'ouvre", ed:IsShown() and not page.zone:IsShown(), true)
attendu("une ligne par palier", ed.nombre, 7)
attendu("  numéro et nom", ed.lignes[1].numero:GetText() .. " " .. ed.lignes[1].nom:GetText(), "1 Rose")
attendu("plus de champ hexa sur la ligne", ed.lignes[1].hex == nil or type(ed.lignes[1].hex) == "string", true)

dire("== renommer : partout")
D.Definir(15, 1)   -- Rose
D.Definir(18, 2)   -- Vert
ed.lignes[1].nom:SetText("Novice")
ed.lignes[1].nom:GetScript("OnEnterPressed")(ed.lignes[1].nom)
attendu("le palier est renommé", N.Get(1).nom, "Novice")
attendu("la difficulté le dit", D.Libelle(15, true), "DD 15 · Novice")
attendu("le métier aussi", M.Paliers()[1].nom, "Novice")

dire("== la couleur : clic sur la pastille")
ed.lignes[1].pastille:Click()
local sel = LCM.UI.SelecteurCouleur()
attendu("le sélecteur s'ouvre", sel:IsShown(), true)
attendu("  sur la couleur du palier", sel.hex:GetText(), "FF8CBF")
sel.cases[3]:Click()
attendu("une teinte de la palette s'y montre", sel.hex:GetText(), "66A6FF")
sel.hex:SetText("zz")
sel.valider:Click()
attendu("un code illisible est refusé", N.Get(1).hex, "FF8CBF")
sel.hex:SetText("#112233")
sel.valider:Click()
attendu("le code hexa se pose", N.Get(1).hex, "112233")
attendu("  et le sélecteur se ferme", sel:IsShown(), false)

dire("== déplacer : ce qui s'y réfère suit")
ed.lignes[7].glisserDepose({ categorie = "palier", element = 7 })
attendu("lâcher sur soi ne fait rien", N.Get(7).nom, "Noir")
ed.lignes[1].glisserDepose({ categorie = "palier", element = 7 })
attendu("le Noir prend la place 1", N.Get(1).nom, "Noir")
attendu("  Novice passe 2", N.Get(2).nom, "Novice")
attendu("  avec sa couleur", N.Get(2).hex, "112233")
attendu("la difficulté 15 reste Novice", D.Get(15).nom, "Novice")
attendu("la difficulté 18 reste Vert", D.Get(18).nom, "Vert")
attendu("la grille suit : Novice sur Novice x1", (D.Coefficient(2, 2)), 1)
attendu("  Novice sur Vert x1,5", (D.Coefficient(2, 3)), 1.5)
ed:Afficher()
ed.lignes[1].descendre:Click()
attendu("la flèche redescend le Noir", N.Get(2).nom, "Noir")

dire("== ajouter, retirer")
ed.ajouter:Click()
attendu("un huitième palier", #N.Liste(), 8)
attendu("  en haut de l'échelle", N.Get(8).nom, "Nouveau palier")
local rangVert
for _, x in ipairs(N.Liste()) do if x.nom == "Vert" then rangVert = x.rang end end
ed.lignes[rangVert].retirer:Click()
ed.confirmer.oui:Click()
attendu("le Vert est retiré", #N.Liste(), 7)
attendu("  la difficulté 18 est écartée", D.Get(18), nil)
local vert = false
for _, x in ipairs(N.Liste()) do if x.nom == "Vert" then vert = true end end
attendu("  plus de Vert dans l'échelle", vert, false)
attendu("  la difficulté 15 suit toujours Novice", D.Get(15).nom, "Novice")

dire("== reprendre les paliers rangés en contenu par la première version")
LCM.Listes.Add({ id = "palier_ancien_a", label = "Rose Facile", liste = "paliers", rang = 1, couleur = "CCCCCC" })
LCM.Listes.Add({ id = "palier_ancien_b", label = "Rose", liste = "paliers", rang = 2, couleur = "FF8CBF" })
local repris = NM.Reprendre()
attendu("deux paliers repris", repris, 2)
attendu("  l'échelle les suit, dans l'ordre", N.Get(1).nom .. "," .. N.Get(2).nom, "Rose Facile,Rose")
attendu("  et elle en compte deux", N.Nombre(), 2)
attendu("  ils quittent le contenu", LCM.Listes.Get("palier_ancien_a"), nil)
attendu("une seconde fois, rien", NM.Reprendre(), 0)

print(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
