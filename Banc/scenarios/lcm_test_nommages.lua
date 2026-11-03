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

-- Une echelle TEMOIN, celle de depart du fichier (3 novembre 2026). La
-- campagne a publie la sienne (19 paliers, « Rose Facile, Rose, Rose
-- Difficile… », ses difficultes et sa grille) : un test ne se pose jamais
-- sur du contenu qui vit.
local E = LCM.Equilibrage
E.nommages = {
    { nom = "Rose",   couleur = "FF8CBF" }, { nom = "Vert",   couleur = "66D966" },
    { nom = "Bleu",   couleur = "66A6FF" }, { nom = "Orange", couleur = "FF9933" },
    { nom = "Rouge",  couleur = "F24D4D" }, { nom = "Violet", couleur = "B373F2" },
    { nom = "Noir",   couleur = "9999A6" },
}
E.difficultes.niveaux = {}
E.difficultes.matrice = {}
for m = 1, 7 do
    E.difficultes.matrice[m] = {}
    for d = 1, 7 do
        local ecart = d - m
        E.difficultes.matrice[m][d] = ecart >= 0 and (1 + 0.5 * ecart) or (ecart == -1 and 0.5 or 0)
    end
end
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
-- Les metiers ont leurs sept couleurs de base, Noir compris, qui ne suivent
-- pas l'echelle (le MJ, 3 novembre 2026 ; ils en prenaient six).
attendu("les métiers ont leurs sept couleurs", #D.CouleursMetier(), 7)
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
-- Le metier, lui, reste Rose : ses couleurs sont celles du fichier (le MJ,
-- 3 novembre 2026 ; il devenait « Novice »).
attendu("le métier reste Rose", M.Paliers()[1].nom, "Rose")
attendu("  la colonne aussi", D.CouleursMetier()[1].nom, "Rose")

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
-- Seule la difficulte suit l'echelle ; la colonne du metier Rose ne bouge
-- pas (3 novembre 2026). Avant, les deux indices etaient deplaces.
attendu("la grille suit : métier Rose sur Novice x1", (D.Coefficient(1, 2)), 1)
attendu("  métier Rose sur Vert x1,5", (D.Coefficient(1, 3)), 1.5)
attendu("  métier Rose sur Noir, passé en 1", (D.Coefficient(1, 1)), 4)
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
