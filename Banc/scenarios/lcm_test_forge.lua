-- La forge : jeux d'equilibrage (registre, refus), garde-fou a
-- l'enregistrement des brouillons, et les deux fenetres pilotees au clic.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = obtenu == voulu
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end
local function contient(libelle, texte, motif)
    attendu(libelle, tostring(texte or ""):find(motif, 1, true) ~= nil, true)
    if not tostring(texte or ""):find(motif, 1, true) then dire("     obtenu : " .. tostring(texte)) end
end

__declencher("PLAYER_LOGIN")
local B, F = LCM.Brouillons, LCM.Forge

-- Un jeu valide : deux raretes, la force verrouillee a 1, l'escalade bornee
-- (plus serree en Commun), la vue a 2 pts le point, l'ouie avec une base.
local function Jeu()
    return {
        id = "creation_arme", label = "Création d'arme", categorie = "armes",
        raretes = {
            { id = "commun", label = "Commun", points = 4, couleur = "FF8CB8" },
            { id = "rare",   label = "Rare",   points = 10, couleur = "4D8CFF" },
        },
        champs = {
            force = { verrou = true, base = 1 },
            escalade = { min = 0, max = 5, raretes = { commun = { max = 2 } } },
            vue = { cout = 2 },
            ouie = { base = 2 },
        },
    }
end

dire("== Registre des jeux : ce qui est refuse")
local function refus(libelle, modif, motif)
    local def = Jeu()
    modif(def)
    local ok, err = pcall(F.Construire, def)
    attendu(libelle, ok, false)
    if motif then contient("     raison", err, motif) end
end
refus("sans categorie", function(d) d.categorie = nil end, "choisis la categorie")
refus("categorie sans statistiques", function(d) d.categorie = "devises" end, "pas de statistiques")
refus("sans rarete", function(d) d.raretes = {} end, "au moins une rarete")
refus("pool vide", function(d) d.raretes[1].points = "" end, "pool de Commun")
refus("pool negatif", function(d) d.raretes[1].points = -1 end, "pool de Commun")
refus("couleur illisible", function(d) d.raretes[1].couleur = "rose" end, "couleur de Commun")
refus("deux raretes de meme id", function(d) d.raretes[2].id = "commun" end, "deux raretes")
refus("statistique etrangere", function(d) d.champs.armure_bidon = { max = 1 } end, "n'est pas une statistique")
refus("min au-dessus du max", function(d) d.champs.vue = { min = 3, max = 1 } end, "au-dessus du maximum")
refus("borne illisible", function(d) d.champs.vue = { max = "beaucoup" } end, "illisible")
refus("cout illisible", function(d) d.champs.vue = { cout = "x" } end, "cout de")
refus("rarete inconnue dans un reglage", function(d) d.champs.vue = { raretes = { mythique = { max = 1 } } } end,
    "rarete inconnue")

local construit = F.Construire(Jeu())
attendu("forme rendue : categorie", construit.categorie, "armes")
attendu("couleur en capitales", construit.raretes[2].couleur, "4D8CFF")
attendu("reglage vide non retenu", F.Construire({ id = "x", label = "X", categorie = "armes",
    raretes = { { id = "a", label = "A", points = 1, couleur = "FFFFFF" } }, champs = { vue = {} } }).champs.vue, nil)

dire("== Avant tout jeu, la categorie est libre")
local ok, raison = B.Enregistrer("objets", { id = "gourdin", label = "Gourdin", categorie = "arme",
    bonus = { force = 4 } }, true)
attendu("arme sans jeu acceptee", ok, true)

