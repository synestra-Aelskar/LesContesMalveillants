-- Compendium « Systeme d'Aelskar » : les categories du template, le contenu
-- importe, la fenetre (types, categories, tableau, carte) et l'editeur du MJ.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = obtenu == voulu
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
local C = LCM.Compendium

dire("== Aucun avertissement au chargement")
local alertes = {}
for _, l in ipairs(__sorties) do
    if l:find("inconnu") or l:find("refuse") then alertes[#alertes + 1] = l end
end
attendu("pas d'alerte", #alertes, 0)
for _, l in ipairs(alertes) do dire("     " .. l) end

dire("== Les categories du template, dans son ordre")
local ids = {}
for _, c in ipairs(C.categories) do ids[#ids + 1] = c.label end
attendu("24 categories (PNJ fondus, Jeux d'équilibrage ajoutes, Systeme-Resolution-Action retiree)", #C.categories, 24)
attendu("ordre", table.concat(ids, ","),
    "Information,Type Armures,Liste Armes,Liste origine,Liste ressources,Liste métiers,Connaissances,"
    .. "Table xp,Calculateur,Sacs,Devises,Jeux d'équilibrage,Ressources,Armes,Armures,Accessoires,"
    .. "Races,Traits,Etats,Maladies,Apprentissage,Actions-MJ,TEMPLATE,PNJ")

dire("== Le contenu importe")
local function N(id) return #C.Entrees(C.Get(id)) end
attendu("type armures", N("type_armures"), 8)
attendu("metiers (figes dans le code)", N("liste_metiers"), 31)
-- Les actions des boutons du radial et les receptions ne sont plus des
-- entrees du compendium depuis le 3 octobre 2026 (Core/ActionsBoutons.lua,
-- Data/ActionsBoutons.lua, Data/Receptions.lua) : la categorie est vide, prete
-- pour ce qu'un MJ y creerait.
attendu("Systeme-Resolution-Action retiree (tout est dans le code)", C.Get("resolutions"), nil)
attendu("la defense aussi", LCM.Resolutions.Get("defense_auto_v3"), nil)
attendu("et elle repond toujours a une attaque", LCM.Actions.ResolutionPour("Attaque").id, "defense_auto_v3")
attendu("actions MJ : toutes sur leurs boutons", N("actions_mj"), 0)
attendu("l'attaque n'est plus au compendium", LCM.Resolutions.Get("attaque_composeur"), nil)
attendu("elle est sur son bouton", LCM.ActionsBoutons.DuBouton("attaque_simple").id, "attaque_composeur")
attendu("races : humain + 4 importees", N("races"), 5)
attendu("traits : escalade + 8 importes", N("traits"), 9)
-- La dague, l'epee rouillee (sauvegarde) et le baton (repris de l'ancien compendium).
attendu("armes", N("armes"), 3)
attendu("armures : tenue et capuche reclassees", N("armures"), 3)
attendu("devises", N("devises"), 4)
-- L'Assassin du culte du compendium, et « Assassin », un PNJ vivant distinct.
attendu("PNJ", N("pnj"), 2)
local trait = LCM.Traits.Get("adepte_de_nocturna")
attendu("cout lu dans les tags", trait.cout, 2)
attendu("resistance a l'ombre (cle « ombre » du template)", trait.bonus.resi_ombre, 4)
attendu("couleur de titre gardee", trait.couleurTitre, "4DE04D")
local brochet = LCM.Ressources.Get("brochet_lunaire")
attendu("type de ressource", brochet.type, "poisson")
attendu("metiers de la ressource", table.concat(brochet.metiers, ","), "cuisinier,pecheur")
local dague = LCM.Objets.Get("dague_d_assassin_du_culte")
attendu("jauge d'etat non standard", dague.etat and dague.etat.max, 20)
local pnj = LCM.PNJ.Get("assassin_du_culte")
attendu("PNJ : niveau", pnj.valeurs.niveau, 12)
attendu("PNJ : race", pnj.valeurs.race, "aelskardien")
attendu("PNJ : perception", pnj.valeurs.perception, 10)
attendu("PNJ : secondaire PA", pnj.valeurs.sec_pa, 2)
attendu("PNJ : mecanique", pnj.valeurs.meca_perce_armure, 8)
attendu("PNJ : traits", #pnj.traits, 3)
attendu("PNJ : armure portee", #pnj.equipement.equipement, 2)

dire("== La carte d'une entree")
local orc = C.Carte(C.Get("races"), LCM.Races.Get("orc"))
attendu("meta : etat puis morphologie", orc.meta, "Etat : 100 / 100  |  Morphologie : Humanoïde")
attendu("description en corps", orc.corps[1].texte, "Je suis un gros zorc VERT.")
attendu("premiere statistique", orc.stats[1].dossier .. "/" .. orc.stats[1].label .. "/" .. orc.stats[1].valeur,
    "Statistiques/Force/4")
local zero = false
for _, s in ipairs(orc.stats) do zero = zero or s.valeur == "0" end
attendu("aucune statistique nulle", zero, false)
local recette = C.Carte(C.Get("connaissances"), LCM.Connaissances.Get("fabrication_de_lingot_de_bronze"))
attendu("metiers et niveau en meta", recette.meta, "Metier : Mineur, Forgeron  |  Niveau : 1")
local composants
for _, s in ipairs(recette.corps) do if s.composants then composants = s.composants end end
attendu("trois composants", composants and #composants, 3)
attendu("composant repris de sa copie", composants and composants[1].nom, "Cuivre")
attendu("composant perdu (aucune copie)", composants and composants[3].nom, "Composant introuvable")
local apnj = C.Carte(C.Get("pnj"), pnj)
attendu("PNJ : race et niveau", apnj.meta, "Race : Aelskardien  |  Niveau : 12")
attendu("PNJ : statistiques par section", apnj.stats[1].dossier, "Habilités")
local xp = C.Carte(C.Get("table_xp"), C.Entrees(C.Get("table_xp"))[1])
attendu("table xp : rien sur la carte (champ cache du template)", #xp.corps, 0)

dire("== Sous-categories")
local groupes = C.SousCategories(C.Get("ressources"))
local etiquettes = {}
for _, g in ipairs(groupes) do etiquettes[#etiquettes + 1] = g.label end
attendu("types de ressources, tries", table.concat(etiquettes, ","), "Lingot,Liquide,Minerais,poisson")
attendu("sans sous-categorie", C.SousCategories(C.Get("devises")), nil)
local sansType = C.SousCategories(C.Get("traits"))
attendu("traits sans type : Sans valeur", sansType[1].label, "Sans valeur")

dire("== La fenetre")
local F = LCM.UI.Compendium
LCM.UI.Menu.Trouver("systeme_aelskar").onClick()
local f = F.frame
attendu("ouverte depuis le menu", f:IsShown(), true)
attendu("titre", f.titre:GetText(), "SYSTÈME D'A'HELL'RAZKAH")
attendu("en-tete simple : pas de filet d'or", f.regle, nil)
attendu("panneaux a 38 du haut", select(5, f.gauche:GetPoint(1)), -38)
attendu("types : Tous + 10", #f.boutonsTypes, 11)
attendu("une categorie par bouton", #f.boutonsCategories, 24)
attendu("premiere active", f.actif, "information")
attendu("vingt lignes creees une fois", #f.rangees, 20)

-- Filtre par type : seulement les listes.
f.boutonsTypes[1]:Click()           -- Tous : tout decoche
local visibles = 0
for _, b in ipairs(f.boutonsCategories) do if b:IsShown() then visibles = visibles + 1 end end
attendu("Tous decoche tout", visibles, 0)
for _, b in ipairs(f.boutonsTypes) do if b.typeId == "list" then b:Click() end end
visibles = 0
for _, b in ipairs(f.boutonsCategories) do if b:IsShown() then visibles = visibles + 1 end end
attendu("le type Liste seul", visibles, 5)
f.boutonsTypes[1]:Click()           -- Tous : tout recoche
visibles = 0
for _, b in ipairs(f.boutonsCategories) do if b:IsShown() then visibles = visibles + 1 end end
attendu("Tous recoche tout", visibles, 24)

-- Repli de la colonne des types.
f.replierTypes:Click()
attendu("types replies", f.boutonsTypes[2]:IsShown(), false)
attendu("largeur reduite", f.gauche:GetWidth(), 184)
f.replierTypes:Click()
attendu("types revenus", f.gauche:GetWidth(), 336)

-- Recherche de categorie.
f.rechercheCat:Saisir("arm")
visibles = 0
for _, b in ipairs(f.boutonsCategories) do if b:IsShown() then visibles = visibles + 1 end end
attendu("« arm » : Type Armures, Liste Armes, Armes, Armures", visibles, 4)
f.effacerCat:Click()

-- Une categorie a sous-categories se deplie au clic.
f:ChoisirCategorie("ressources")
local bRessources
for _, b in ipairs(f.boutonsCategories) do if b.categorieId == "ressources" then bRessources = b end end
attendu("prefixe deplie", bRessources.label:GetText(), "- Ressources")
attendu("deux sous-categories", f.boutonsSous[2] and f.boutonsSous[2]:IsShown(), true)
local sousLiquide
for _, b in ipairs(f.boutonsSous) do if b:IsShown() and b.label:GetText():find("Liquide") then sousLiquide = b end end
sousLiquide:Click()
local lignes = 0
for _, r in ipairs(f.rangees) do if r:IsShown() then lignes = lignes + 1 end end
attendu("filtre par sous-categorie", lignes, 1)
attendu("c'est l'eau", f.rangees[1].element.id, "eau")
sousLiquide:Click()               -- reclic : on retire le filtre
lignes = 0
for _, r in ipairs(f.rangees) do if r:IsShown() then lignes = lignes + 1 end end
attendu("filtre retire", lignes, #LCM.Compendium.Entrees(LCM.Compendium.Get("ressources")))

-- Pagination : 31 metiers, 20 par page.
f:ChoisirCategorie("liste_metiers")
attendu("deux pages", f.pages, 2)
attendu("indicateur", f.pageTexte:GetText(), "1 / 2")
f.pageSuiv:Click()
lignes = 0
for _, r in ipairs(f.rangees) do if r:IsShown() then lignes = lignes + 1 end end
attendu("onze metiers en page 2", lignes, 11)

-- Recherche d'entree (nom, tags et valeurs).
f:ChoisirCategorie("traits")
f.champRecherche:Saisir("discr")
lignes = 0
for _, r in ipairs(f.rangees) do if r:IsShown() then lignes = lignes + 1 end end
attendu("recherche par nom", lignes, 1)
f.effacer:Click()

-- Le tableau : ID, NOM, colonnes, dessinees seulement si visibles. Les
-- categories generiques (traits...) ne montrent plus que la description :
-- le defilement et le masquage s'essaient sur les connaissances.
f:SetSize(860, 520)
attendu("traits : la description seule", f.colonnesEntete[1]:GetText(), "DESCRIPTION")
f:ChoisirCategorie("connaissances")
attendu("en-tete ID", f.enteteId:GetText(), "ID")
attendu("premiere colonne", f.colonnesEntete[1]:GetText(), "METIER")
attendu("defilement horizontal propose", f.curseur:IsShown(), true)
local avant = f.colonnesEntete[1]:GetText()
f.curseur:Aller(400)
attendu("le tableau a defile", f.colonnesEntete[1]:GetText() ~= avant, true)
f.curseur:Aller(0)

-- Colonnes masquees : une preference, effacee quand elle redevient vide.
f:OuvrirColonnes()
local p = f.colonnesPopup
attendu("une case par colonne", p.cases[1]:IsShown(), true)
p.cases[1]:Click()                  -- masque METIER
attendu("preference retenue", LCM.db.compendium.colonnesMasquees.connaissances.metiers, true)
attendu("METIER masquee", f.colonnesEntete[1]:GetText(), "NIVEAU")
p.cases[1]:Click()
attendu("preference effacee", LCM.db.compendium, nil)
p:Hide()
f:ChoisirCategorie("traits")
attendu("icone en tete de ligne", f.rangees[1].icone:IsShown(), true)

-- Les objets : icone, ID, NOM, DESCRIPTION, et rien d'autre.
f:ChoisirCategorie("armes")
attendu("armes : une seule colonne", #LCM.Compendium.Colonnes(LCM.Compendium.Get("armes")), 1)
attendu("armes : description", f.colonnesEntete[1]:GetText(), "DESCRIPTION")
attendu("armes : pas de deuxieme colonne", f.colonnesEntete[2] == nil or not f.colonnesEntete[2]:IsShown(), true)
attendu("armes : icone a gauche", f.rangees[1].element == nil or f.rangees[1].icone:IsShown(), true)
f:ChoisirCategorie("traits")

-- Selection : clic, Ctrl, Maj.
f.rangees[1]:Click()
attendu("une selectionnee", #f:Selectionnees(), 1)
__touches.ctrl = true
f.rangees[2]:Click()
__touches.ctrl = false
attendu("Ctrl ajoute", #f:Selectionnees(), 2)
__touches.shift = true
f.rangees[5]:Click()
__touches.shift = false
attendu("Maj etend depuis l'ancre", #f:Selectionnees(), 4)
attendu("compteur sur Supprimer", f.supprimer.label:GetText(), "Supprimer (4)")

-- Une cellule ouvre sa valeur complete.
f:ChoisirCategorie("connaissances")
-- Le banc ne calcule pas la largeur des panneaux : la vue montre peu de
-- colonnes. On fait defiler jusqu'a « Composants » (metier 96, niveau 96,
-- description 140, et l'ecart de 8 entre chacune ; l'icone n'est plus une
-- colonne, elle ouvre la ligne).
f.curseur:Aller(96 + 8 + 96 + 8 + 140 + 8)
local cellule
for _, c in ipairs(f.rangees[1].cellules) do if c:IsShown() and c.champ.cle == "composants" then cellule = c end end
cellule:Click()
attendu("fenetre de valeur", f.valeur:IsShown(), true)
attendu("son titre", f.valeur.titre:GetText(), "COMPOSANTS")
f.valeur.fermer:Click()

-- « Voir » : la carte.
f:ChoisirCategorie("races")
local rOrc
for _, r in ipairs(f.rangees) do if r.element and r.element.id == "orc" then rOrc = r end end
rOrc.voir:Click()
local carte = F.cartes[1]
attendu("carte ouverte", carte:IsShown(), true)
attendu("nom", carte.titre:GetText(), "ORC" == carte.titre:GetText() and "ORC" or "ORC")
attendu("statistiques repliees a l'ouverture", carte.basculeStats.label:GetText(), "+ Statistiques")
carte.basculeStats:Click()
attendu("depliees", carte.basculeStats.label:GetText(), "- Statistiques")
attendu("dossiers en-tete", carte.entetesStats[1]:GetText(), "Statistiques")
attendu("une puce par statistique", carte.puces[#orc.stats] and carte.puces[#orc.stats]:IsShown(), true)
carte.fermer:Click()

dire("== Lecture seule : elle se dit")
f:ChoisirCategorie("table_xp")
attendu("raison affichee", f.lectureSeule:GetText():find("Data/Equilibrage.lua") ~= nil, true)
attendu("pas de Nouvelle entree", f.nouvelle:IsShown(), false)

dire("== Editeur MJ : creer un trait")
f:ChoisirCategorie("traits")
attendu("Nouvelle entree", f.nouvelle:IsShown(), true)
f.nouvelle:Click()
local ed = LCM_CompendiumEditeur
local idRapace = ed.travail.e.id
attendu("editeur ouvert", ed:IsShown(), true)
local onglets = {}
for _, b in ipairs(ed.onglets) do if b:IsShown() then onglets[#onglets + 1] = b.label:GetText() end end
attendu("onglets", table.concat(onglets, ","), "Général,Textes courts,Statistiques,Textes longs,Jauges,Listes,Avantage")
ed.identite.nom:Saisir("Oeil du rapace")
attendu("identifiant unique", (ed.identite.ident:GetText() or ""):match("^(%S+)"), idRapace)
attendu("le nom ne devient pas l'identifiant", idRapace ~= "oeil_du_rapace", true)
-- Onglet Statistiques, dossier Statistiques : un bonus de Force est refuse.
for _, b in ipairs(ed.onglets) do if b.ongletId == "statistic" then b:Click() end end
attendu("dossiers de statistiques", ed.dossiers[1]:IsShown(), true)
local edForce
for champ, e in pairs(ed.editeurs) do if champ.cle == "force" and e:IsShown() then edForce = e end end
edForce.saisie:Saisir("2")
ed.ok:Click()
attendu("primaire refusee", (ed.message:GetText() or ""):find("primaire") ~= nil, true)
attendu("toujours ouvert", ed:IsShown(), true)
edForce.saisie:Saisir("")
-- Dossier Observations : Vue +2.
for _, b in ipairs(ed.dossiers) do if b.dossier == "Observations" then b:Click() end end
local edVue
for champ, e in pairs(ed.editeurs) do if champ.cle == "vue" and e:IsShown() then edVue = e end end
edVue.saisie:Saisir("2")
for _, b in ipairs(ed.onglets) do if b.ongletId == "text" then b:Click() end end
local edCout
for champ, e in pairs(ed.editeurs) do if champ.cle == "cout" and e:IsShown() then edCout = e end end
edCout.saisie:Saisir("3")
ed.ok:Click()
attendu("enregistre et ferme", ed:IsShown(), false)
local neuf = LCM.Traits.Get(idRapace)
attendu("trait jouable", neuf and neuf.bonus.vue, 2)
attendu("cout", neuf and neuf.cout, 3)
attendu("brouillon", neuf and neuf.brouillon, true)
attendu("sauvegarde du compagnon", LCM_MJ_DB.brouillons.traits[idRapace].label, "Oeil du rapace")

dire("== Contenu forgeable : modification directe dans la Forge")
local rPub
for _, r in ipairs(f.rangees) do if r.element and r.element.id == "maitre_de_la_discretion" then rPub = r end end
rPub.reglages:Click()
local forgeEdition = LCM.UI.Forge.Fenetre()
attendu("la Forge s'ouvre", forgeEdition:IsShown(), true)
attendu("l'ancien éditeur reste fermé", ed:IsShown(), false)
attendu("elle reprend la bonne entrée", LCM.UI.Forge.courant.editionId, "maitre_de_la_discretion")
attendu("le bouton annonce l'enregistrement", forgeEdition.creer.label:GetText(), "Enregistrer l'entrée")
local toutesDansForge = true
for _, id in ipairs({ "races", "traits", "etats", "maladies", "apprentissages", "armes", "armures" }) do
    toutesDansForge = toutesDansForge and LCM.UI.Forge.EstCategorie(LCM.Compendium.Get(id))
end
attendu("toutes les familles demandées passent par la Forge", toutesDansForge, true)
forgeEdition:Hide()
rPub.dupliquer:Click()
local copie
for _, element in ipairs(LCM.Traits.list) do
    if element.brouillon and element.label == "Maitre de la discrétion (copie)" then copie = element end
end
local copieId = copie and copie.id
attendu("copie en brouillon", copie and copie.brouillon, true)
attendu("libelle", copie and copie.label, "Maitre de la discrétion (copie)")
attendu("bonus copie", copie and copie.bonus.discretion, 4)

dire("== Supprimer : brouillons oui, publie non")
f:BasculerEdition()
attendu("mode edition", f.modeEdition:IsShown(), true)
local rCopie
for _, r in ipairs(f.rangees) do if r.element and r.element.id == copieId then rCopie = r end end
attendu("X en mode edition", rCopie.supprimer:IsShown(), true)
rCopie.supprimer:Click()
f.confirmation.oui:Click()
attendu("copie supprimee", LCM.Traits.Get(copieId), nil)
for _, r in ipairs(f.rangees) do if r.element and r.element.id == "maitre_de_la_discretion" then rPub = r end end
rPub.supprimer:Click()
f.confirmation.oui:Click()
-- 5 octobre 2026 : une entree PUBLIEE se MASQUE au lieu d'etre refusee net.
-- Elle disparait du jeu tout de suite et reste masquee d'une session a
-- l'autre ; le fichier, lui, se corrige a la source. Refuser sans issue ne
-- laissait aucun moyen de se debarrasser d'un trait en seance.
attendu("le publie est retire du jeu", LCM.Traits.Get("maitre_de_la_discretion"), nil)
attendu("et marque comme masque",
    LCM.Brouillons.EstMasquee("traits", "maitre_de_la_discretion"), true)
attendu("on dit qu'il reste a retirer du fichier",
    (f.message:GetText() or ""):find("fichier") ~= nil, true)
-- On peut revenir dessus : le masque se leve.
attendu("demasquer", LCM.Brouillons.Demasquer("traits", "maitre_de_la_discretion"), true)
attendu("plus masque", LCM.Brouillons.EstMasquee("traits", "maitre_de_la_discretion"), false)
f:BasculerEdition()

dire("== Modification groupee")
for _, r in ipairs(f.rangees) do if r.element and r.element.id == idRapace then r:Click() end end
f.groupee:Click()
local choixCout
for _, b in ipairs(LCM_Choix_compendium_editeur and LCM_Choix_compendium_editeur.lignes or {}) do
    if b:IsShown() and type(b.choix) == "table" and b.choix.cle == "cout" then choixCout = b end
end
choixCout:Click()
local g = LCM_CompendiumGroupe
g.saisie:Saisir("1")
g.ok:Click()
attendu("cout change", LCM.Traits.Get(idRapace).cout, 1)

dire("== Une connaissance : composants et fabrication")
f:ChoisirCategorie("connaissances")
f.nouvelle:Click()
local idFonte = ed.travail.e.id
ed.identite.nom:Saisir("Fonte du fer")
for _, b in ipairs(ed.onglets) do if b.ongletId == "table" then b:Click() end end
local edComp
for champ, e in pairs(ed.editeurs) do if champ.cle == "composants" and e:IsShown() then edComp = e end end
edComp.ajouter:Click()
edComp.lignes[1].entree:Click()
for _, b in ipairs(LCM_Choix_compendium_editeur.lignes) do
    if b:IsShown() and b.choix == "ressources/eau" then b:Click() end
end
for _, b in ipairs(ed.onglets) do if b.ongletId == "compendium_entry" then b:Click() end end
attendu("onglet Fabrication", (function()
    for _, b in ipairs(ed.onglets) do if b.ongletId == "compendium_entry" then return b.label:GetText() end end
end)(), "Fabrication")
ed.ok:Click()
local fonte = LCM.Connaissances.Get(idFonte)
attendu("connaissance creee", fonte ~= nil, true)
attendu("composant pose", fonte and fonte.composants[1].ref, "ressources/eau")

dire("== Une resolution : le cheminement")
f:ChoisirCategorie("actions_mj")
f.nouvelle:Click()
local idCheminement = ed.travail.e.id
ed.identite.nom:Saisir("Essai de cheminement")
for _, b in ipairs(ed.onglets) do if b.ongletId == "table" then b:Click() end end
local edArbre
for champ, e in pairs(ed.editeurs) do if champ.cle == "feuilles" and e:IsShown() then edArbre = e end end
edArbre.outils.feuille:Click()
edArbre.outils.ajouter:Click()
for _, b in ipairs(LCM_Choix_compendium_editeur.lignes) do if b:IsShown() and b.choix == "message" then b:Click() end end
ed.ok:Click()
local essai = LCM.Resolutions.Get(idCheminement)
attendu("resolution creee", essai ~= nil, true)
attendu("une feuille, une etape", essai and #essai.feuilles[1].etapes, 1)
attendu("categorie mj (par la categorie)", essai and essai.categorie, "mj")

dire("== Le joueur consulte, il n'edite pas")
LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = false
f:ChoisirCategorie("traits")
attendu("pas de Nouvelle entree", f.nouvelle:IsShown(), false)
attendu("pas de mode edition", f.reglages:IsShown(), false)
attendu("Voir reste", f.rangees[1].voir:IsShown(), true)
attendu("pas de Dup", f.rangees[1].dupliquer:IsShown(), false)
LCM._masterCompanion = true
__addonsCharges["LesContesMalveillants_MJ"] = true

dire("== Une seule entree de menu (le hub est retire le 3 octobre 2026)")
attendu("plus d'entree Compendium", LCM.UI.Menu.Trouver("compendium"), nil)
attendu("plus de hub", F.hub, nil)
f:Hide()
LCM.UI.Menu.Trouver("systeme_aelskar").onClick()
attendu("le Systeme ouvre le compendium", f:IsShown(), true)

dire("== la carte s'ouvre et se referme sur son contenu")
local trait = LCM.Traits.list[1]
local carteT = LCM.UI.Compendium.Voir(C.Get("traits"), trait)
attendu("la carte s'ouvre", carteT:IsShown(), true)
attendu("les statistiques sont repliees", carteT.statsRepliees, true)
local repliee = carteT:GetHeight()
carteT.basculeStats:Click()
attendu("depliee", carteT.statsRepliees, false)
local depliee = carteT:GetHeight()
attendu("la carte s'agrandit", depliee > repliee, true)
carteT.basculeStats:Click()
attendu("et se referme a sa taille d'avant", carteT:GetHeight(), repliee)
-- 3 octobre 2026 : deplier AGRANDIT meme une carte qu'on a retaillee. La
-- regle d'avant (« elle garde sa taille ») se mordait la queue : on retaillait
-- justement parce que deplier n'agrandissait pas, et ca garantissait que ca
-- n'agrandirait plus jamais. La LARGEUR choisie, elle, est respectee.
carteT.placee = true
carteT:SetWidth(380)
carteT:SetHeight(300)
local avantClic = carteT:GetHeight()
carteT.basculeStats:Click()
attendu("deplier agrandit quand meme", carteT:GetHeight() ~= avantClic, true)
attendu("et montre tout le contenu", carteT:GetHeight() >= carteT:Disposer(), true)
attendu("la largeur choisie est gardee", carteT:GetWidth(), 380)
carteT:Hide()

dire("== La croix de la carte dans son encoche")
local carteX = LCM.UI.Compendium.Voir(C.Get("traits"), trait)
local enc = LCM.UI.AelEncoches and LCM.UI.AelEncoches(carteX)
if enc then
    local point, rel, relPoint, x, y = carteX.fermer:GetPoint(1)
    attendu("croix centree", point, "CENTER")
    attendu("sur le coin haut droit", relPoint, "TOPRIGHT")
    attendu("dans l'encoche", x, enc.droite[1])
else
    dire("   (pas d'encoches dans ce theme)")
end
carteX:Hide()

dire("== Link : choisir a qui, et l'entree part entiere")
local function cartesOuvertes()
    local n = 0
    for _, c in ipairs(LCM.UI.Compendium.cartes) do if c:IsShown() then n = n + 1 end end
    return n
end
local function fermerCartes() for _, c in ipairs(LCM.UI.Compendium.cartes) do c:Hide() end end
-- Rejoue ce qui est parti comme si l'autre le recevait. `de` : l'expediteur.
local function rejouer(debut, de)
    for i = debut + 1, #__envois do LCM.Reseau.Recevoir(de, __envois[i].message) end
end

__groupe({ "Reika-Apertus", "Nytherah-Apertus", "Moryn-Apertus", "Lyse-Apertus" }, true)
LCM.Reseau.Recevoir("Nytherah-Apertus", "1:1:1:ici|" .. LCM.Reseau.Encoder({ v = "0.1.0" }))
local fl = LCM.UI.Compendium.Ouvrir("traits")
local rl = fl.rangees[1]
attendu("bouton Link", rl.lien:IsShown(), true)
rl.lien:Click()
local dj = LCM.UI.Compendium.choixJoueurs
attendu("le choix des joueurs s'ouvre", dj ~= nil and dj:IsShown(), true)
attendu("les membres du raid", dj.nombre, 3)
attendu("ceux qui ont l'addon d'abord", dj.lignes[1].joueur, "Nytherah-Apertus")
contient = contient or function(l, o, v) attendu(l, tostring(o):find(v, 1, true) ~= nil, true) end
contient("les autres marques", dj.lignes[2].label:GetText(), "addon non confirmé")

-- Sans personne : refuse, et dit pourquoi.
dj.envoyer:Click()
attendu("personne choisi : refuse", dj:IsShown(), true)
attendu("et dit pourquoi", dj.statut:GetText(), "choisis au moins un joueur.")

-- Un seul joueur : un chuchotement, avec toutes les donnees.
local n = #__envois
dj.lignes[1]:Click()
dj.envoyer:Click()
attendu("la fenetre se ferme", dj:IsShown(), false)
attendu("parti en chuchotement", __envois[n + 1] and __envois[n + 1].canal, "WHISPER")
attendu("a Nytherah", __envois[n + 1] and __envois[n + 1].cible, "Nytherah-Apertus")
attendu("sous la limite de 255", __plusGrosEnvoi() <= 255, true)

-- Plusieurs membres du raid : un seul envoi au raid, avec la liste.
rl.lien:Click()
dj.lignes[1]:Click() dj.lignes[2]:Click()
n = #__envois
dj.envoyer:Click()
attendu("au raid, une seule fois", __envois[n + 1] and __envois[n + 1].canal, "RAID")
-- N'importe qui en /w, meme hors du groupe.
rl.lien:Click()
dj.autre:Saisir("Lointain-Autreroyaume")
n = #__envois
dj.envoyer:Click()
attendu("un /w a quelqu'un hors groupe", __envois[n + 1] and __envois[n + 1].cible, "Lointain-Autreroyaume")

dire("== Link : ce que recoit l'autre")
-- Un objet forge que le destinataire n'a pas : nombres, listes, texte libre.
local lame = { id = "lame_inconnue", label = "Lame inconnue", bonus = { force = 2 }, metiers = { "forge" },
               description = "a;b=c:d|e", forge = "creation_arme/rare" }
lame.soi = lame                          -- une reference circulaire ne fait pas boucler
fermerCartes()
n = #__envois
LCM.Lien.EnvoyerEntree(C.Get("armes"), lame, { "Nytherah-Apertus" })
rejouer(n, "Syn-Apertus")
local _, recue = LCM.Lien.TrouverEntree("Syn-Apertus", "armes", "lame_inconnue")
attendu("recue en memoire", recue and recue.label, "Lame inconnue")
attendu("les nombres restent des nombres", recue and recue.bonus.force, 2)
attendu("les listes restent des listes", recue and recue.metiers[1], "forge")
attendu("le texte libre passe", recue and recue.description, "a;b=c:d|e")
attendu("rien en sauvegarde", LCM.Objets.Get("lame_inconnue"), nil)
attendu("la carte s'ouvre a la reception", cartesOuvertes() > 0, true)
local lienRecu
for i = #__sorties, 1, -1 do if __sorties[i]:find("te montre", 1, true) then lienRecu = __sorties[i] break end end
contient("un lien cliquable dans le chat", lienRecu or "", "|Hlcmentree:Syn-Apertus:armes:lame_inconnue|h")
-- Recliquer sur le lien rouvre la carte, sans rien redemander.
fermerCartes()
n = #__envois
__cliquerLien("lcmentree:Syn-Apertus:armes:lame_inconnue")
attendu("le lien rouvre la carte", cartesOuvertes() > 0, true)
attendu("sans redemander", #__envois, n)

-- Envoi au raid pour d'autres : je l'ignore.
fermerCartes()
n = #__envois
LCM.Reseau.Envoyer("entree", { categorie = "armes", id = "pas_pour_moi", pour = "Lyse-Apertus,Moryn-Apertus",
    corps = LCM.Lien.Serialiser({ label = "Pas pour moi" }) }, "RAID")
rejouer(n, "Syn-Apertus")
local _, pasPourMoi = LCM.Lien.TrouverEntree("Syn-Apertus", "armes", "pas_pour_moi")
attendu("pas pour moi : ignore", pasPourMoi, nil)

-- Un gros envoi (un PNJ) part etale : une rafale, puis le reste a cadence.
local gros = { id = "pnj_gros", label = "Gros PNJ", valeurs = {} }
for i = 1, 400 do gros.valeurs["champ_" .. i] = i end
n = #__envois
local okGros, morceaux = LCM.Lien.EnvoyerEntree(C.Get("pnj"), gros, { "Nytherah-Apertus" })
attendu("gros envoi accepte", okGros, true)
attendu("en plusieurs dizaines de morceaux", morceaux > LCM.Reseau.RAFALE, true)
attendu("seule la rafale part tout de suite", #__envois - n, LCM.Reseau.RAFALE)
__avancer(morceaux * LCM.Reseau.CADENCE + 1)
attendu("le reste suit", #__envois - n, morceaux)
attendu("file videe", LCM.Reseau.FileEnvoi(), 0)
rejouer(n, "Syn-Apertus")
local _, pnjRecu = LCM.Lien.TrouverEntree("Syn-Apertus", "pnj", "pnj_gros")
attendu("le PNJ arrive entier", pnjRecu and pnjRecu.valeurs.champ_400, 400)
fermerCartes()

-- Un lien recopie dans le chat, sans envoi : on demande les donnees.
n = #__envois
__cliquerLien("lcmentree:Nytherah-Apertus:armes:lame_absente")
attendu("demande envoyee", __envois[n + 1] and __envois[n + 1].message:find("entree?|", 1, true) ~= nil, true)
attendu("au proprietaire du lien", __envois[n + 1] and __envois[n + 1].cible, "Nytherah-Apertus")
n = #__envois
LCM.Reseau.Recevoir("Nytherah-Apertus", "1:1:1:entree?|" .. LCM.Reseau.Encoder({ categorie = "traits", id = rl.element.id }))
attendu("le proprietaire repond", __envois[n + 1] and __envois[n + 1].message:find("entree|", 1, true) ~= nil, true)
__groupe({})

dire("== un lien de chat est cliquable")
-- Un lien ne se clique que si la fenetre de chat accepte les liens ET que
-- quelqu'un ecoute le clic. On ne tenait que la seconde, par une seule porte
-- (SetItemRef) ; une fenetre dont les liens sont coupes affichait « [Nom] » en
-- texte mort, sans rien pour le dire (5 octobre 2026).
local L = LCM.Lien
local cat = C.Get("armes")
local entree = { id = "lame_lien", label = "Lame d'essai" }
local lien = L.Entree(cat, entree, "Syn-Apertus")
attendu("le lien a la forme attendue",
    lien:match("^|c%x%x%x%x%x%x%x%x|H(.-)|h%[(.-)%]|h|r") ~= nil, true)
local charge, visible = lien:match("^|c%x%x%x%x%x%x%x%x|H(.-)|h%[(.-)%]|h|r")
attendu("son texte visible est le libelle", visible, "Lame d'essai")

-- Un libelle qui porte des codes d'affichage : glisses tels quels entre
-- « |h[ » et « ]|h », le premier « | » fermait le lien avant l'heure et il n'y
-- avait plus rien a cliquer.
local sale = L.Entree(cat, { id = "lame_sale", label = "|cffff0000Lame|r |TIcon:0|t rouge" })
local _, visibleSale = sale:match("^|c%x%x%x%x%x%x%x%x|H(.-)|h%[(.-)%]|h|r")
attendu("les codes sont retires du texte visible", visibleSale, "Lame rouge")
attendu("et il ne reste aucune barre verticale", visibleSale:find("|", 1, true), nil)

-- Le clic : la charge du lien est reconnue comme etant a nous.
attendu("le clic est intercepte", L.Intercepter(charge), true)
-- Le meme clic peut arriver par les deux portes (SetItemRef et
-- OnHyperlinkClick) : on ne fait le geste qu'une fois.
attendu("un lien qui n'est pas le notre passe son chemin",
    L.Intercepter("item:6948"), false)

-- Les fenetres de chat se branchent, et le branchement est idempotent.
local fausse = { liens = nil, crochets = 0 }
function fausse:SetHyperlinksEnabled(oui) self.liens = oui end
function fausse:HookScript() self.crochets = self.crochets + 1 end
attendu("une fenetre de chat se branche", L.BrancherChat(fausse), true)
attendu("ses liens sont allumes", fausse.liens, true)
attendu("et son clic nous arrive", fausse.crochets, 1)
attendu("la rebrancher ne double rien", L.BrancherChat(fausse) and fausse.crochets, 1)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
