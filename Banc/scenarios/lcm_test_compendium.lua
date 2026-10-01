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
attendu("24 categories (PNJ et Fiches PNJ fondus)", #C.categories, 24)
attendu("ordre", table.concat(ids, ","),
    "Information,Type Armures,Liste Armes,Liste origine,Liste ressources,Liste métiers,Connaissances,"
    .. "Table xp,Systeme-Résolution-Action,Calculateur,Sacs,Devises,Ressources,Armes,Armures,Accessoires,"
    .. "Races,Traits,Etats,Maladies,Apprentissage,Actions-MJ,TEMPLATE,PNJ")

dire("== Le contenu importe")
local function N(id) return #C.Entrees(C.Get(id)) end
attendu("type armures", N("type_armures"), 8)
attendu("metiers (figes dans le code)", N("liste_metiers"), 31)
attendu("resolutions (copies exactes ecartees)", N("resolutions"), 19)
attendu("actions MJ", N("actions_mj"), 2)
attendu("races : humain + 4 importees", N("races"), 5)
attendu("traits : escalade + 8 importes", N("traits"), 9)
attendu("armes", N("armes"), 1)
attendu("armures : tenue et capuche reclassees", N("armures"), 3)
attendu("devises", N("devises"), 4)
attendu("PNJ", N("pnj"), 1)
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
attendu("composant d'un compendium absent", composants and composants[1].nom, "Composant introuvable")
local apnj = C.Carte(C.Get("pnj"), pnj)
attendu("PNJ : race et niveau", apnj.meta, "Race : Aelskardien  |  Niveau : 12")
attendu("PNJ : statistiques par section", apnj.stats[1].dossier, "Statistiques")
local xp = C.Carte(C.Get("table_xp"), C.Entrees(C.Get("table_xp"))[1])
attendu("table xp : rien sur la carte (champ cache du template)", #xp.corps, 0)

dire("== Sous-categories")
local groupes = C.SousCategories(C.Get("ressources"))
attendu("deux types de ressources", #groupes, 2)
attendu("tri par libelle", groupes[1].label, "Liquide")
attendu("sans sous-categorie", C.SousCategories(C.Get("devises")), nil)
local sansType = C.SousCategories(C.Get("traits"))
attendu("traits sans type : Sans valeur", sansType[1].label, "Sans valeur")

dire("== La fenetre")
local F = LCM.UI.Compendium
LCM.UI.Menu.Trouver("systeme_aelskar").onClick()
local f = F.frame
attendu("ouverte depuis le menu", f:IsShown(), true)
attendu("titre", f.titre:GetText(), "SYSTÈME D'AELSKAR")
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
f.boutonsSous[1]:Click()
local lignes = 0
for _, r in ipairs(f.rangees) do if r:IsShown() then lignes = lignes + 1 end end
attendu("filtre par sous-categorie", lignes, 1)
attendu("c'est l'eau", f.rangees[1].element.id, "eau")
f.boutonsSous[1]:Click()           -- reclic : on retire le filtre
lignes = 0
for _, r in ipairs(f.rangees) do if r:IsShown() then lignes = lignes + 1 end end
attendu("filtre retire", lignes, 2)

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

-- Le tableau : ID, NOM, colonnes, dessinees seulement si visibles.
f:SetSize(860, 520)
f:Rafraichir()
attendu("en-tete ID", f.enteteId:GetText(), "ID")
attendu("premiere colonne (dossier Statistiques)", f.colonnesEntete[1]:GetText(), "FORCE")
attendu("defilement horizontal propose", f.curseur:IsShown(), true)
local avant = f.colonnesEntete[1]:GetText()
f.curseur:Aller(400)
attendu("le tableau a defile", f.colonnesEntete[1]:GetText() ~= avant, true)
f.curseur:Aller(0)

-- Colonnes masquees : une preference, effacee quand elle redevient vide.
f:OuvrirColonnes()
local p = f.colonnesPopup
attendu("une case par colonne", p.cases[1]:IsShown(), true)
p.cases[1]:Click()                  -- masque FORCE
attendu("preference retenue", LCM.db.compendium.colonnesMasquees.traits.force, true)
attendu("FORCE masquee", f.colonnesEntete[1]:GetText(), "MYSTIQUE")
p.cases[1]:Click()
attendu("preference effacee", LCM.db.compendium, nil)

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
-- colonnes. On fait defiler jusqu'a « Composants » (icone 44, metier 96,
-- niveau 96, description 140, et l'ecart de 8 entre chacune).
f.curseur:Aller(44 + 8 + 96 + 8 + 96 + 8 + 140 + 8)
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
attendu("editeur ouvert", ed:IsShown(), true)
local onglets = {}
for _, b in ipairs(ed.onglets) do if b:IsShown() then onglets[#onglets + 1] = b.label:GetText() end end
attendu("onglets", table.concat(onglets, ","), "Général,Textes courts,Statistiques,Textes longs,Jauges,Listes,Avantage")
ed.identite.nom:Saisir("Oeil du rapace")
attendu("identifiant derive", (ed.identite.ident:GetText() or ""):match("^oeil_du_rapace") ~= nil, true)
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
local neuf = LCM.Traits.Get("oeil_du_rapace")
attendu("trait jouable", neuf and neuf.bonus.vue, 2)
attendu("cout", neuf and neuf.cout, 3)
attendu("brouillon", neuf and neuf.brouillon, true)
attendu("sauvegarde du compagnon", LCM_MJ_DB.brouillons.traits.oeil_du_rapace.label, "Oeil du rapace")

dire("== Contenu publie : lecture seule, Dup pour corriger")
local rPub
for _, r in ipairs(f.rangees) do if r.element and r.element.id == "maitre_de_la_discretion" then rPub = r end end
rPub.reglages:Click()
attendu("lecture seule", ed.ok:IsShown(), false)
attendu("et pourquoi", (ed.message:GetText() or ""):find("fichier généré fait foi") ~= nil, true)
ed.annuler:Click()
rPub.dupliquer:Click()
local copie = LCM.Traits.Get("maitre_de_la_discretion_copie")
attendu("copie en brouillon", copie and copie.brouillon, true)
attendu("libelle", copie and copie.label, "Maitre de la discrétion (copie)")
attendu("bonus copie", copie and copie.bonus.discretion, 4)

dire("== Supprimer : brouillons oui, publie non")
f:BasculerEdition()
attendu("mode edition", f.modeEdition:IsShown(), true)
local rCopie
for _, r in ipairs(f.rangees) do if r.element and r.element.id == "maitre_de_la_discretion_copie" then rCopie = r end end
attendu("X en mode edition", rCopie.supprimer:IsShown(), true)
rCopie.supprimer:Click()
f.confirmation.oui:Click()
attendu("copie supprimee", LCM.Traits.Get("maitre_de_la_discretion_copie"), nil)
for _, r in ipairs(f.rangees) do if r.element and r.element.id == "maitre_de_la_discretion" then rPub = r end end
rPub.supprimer:Click()
f.confirmation.oui:Click()
attendu("le publie reste", LCM.Traits.Get("maitre_de_la_discretion") ~= nil, true)
attendu("refus dit", (f.message:GetText() or ""):find("fichier fait foi") ~= nil, true)
f:BasculerEdition()

dire("== Modification groupee")
for _, r in ipairs(f.rangees) do if r.element and r.element.id == "oeil_du_rapace" then r:Click() end end
f.groupee:Click()
local choixCout
for _, b in ipairs(LCM_Choix_compendium_editeur and LCM_Choix_compendium_editeur.lignes or {}) do
    if b:IsShown() and type(b.choix) == "table" and b.choix.cle == "cout" then choixCout = b end
end
choixCout:Click()
local g = LCM_CompendiumGroupe
g.saisie:Saisir("1")
g.ok:Click()
attendu("cout change", LCM.Traits.Get("oeil_du_rapace").cout, 1)

dire("== Une connaissance : composants et fabrication")
f:ChoisirCategorie("connaissances")
f.nouvelle:Click()
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
local fonte = LCM.Connaissances.Get("fonte_du_fer")
attendu("connaissance creee", fonte ~= nil, true)
attendu("composant pose", fonte and fonte.composants[1].ref, "ressources/eau")

dire("== Une resolution : le cheminement")
f:ChoisirCategorie("resolutions")
f.nouvelle:Click()
ed.identite.nom:Saisir("Essai de cheminement")
for _, b in ipairs(ed.onglets) do if b.ongletId == "table" then b:Click() end end
local edArbre
for champ, e in pairs(ed.editeurs) do if champ.cle == "feuilles" and e:IsShown() then edArbre = e end end
edArbre.outils.feuille:Click()
edArbre.outils.ajouter:Click()
for _, b in ipairs(LCM_Choix_compendium_editeur.lignes) do if b:IsShown() and b.choix == "message" then b:Click() end end
ed.ok:Click()
local essai = LCM.Resolutions.Get("essai_de_cheminement")
attendu("resolution creee", essai ~= nil, true)
attendu("une feuille, une etape", essai and #essai.feuilles[1].etapes, 1)
attendu("categorie systeme (par la categorie)", essai and essai.categorie, "systeme")

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

dire("== Le hub")
LCM.UI.Menu.Trouver("compendium").onClick()
local h = F.hub
attendu("hub ouvert", h:IsShown(), true)
attendu("titre", h.titre:GetText(), "COMPENDIUMS")
attendu("compte", h.carte.meta:GetText(), string.format("24 categorie(s)  |  %d entree(s)", C.Total()))
f:Hide()
h.carte:Click()
attendu("la carte ouvre le compendium", f:IsShown(), true)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