dire("== Enregistrer le jeu en brouillon")
ok, raison = B.Enregistrer("jeux", Jeu(), true)
attendu("jeu accepte", ok, true)
if not ok then dire("     raison : " .. tostring(raison)) end
attendu("jouable aussitot", F.Get("creation_arme") ~= nil, true)
attendu("sauvegarde", LCM_MJ_DB.brouillons.jeux.creation_arme.label, "Création d'arme")
attendu("un jeu pour les armes", #F.PourCategorie("armes"), 1)
attendu("aucun pour les armures", #F.PourCategorie("armures"), 0)

dire("== Le bilan")
local jeu = F.Get("creation_arme")
local bilan = F.Bilan(jeu, "rare", { force = 1, vue = 2, escalade = 3, ouie = 2 })
attendu("vue 2 x 2 + escalade 3 = 7", bilan.total, 7)
bilan = F.Bilan(jeu, "rare", { force = 1 })
-- L'ouie a une base de 2 ; absente, elle vaut 0, donc deux crans sous sa base.
-- Elle rembourse la MOITIE depuis le 5 octobre 2026 : 1, et non 2.
attendu("ouie absente : sous sa base, rembourse la moitié", bilan.total, -1)
attendu("limites : max de la rarete", F.Limites(jeu, "escalade", "commun").max, 2)
attendu("limites : max du jeu ailleurs", F.Limites(jeu, "escalade", "rare").max, 5)
attendu("cout par defaut", F.Limites(jeu, "pistage", "rare").cout, LCM.Equilibrage.forge.coutParDefaut)
-- RareteSuffisante prend les VALEURS depuis le 5 octobre 2026, plus un total :
-- le credit des negatives etant plafonne par le pool, le total depend de la
-- rarete qu'on vise, et ne peut donc pas se calculer une fois pour toutes.
attendu("rarete suffisante pour 3 pts", F.RareteSuffisante(jeu, { escalade = 3 }).id, "commun")
attendu("aucune pour 12 pts", F.RareteSuffisante(jeu, { vue = 6 }), nil)

dire("== Le garde-fou : le bareme bloque")
local function arme(id, forge, bonus)
    return { id = id, label = id, categorie = "arme", forge = forge, bonus = bonus }
end
ok, raison = B.Enregistrer("objets", arme("sans_jeu", nil, { vue = 1 }), true)
attendu("sans jeu : refusee", ok, false)
contient("     nomme le jeu", raison, "« Création d'arme »")
attendu("     rien sauvegarde", LCM_MJ_DB.brouillons.objets.sans_jeu, nil)

ok, raison = B.Enregistrer("objets", arme("lame_juste", "creation_arme/rare",
    { force = 1, vue = 2, escalade = 3, ouie = 2 }), true)
attendu("dans le pool : acceptee", ok, true)
if not ok then dire("     raison : " .. tostring(raison)) end
attendu("le jeu suit l'entree", LCM.Objets.Get("lame_juste").forge, "creation_arme/rare")

ok, raison = B.Enregistrer("objets", arme("lame_chere", "creation_arme/commun",
    { force = 1, vue = 2, escalade = 1, ouie = 2 }), true)
attendu("hors pool : refusee", ok, false)
contient("     dit combien", raison, "5 pts dépensés, le pool Commun en permet 4")
ok = B.Enregistrer("objets", arme("lame_chere", "creation_arme/commun", { force = 1, vue = 2, ouie = 2 }), true)
attendu("pile au pool : acceptee", ok, true)

ok, raison = B.Enregistrer("objets", arme("lame_forte", "creation_arme/rare", { force = 3, ouie = 2 }), true)
attendu("verrou force : refusee", ok, false)
contient("     raison", raison, "Force est verrouillé à 1")

ok, raison = B.Enregistrer("objets", arme("grimpeuse", "creation_arme/commun", { force = 1, escalade = 3, ouie = 2 }), true)
attendu("max de la rarete : refusee", ok, false)
contient("     raison", raison, "au-dessus de son maximum (3 > 2)")
ok = B.Enregistrer("objets", arme("grimpeuse", "creation_arme/rare", { force = 1, escalade = 3, ouie = 2 }), true)
attendu("meme valeur en Rare : acceptee", ok, true)

ok, raison = B.Enregistrer("objets", arme("fantome", "jeu_disparu/rare", { force = 1 }), true)
attendu("jeu inconnu : refusee", ok, false)
contient("     raison", raison, "jeu d'équilibrage inconnu")
ok, raison = B.Enregistrer("objets", arme("rare_inconnue", "creation_arme/mythique", { force = 1 }), true)
attendu("rarete inconnue : refusee", ok, false)
contient("     raison", raison, "rareté inconnue")

-- Un jeu des armes ne regit pas les armures, ni les traits.
ok = B.Enregistrer("objets", { id = "plastron", label = "Plastron", categorie = "equipement",
    bonus = { vue = 9 } }, true)
attendu("armure : libre", ok, true)
ok = B.Enregistrer("traits", { id = "oeil_vif", label = "Oeil vif", cout = 1, bonus = { vue = 9 } }, true)
attendu("trait : libre", ok, true)
-- Le « jeu/rarete » d'un jeu qui ne vise pas la categorie n'y change rien
-- tant qu'aucun jeu ne la vise (cas d'un jeu supprime depuis).
ok = B.Enregistrer("objets", { id = "plastron_vieux", label = "Vieux", categorie = "equipement",
    forge = "jeu_disparu/rare", bonus = { vue = 1 } }, true)
attendu("categorie libre, vieux jeu ignore", ok, true)

-- Le contenu publie n'est pas re-verifie au chargement : le fichier fait foi.
attendu("arme publiee toujours la", LCM.Objets.Get("epee_rouillee") ~= nil, true)

dire("== Le compendium montre le jeu")
local armes = LCM.Compendium.Get("armes")
local champForge
for _, champ in ipairs(LCM.Compendium.Champs(armes)) do if champ.cle == "forge" then champForge = champ end end
attendu("champ Forge present", champForge ~= nil, true)
local options = LCM.Compendium.Options(champForge)
attendu("une option par rarete", #options, 2)
attendu("groupee par jeu", options[1].groupe, "Création d'arme")
attendu("texte de la carte", LCM.Compendium.Texte(armes, champForge, "creation_arme/rare", "full"), "Rare (10 pts)")

dire("== L'editeur du compendium passe par la meme porte")
local Ed = LCM.CompendiumEditeur
ok, raison = Ed.Dupliquer(armes, LCM.Objets.Get("lame_juste"))
attendu("dupliquer une lame forgee : acceptee", ok, true)
ok, raison = Ed.Dupliquer(armes, LCM.Objets.Get("epee_rouillee"))
attendu("dupliquer une arme non forgee : refusee", ok, false)
contient("     raison", raison, "passe par un jeu d'équilibrage")

dire("== Le compendium : bouton Forger")
local FU = LCM.UI.Forge
local cf = LCM.UI.Compendium.Ouvrir("armes")
attendu("Forger visible sur Armes", cf.forger:IsShown(), true)
attendu("cale a droite", cf.forger.__points[1][1], "TOPRIGHT")
cf:ChoisirCategorie("devises")
attendu("pas sur Devises", cf.forger:IsShown(), false)
cf:ChoisirCategorie("armures")
attendu("visible sur Armures", cf.forger:IsShown(), true)
cf.forger:Click()
contient("aucun jeu pour les armures : dit", cf.message:GetText(), "aucun jeu d'équilibrage ne vise Armures")
attendu("forge pas ouverte", FU.frame == nil or not FU.frame:IsShown(), true)
cf:ChoisirCategorie("armes")
cf.forger:Click()

dire("== Fenetre de la forge")
local f = FU.frame
attendu("ouverte", f:IsShown(), true)
attendu("jeu choisi", f.jeu.label:GetText(), "Création d'arme")
attendu("premiere rarete", f.rarete.label:GetText(), "Commun")
attendu("compteur a 0", f.compteur.points:GetText(), "0 pts")
attendu("pool affiche", f.compteur.pool:GetText(), "/ 4 pts")
attendu("largeur du selecteur de vue", f.mode:GetWidth(), 204)
attendu("fleches des menus", f.jeu.fleche ~= nil and f.rarete.fleche ~= nil, true)
f.icone:Click()
attendu("selecteur icone ouvert", f.selecteurIcone:IsShown(), true)
local iconeForge = "Interface\\Icons\\INV_Misc_Book_09"
f.selecteurIcone.onChoix(iconeForge)
f.selecteurIcone:Hide()
attendu("icone choisie", FU.courant.icone, iconeForge)
attendu("apercu de l'icone WoW", f.icone.texture:GetTexture(), iconeForge)
f.selecteurIcone.onChoix("Interface/AddOns/LesContesMalveillants/ressources/radial/icones/animation.tga")
attendu("apercu de l'icone creee", f.icone.texture:GetTexture(),
    "Interface\\AddOns\\LesContesMalveillants\\ressources\\radial\\icones\\animation.tga")
f.selecteurIcone.onChoix(iconeForge)

-- La force (verrouillee) n'apparait pas ; le premier dossier est ouvert.
local function ligne(cle)
    for _, l in ipairs(f.lignes) do if l:IsShown() and l.cle == cle then return l end end
end
local function dossier(nom)
    for _, b in ipairs(f.dossiers) do if b:IsShown() and b.dossier == nom then return b end end
end
attendu("force verrouillee absente", ligne("force"), nil)
dossier("Observations"):Click()
local vue = ligne("vue")
attendu("vue visible", vue ~= nil, true)
attendu("vue : cout par point", vue.cout:GetText(), "2 / pt")
vue.plus:Click()
attendu("vue a 1", vue.valeur:GetText(), "1")
attendu("2 pts depenses", f.compteur.points:GetText(), "2 pts")
attendu("ligne : 2 pts", vue.cout:GetText(), "2 pts")
contient("en-tete du dossier", dossier("Observations").label:GetText(), "2 pts")
f.mode.boutons[2]:Click()
attendu("forge en tableau", f.vue, "tableau")
attendu("tableau de forge compact", f:GetWidth() <= 972, true)
attendu("investissement conserve en tableau", ligne("vue").valeur:GetText(), "1")
attendu("pool conserve en tableau", f.compteur.points:GetText(), "2 pts")
attendu("verrou conserve en tableau", ligne("force"), nil)
attendu("cadre du theme dans la forge", dossier("Observations").carte.cadre ~= nil, true)
ligne("vue").plus:Click()
attendu("investir depuis le tableau", ligne("vue").valeur:GetText(), "2")
ligne("vue").moins:Click()
f.mode.boutons[1]:Click()
attendu("retour forge en liste", f.vue, "liste")
attendu("largeur liste restauree", f:GetWidth(), 600)
attendu("investissement conserve en liste", ligne("vue").valeur:GetText(), "1")
vue = ligne("vue")

-- On depasse : rien n'est rabote, le compteur passe au rouge, la creation
-- est refusee et dit pourquoi.
vue.plus:Click()
vue.plus:Click()
attendu("vue a 3, pas rabotee", vue.valeur:GetText(), "3")
attendu("6 pts", f.compteur.points:GetText(), "6 pts")
attendu("depasse", f.compteur.palier:GetText(), "Dépasse le pool de Commun")
f.creer:Click()
contient("sans nom : refusee", f.statut:GetText(), "donne-lui un nom")
f.nom:Saisir("Lame d'essai")
local idLame = FU.courant.creationId
attendu("identifiant unique de l'entree", idLame ~= "lame_d_essai", true)
attendu("icone transmise a la definition", FU.Definition().icone, iconeForge)
attendu("description sous le nom", f.description:IsShown(), true)
f.description.saisie:Saisir("Une lame forgée pour l'essai.")
attendu("description transmise a la definition", FU.Definition().description, "Une lame forgée pour l'essai.")
f.creer:Click()
contient("hors pool : refusee", f.statut:GetText(), "Refusé : 6 pts dépensés")
attendu("rien sauvegarde", LCM_MJ_DB.brouillons.objets[idLame], nil)

-- Une saisie illisible n'est pas lue comme zero.
vue.valeur:SetText("beaucoup")
vue.valeur:GetScript("OnEnterPressed")(vue.valeur)
contient("saisie illisible refusee", f.statut:GetText(), "n'est pas un nombre entier")
attendu("valeur gardee", FU.courant.valeurs.vue, 3)

-- Max d'une rarete : la ligne le dit en rouge.
dossier("Athlétismes"):Click()
local esc = ligne("escalade")
esc.valeur:SetText("3")
esc.valeur:GetScript("OnEnterPressed")(esc.valeur)
attendu("escalade hors bornes signalee", esc.hors ~= nil, true)
contient("bornes affichees", esc.limites:GetText(), "max 2")

-- Passer en Rare : 3 en escalade y est permis, et 6 + 3 = 9 tient dans 10.
f.rarete:Click()
for _, b in ipairs(f.choix.lignes) do if b:IsShown() and b.choix == "rare" then b:Click() end end
attendu("rarete Rare", f.rarete.label:GetText(), "Rare")
attendu("9 pts", f.compteur.points:GetText(), "9 pts")
attendu("escalade dans les bornes", esc.hors, nil)
contient("palier", f.compteur.palier:GetText(), "Rareté Rare")
f.creer:Click()
contient("creee", f.statut:GetText(), "Lame d'essai")
local cree = LCM.Objets.Get(idLame)
attendu("brouillon jouable", cree and cree.brouillon, true)
attendu("son jeu", cree and cree.forge, "creation_arme/rare")
attendu("force a sa base", cree and cree.bonus.force, 1)
attendu("ouie a sa base", cree and cree.bonus.ouie, 2)
attendu("vue", cree and cree.bonus.vue, 3)
attendu("couleur de la rarete", cree and cree.couleurTitre, "4D8CFF")
attendu("tag de la rarete", cree and cree.tags, "Rare")
attendu("saisie remise a zero", next(FU.courant.valeurs), nil)
attendu("description de l'entree", cree and cree.description, "Une lame forgée pour l'essai.")
attendu("description remise a zero", FU.courant.description, "")
attendu("editeur pas ouvert", Ed.frame ~= nil and Ed.frame:IsShown(), false)

dire("== Modifier depuis le compendium revient dans la forge")
-- Une propriete hors statistiques doit survivre a ce passage : la Forge ne
-- l'affiche pas, mais ne doit surtout pas l'effacer.
cree.taille = 2
Ed.Ouvrir(armes, cree)
attendu("la forge reste le panneau d'edition", f:IsShown(), true)
attendu("l'ancien editeur reste ferme", Ed.frame ~= nil and Ed.frame:IsShown(), false)
attendu("le bouton annonce une modification", f.creer.label:GetText(), "Enregistrer l'entrée")
attendu("le même jeu est repris", FU.courant.jeuId, "creation_arme")
attendu("la même rareté est reprise", FU.courant.rareteId, "rare")
attendu("le nom est repris", FU.courant.nom, "Lame d'essai")
attendu("les statistiques sont reprises", FU.courant.valeurs.vue, 3)
f.nom:Saisir("Lame retouchée")
f.description.saisie:Saisir("Description retouchée dans la Forge.")
FU.courant.valeurs.vue = 2
f:Rafraichir()
f.creer:Click()
contient("modification enregistrée", f.statut:GetText(), "enregistré")
attendu("l'identifiant reste stable", LCM.Objets.Get(idLame), cree)
attendu("aucun doublon au nouveau nom", LCM.Objets.Get("lame_retouchee"), nil)
attendu("le nom est modifié", cree.label, "Lame retouchée")
attendu("la description est modifiée", cree.description, "Description retouchée dans la Forge.")
attendu("le bonus est modifié", cree.bonus.vue, 2)
attendu("la propriété d'arme est conservée", cree.taille, 2)
attendu("le mode édition reste explicite", f.creer.label:GetText(), "Enregistrer l'entrée")

dire("== Les jeux dans le compendium")
cf:ChoisirCategorie("jeux_equilibrage")
local cj = LCM.Compendium.Get("jeux_equilibrage")
attendu("categorie listee", cj ~= nil, true)
attendu("le jeu en est une entree", LCM.Compendium.Entree(cj, "creation_arme") ~= nil, true)
attendu("Nouvelle entree", cf.nouvelle:IsShown(), true)
attendu("pas de Forger ici", cf.forger:IsShown(), false)
attendu("carte : categorie", LCM.Compendium.Carte(cj, F.Get("creation_arme")).meta:find("Armes", 1, true) ~= nil, true)

-- La roue d'une ligne ouvre l'equilibrage de ce jeu.
local rJeu
for _, r in ipairs(cf.rangees) do if r.element and r.element.id == "creation_arme" then rJeu = r end end
rJeu.reglages:Click()
local q = FU.equilibrage
attendu("equilibrage ouvert", q:IsShown(), true)
attendu("sur ce jeu", q.selection, "creation_arme")
attendu("titre du jeu", q.titre:GetText(), "CRÉATION D'ARME")
attendu("pas marque modifie", q.etat:GetText(), "Brouillon.")
attendu("l'editeur a champs reste ferme", Ed.frame ~= nil and Ed.frame:IsShown(), false)

-- Modification groupee : refusee, et dit.
Ed.ModifGroupee(cj, { F.Get("creation_arme") })
local alerte = false
for _, l in ipairs(__sorties) do if l:find("pas de modification groupee", 1, true) then alerte = true end end
attendu("modif groupee : refusee et dit", alerte, true)

-- Nouvelle entree : un jeu neuf.
cf.nouvelle:Click()
local t = q:Travail()
local idArmure = t.def.id
attendu("jeu neuf", t.creation, true)
attendu("sept raretes de Necronicon", #t.def.raretes, 7)
attendu("pools vides", t.def.raretes[1].points, "")
attendu("etat", q.etat:GetText(), "Jeu neuf, pas encore enregistré.")
q.pageJeu.nom:Saisir("Création d'armure")
-- Les champs se voient avant meme de choisir la categorie.
q.onglets.boutons[2]:Click()
local avant = 0
for _, b in ipairs(q.pageChamps.dossiers) do if b:IsShown() then avant = avant + 1 end end
attendu("dossiers visibles sans categorie", avant > 10, true)
q.onglets.boutons[1]:Click()
q.enregistrer:Click()
contient("sans categorie : refuse", q.statut:GetText(), "choisis la categorie")
q.pageJeu.categorie:Click()
local cats = {}
for _, b in ipairs(q.choix.lignes) do if b:IsShown() then cats[#cats + 1] = b.choix end end
attendu("categories proposees : celles a statistiques", table.concat(cats, ","):find("devises") == nil, true)
for _, b in ipairs(q.choix.lignes) do if b:IsShown() and b.choix == "armures" then b:Click() end end
attendu("categorie choisie", q.pageJeu.categorie.label:GetText(), "Armures")
q.enregistrer:Click()
contient("pools vides : refuse", q.statut:GetText(), "pool de Commun")
for _, l in ipairs(q.pageJeu.lignes) do
    if l:IsShown() then l.points:Saisir("8") end
end
q.pageJeu.lignes[7].retirer:Click()
attendu("une rarete retiree", #t.def.raretes, 6)

-- Onglet Champs : inclusion et bornes, par rarete.
q.onglets.boutons[2]:Click()
attendu("onglet champs", q.onglet, "champs")
local pc = q.pageChamps
local function dossierEq(nom)
    for i, b in ipairs(pc.dossiers) do if b:IsShown() and b.dossier == nom then return b, pc.casesDossier[i] end end
end
local function ligneEq(cle)
    for _, l in ipairs(pc.lignes) do if l:IsShown() and l.cle == cle then return l end end
end
local noms = {}
for _, b in ipairs(pc.dossiers) do if b:IsShown() then noms[#noms + 1] = b.dossier end end
local tous = table.concat(noms, ",")
for _, attendus in ipairs({ "Statistiques", "Pénétrations", "Résistances", "Observations", "Athlétismes",
                            "Filouteries", "Mécanique de compétence" }) do
    attendu("dossier " .. attendus, tous:find(attendus, 1, true) ~= nil, true)
end
local _, casePen = dossierEq("Pénétrations")
attendu("dossier actif par defaut", casePen:EstCochee(), true)
casePen:Click()
attendu("dossier prive : ses champs verrouilles", t.def.champs.pen_feu and t.def.champs.pen_feu.verrou, true)
contient("en-tete : prive", (dossierEq("Pénétrations")).label:GetText(), "privé")
attendu("case decochee", select(2, dossierEq("Pénétrations")):EstCochee(), false)
select(2, dossierEq("Pénétrations")):Click()
attendu("recoche : plus rien de prive", t.def.champs.pen_feu, nil)
dossierEq("Statistiques"):Click()
attendu("champ actif par defaut", ligneEq("force").actif:EstCochee(), true)
ligneEq("force").actif:Click()
ligneEq("adresse").max:Saisir("2")
ligneEq("adresse").cout:Saisir("3")
attendu("champ prive", t.def.champs.force.verrou, true)
contient("dossier : un prive", (dossierEq("Statistiques")).label:GetText(), "1 privé")
attendu("max ecrit tel quel", t.def.champs.adresse.max, "2")
q.pageChamps.rarete:Click()
for _, b in ipairs(q.choix.lignes) do if b:IsShown() and b.choix == "rare" then b:Click() end end
attendu("inclusion cachee par rarete", ligneEq("force").actif:IsShown(), false)
ligneEq("adresse").max:Saisir("4")
attendu("max de la rarete", t.def.champs.adresse.raretes.rare.max, "4")
ligneEq("adresse").max:Saisir("")
attendu("effacer ne laisse rien", t.def.champs.adresse.raretes, nil)
ligneEq("adresse").max:Saisir("4")

-- Le tableau : tout a plat, la fenetre s'elargit ; la liste la rend.
pc.rarete:Click()
for _, b in ipairs(q.choix.lignes) do if b:IsShown() and b.choix == "" then b:Click() end end
pc.vueBouton:Click()
attendu("vue tableau", q.vue, "tableau")
attendu("bouton : retour liste", pc.vueBouton.label:GetText(), "Affichage : liste")
local cellules = 0
for _, l in ipairs(pc.tLignes) do if l:IsShown() then cellules = cellules + 1 end end
attendu("tous les champs a plat", cellules, #LCM.Forge.Champs("armures"))
attendu("fenetre elargie", q:GetWidth() > 560, true)
attendu("tableau compact borne a deux colonnes", q:GetWidth() <= 918, true)
local colonnes, debordements = {}, 0
for _, l in ipairs(pc.tLignes) do
    if l:IsShown() then
        local _, _, _, x = l:GetPoint(1)
        colonnes[x] = true
        local _, _, _, saisieX = l.cout:GetPoint(1)
        if saisieX + l.cout:GetWidth() > l:GetWidth() then debordements = debordements + 1 end
    end
end
local nombreColonnes = 0
for _ in pairs(colonnes) do nombreColonnes = nombreColonnes + 1 end
attendu("deux colonnes maximum", nombreColonnes <= 2, true)
attendu("saisies dans leur ligne", debordements, 0)
attendu("liste cachee", (dossierEq("Statistiques")), nil)
local resi
for _, d in ipairs(pc.tDossiers) do if d:IsShown() and d.case.dossier == "Résistances" then resi = d end end
local rouge, vert, bleu = resi.label:GetTextColor()
attendu("resistances en bleu", bleu > rouge and bleu > vert, true)
attendu("cadre du theme sur la categorie", resi.carte.cadre ~= nil, true)
resi.case:Click()
attendu("prive depuis le tableau", t.def.champs.resi_feu and t.def.champs.resi_feu.verrou, true)
local celluleVue
for _, l in ipairs(pc.tLignes) do if l:IsShown() and l.cle == "vue" then celluleVue = l end end
celluleVue.cout:Saisir("2")
attendu("ligne compacte", celluleVue:GetHeight(), 22)
attendu("saisie compacte", celluleVue.cout:GetHeight(), 19)
attendu("cout saisi au tableau", t.def.champs.vue.cout, "2")
pc.vueBouton:Click()
attendu("retour liste", q.vue, "liste")
attendu("liste compacte", q:GetWidth(), 530)
pc.deplier:Click()
local visibles = 0
for _, l in ipairs(pc.lignes) do if l:IsShown() then visibles = visibles + 1 end end
attendu("tout deplier montre tous les champs", visibles, #LCM.Forge.Champs("armures"))
pc.deplier:Click()
visibles = 0
for _, l in ipairs(pc.lignes) do if l:IsShown() then visibles = visibles + 1 end end
attendu("tout replier masque les champs", visibles, 0)

q.enregistrer:Click()
contient("enregistre", q.statut:GetText(), "Jeu enregistré")
local armure = F.Get(idArmure)
attendu("jeu en brouillon", armure and armure.brouillon, true)
attendu("six raretes", armure and #armure.raretes, 6)
attendu("pool lu en nombre", armure and armure.raretes[1].points, 8)
attendu("max par rarete", F.Limites(armure, "adresse", "rare").max, 4)
attendu("max du jeu", F.Limites(armure, "adresse", "commun").max, 2)
attendu("cout", F.Limites(armure, "adresse", "commun").cout, 3)
attendu("dossier prive enregistre", F.Limites(armure, "resi_feu", "commun").verrou, true)
attendu("le compendium le liste", LCM.Compendium.Entree(cj, idArmure) ~= nil, true)

-- Desormais les armures aussi passent par un jeu.
ok, raison = B.Enregistrer("objets", { id = "casque", label = "Casque", categorie = "equipement" }, true)
attendu("armure sans jeu : refusee", ok, false)
ok, raison = B.Enregistrer("objets", { id = "plastron_arme", label = "Mauvais jeu", categorie = "equipement",
    forge = "creation_arme/rare", bonus = { vue = 1 } }, true)
attendu("jeu d'une autre categorie : refusee", ok, false)
contient("     raison", raison, "n'équilibre pas Armures")

-- Et la forge ouverte depuis Armures ne propose que les jeux des armures.
cf:ChoisirCategorie("armures")
cf.forger:Click()
attendu("forge sur le jeu des armures", f.jeu.label:GetText(), "Création d'armure")
f.jeu:Click()
local proposes = 0
for _, b in ipairs(f.choix.lignes) do if b:IsShown() then proposes = proposes + 1 end end
attendu("un seul jeu propose", proposes, 1)
f.choix:Hide()

-- Modifier un jeu existant : l'etat le dit, l'enregistrement modifie sur place.
cf:ChoisirCategorie("jeux_equilibrage")
for _, r in ipairs(cf.rangees) do if r.element and r.element.id == "creation_arme" then rJeu = r end end
rJeu.reglages:Click()
q.pageJeu.lignes[1].points:Saisir("5")
attendu("marque modifie", q.etat:GetText(), "Brouillon, modifications non enregistrées.")
q.enregistrer:Click()
attendu("pool modifie", F.Get("creation_arme").raretes[1].points, 5)
attendu("la meme table, modifiee sur place", F.Get("creation_arme") == jeu, true)

-- Dupliquer et supprimer : les gestes du compendium.
ok = Ed.Dupliquer(cj, F.Get(idArmure))
attendu("dupliquer un jeu", ok, true)
local copieArmure
for _, element in ipairs(F.list) do
    if element.brouillon and element.label == "Création d'armure (copie)" then copieArmure = element end
end
attendu("la copie existe", copieArmure ~= nil, true)
local faits = Ed.Supprimer(cj, { F.Get(idArmure), copieArmure })
attendu("deux jeux supprimes", faits, 2)
attendu("jeu retire", F.Get(idArmure), nil)
attendu("brouillon efface", LCM_MJ_DB.brouillons.jeux[idArmure], nil)
ok = B.Enregistrer("objets", { id = "casque", label = "Casque", categorie = "equipement" }, true)
attendu("armures de nouveau libres", ok, true)

dire("== Bouton C : copier une colonne sur tout le dossier")
FU.Editer(nil)
local tc = q:Travail()
q.vue = "liste"
q.onglet = "champs"
q.rareteChamps = nil
q:Rafraichir()
local function enTete(nom)
    for _, b in ipairs(q.pageChamps.dossiers) do if b:IsShown() and b.dossier == nom then return b end end
end
local function ligneC(cle)
    for _, l in ipairs(q.pageChamps.lignes) do if l:IsShown() and l.cle == cle then return l end end
end
q.ouverts["Statistiques"] = true
q:Rafraichir()
local stats = enTete("Statistiques")
attendu("quatre C sur l'en-tete", stats.copie.min:IsShown() and stats.copie.base:IsShown()
    and stats.copie.max:IsShown() and stats.copie.cout:IsShown(), true)
stats.copie.max:Click()
contient("colonne vide : le dit", q.statut:GetText(), "aucune valeur à copier")
-- La valeur peut etre tapee sur n'importe quelle ligne, pas forcement la premiere.
ligneC("mystique").cout:Saisir("1")
stats.copie.cout:Click()
local tousA1 = true
for _, cle in ipairs({ "force", "mystique", "perception", "adresse", "esprit", "constitution" }) do
    if not (tc.def.champs[cle] and tc.def.champs[cle].cout == "1") then tousA1 = false end
end
attendu("cout 1 sur les six statistiques", tousA1, true)
attendu("affiche sur une autre ligne", ligneC("constitution").cout:GetText(), "1")
attendu("pas deborde sur un autre dossier", tc.def.champs.pen_feu, nil)
contient("statut", q.statut:GetText(), "Coût = 1 sur les 6 champs")
-- Par rarete : min / base / max de cette rarete, et pas de C pour le cout.
q.rareteChamps = tc.def.raretes[2].id
q:Rafraichir()
attendu("pas de C cout par rarete", enTete("Statistiques").copie.cout:IsShown(), false)
ligneC("force").base:Saisir("2")
enTete("Statistiques").copie.base:Click()
local rid = tc.def.raretes[2].id
attendu("base de la rarete copiee", tc.def.champs.esprit.raretes and tc.def.champs.esprit.raretes[rid].base, "2")
attendu("base du jeu intacte", tc.def.champs.esprit.base, nil)
-- En tableau, la carte de chaque dossier porte aussi ses C.
q.rareteChamps = nil
q.vue = "tableau"
q:Rafraichir()
local carte
for _, d in ipairs(q.pageChamps.tDossiers) do if d:IsShown() and d.copie.min.dossier == "Résistances" then carte = d end end
attendu("C dans le tableau", carte ~= nil and carte.copie.min:IsShown(), true)
local cellule
for _, l in ipairs(q.pageChamps.tLignes) do if l:IsShown() and l.cle == "resi_eau" then cellule = l end end
cellule.min:Saisir("0")
carte.copie.min:Click()
attendu("min copie au tableau", tc.def.champs.resi_feu and tc.def.champs.resi_feu.min, "0")
q.vue = "liste"
q:Hide()

dire("== Les valeurs negatives : moitie du cout, et plafonnees au pool")
-- Deux regles du 5 octobre 2026 :
--   * descendre une statistique sous sa base ne rend que la MOITIE de son
--     cout (un defaut coute a jouer autant qu'il rapporte a construire) ;
--   * ce que les negatives rendent EN TOUT ne depasse pas le pool de la
--     rarete, sinon il suffisait d'assez de defauts pour tout s'offrir.
local jeuNeg = F.Construire(Jeu())
local commun = jeuNeg.raretes[1]        -- pool 4
local rare = jeuNeg.raretes[2]       -- pool 10

-- Les autres statistiques restent SUR leur base : la force est verrouillee a 1
-- et l'ouie a une base de 2, donc les laisser a zero les mettrait sous leur
-- base et rendrait des points elles aussi.
local function V(t)
    local v = { force = 1, ouie = 2 }
    for cle, valeur in pairs(t) do v[cle] = valeur end
    return v
end

-- La moitie : escalade a -1, le point vaut 1, donc 0,5 rendu.
local demi = F.Bilan(jeuNeg, rare.id, V({ escalade = -1 }))
attendu("une negative rend la moitié", demi.credit, 0.5)
attendu("et la ligne le montre", (function()
    for _, l in ipairs(demi.lignes) do if l.champ.cle == "escalade" then return l.depense end end
end)(), -0.5)
attendu("le total la retranche", demi.total, -0.5)

-- Le cout propre d'une statistique suit : la vue vaut 2 le point, donc -1
-- rend 1.
attendu("la moitié se compte sur le coût de la statistique",
    F.Bilan(jeuNeg, rare.id, V({ vue = -1 })).credit, 1)

-- Positif et negatif ensemble : on depense plein tarif, on recupere a moitie.
local melange = F.Bilan(jeuNeg, rare.id, V({ escalade = 2, vue = -1 }))
attendu("dépensé plein tarif", melange.depenses, 2)
attendu("rendu à moitié", melange.credit, 1)
attendu("total", melange.total, 1)

-- Le PLAFOND : un pool de 4 et des negatives qui rendraient bien plus.
local beaucoup = V({ escalade = -20, vue = -20 })
local brut = F.Bilan(jeuNeg, commun.id, beaucoup)
attendu("elles rendraient beaucoup", brut.credit > commun.points, true)
attendu("mais on n'en garde que le pool", brut.creditRetenu, commun.points)
attendu("et on dit ce qui est perdu", brut.creditPerdu, brut.credit - commun.points)
attendu("le total descend d'autant, pas plus", brut.total, -commun.points)

-- Donc on peut depenser deux fois le pool, et pas un point de plus.
local bilanFond = F.Bilan(jeuNeg, commun.id, V({ escalade = -20, vue = 4 }))
attendu("on dépense le double du pool", bilanFond.depenses, 8)
attendu("et le total tombe pile sur le pool", bilanFond.total, commun.points)
attendu("un point de plus ne passerait pas",
    F.Bilan(jeuNeg, commun.id, V({ escalade = -20, vue = 5 })).total > commun.points, true)

-- Le plafond depend de la rarete : les memes valeurs rendent plus en Rare.
attendu("le pool de Rare retient davantage",
    F.Bilan(jeuNeg, rare.id, beaucoup).creditRetenu, rare.points)

-- Et donc la rarete suffisante se cherche sur les VALEURS.
attendu("deux points tiennent dans le Commun",
    F.RareteSuffisante(jeuNeg, V({ escalade = 2 })).id, "commun")

dire("== Pas de commande ni d'entree de menu")
attendu("pas de /lcm forge", LCM.UI.Menu.Trouver("forge"), nil)

local mecaniquesForge = {}
for _, champ in ipairs(F.Statistiques(LCM.Compendium.Get("traits"))) do
    mecaniquesForge[champ.cle] = true
end
attendu("Forge : Provocation disponible", mecaniquesForge.meca_provocation, true)
attendu("Forge : Intimidation disponible", mecaniquesForge.meca_intimidation, true)

dire("== Race publique ou reservee au MJ dans la Forge")
ok, raison = B.Enregistrer("jeux", {
    id = "jeu_race_acces", label = "Création de race", categorie = "races",
    raretes = { { id = "commun", label = "Commun", points = 10, couleur = "FFFFFF" } },
    champs = { vue = { cout = 1, base = 0, max = 4 } },
}, true)
attendu("jeu de race disponible", ok, true)
local races = LCM.Compendium.Get("races")
FU.Ouvrir("races")
attendu("case visible pour une race", f.mjSeulement:IsShown(), true)
attendu("publique par defaut", f.mjSeulement:EstCochee(), false)
local idRaceForge = FU.courant.creationId
f.nom:Saisir("Race jumelle")
f.mjSeulement:Click()
attendu("case MJ cochee", FU.courant.mjSeulement, true)
f.creer:Click()
local raceForge = LCM.Races.Get(idRaceForge)
attendu("restriction enregistree", raceForge and raceForge.mjSeulement, true)
local chargeMJ = __addonsCharges["LesContesMalveillants_MJ"]
LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = nil
attendu("race MJ cachee au joueur", LCM.Races.Choisissable(raceForge), false)
LCM._masterCompanion = true
__addonsCharges["LesContesMalveillants_MJ"] = chargeMJ

Ed.Ouvrir(races, raceForge)
attendu("case relue en modification", f.mjSeulement:EstCochee(), true)
f.mjSeulement:Click()
f.creer:Click()
attendu("restriction retiree", LCM.Races.Get(idRaceForge).mjSeulement, nil)
LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = nil
attendu("race publique visible au joueur", LCM.Races.Choisissable(LCM.Races.Get(idRaceForge)), true)
LCM._masterCompanion = true
__addonsCharges["LesContesMalveillants_MJ"] = chargeMJ
B.Supprimer("races", idRaceForge)
B.Supprimer("jeux", "jeu_race_acces")

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
