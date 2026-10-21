-- Atelier du MJ : saisie en seance, refus, modification, suppression, et la
-- fenetre pilotee au clic.
--
-- 15 octobre 2026 : plus de brouillons. Une entree enregistree EXISTE, d'ou
-- qu'elle vienne ; elle ne porte aucune marque, l'atelier n'a plus de
-- « lecture seule » pour le contenu des fichiers ni de « reprendre en
-- brouillon », et supprimer supprime. Les attentes qui racontaient l'ancien
-- modele ont ete reecrites ici, avec ce qui les remplace.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = obtenu == voulu
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

-- Entrees d'une seance precedente, encore dans la file d'envoi : une valide,
-- une fautive, et une correction d'une entree venue d'un fichier.
LCM.Brouillons.Set("traits", { id = "agile", label = "Agile", cout = 1, bonus = { acrobaties = 2 } })
LCM.Brouillons.Set("traits", { id = "triche", label = "Triche", cout = 1, bonus = { force = 5 } })
-- `remplacePublie` : reste de l'ancien modele, que la migration efface.
LCM.Brouillons.Set("traits",
    { id = "escalade_jungle", label = "Correction", cout = 1, remplacePublie = true })

__declencher("PLAYER_LOGIN")
local B = LCM.Brouillons

-- Ce scenario teste l'ATELIER : la saisie, les refus, la liste, la fenetre.
-- Il travaille donc sur des familles SANS jeu d'equilibrage — sinon le
-- bareme refuse tout ce qu'il ecrit, et « + Bonus » ouvre la Forge a la place
-- de la liste de choix. La campagne en publie maintenant pour les traits, les
-- races, les armes et les armures — et les etats (« Equilibrage-Etats »,
-- 21 octobre 2026) : on les ecarte de CE banc, en memoire seulement, pour que
-- le scenario puisse encore raconter son histoire.
for rang = #LCM.Forge.list, 1, -1 do
    local jeu = LCM.Forge.list[rang]
    local vise = jeu.categorie
    if vise == "traits" or vise == "races" or vise == "armes" or vise == "armures"
        or vise == "accessoires" or vise == "etats" then
        LCM.Forge.Retirer(jeu.id)
    end
end

dire("== A la connexion")
attendu("entree valide jouable", LCM.Traits.Get("agile") ~= nil, true)
attendu("  sans marque", LCM.Traits.Get("agile").brouillon, nil)
attendu("entree fautive ecartee", LCM.Traits.Get("triche"), nil)
-- Depuis le 9 octobre 2026, une correction encore dans la file est appliquee
-- au chargement par-dessus le fichier. Avant, elle tenait le temps de la
-- seance puis disparaissait au rechargement, sans un mot.
attendu("la correction s'applique", LCM.Traits.Get("escalade_jungle").label, "Correction")
attendu("  et perd ses restes de l'ancien modele",
    B.Get("traits", "escalade_jungle").remplacePublie, nil)
local annonce = false
for _, l in ipairs(__sorties) do
    -- Pas de `lower()` : sous Windows, il depend de la locale du C et abime
    -- les octets de l'UTF-8 (« é » n'en sort pas intact).
    if l:find("refusée (traits / triche)", 1, true) and l:find("primaire") then annonce = true end
end
attendu("le refus est annonce", annonce, true)

dire("== Identifiants")
attendu("accents et espaces", B.Identifiant("Écaille d'Ombre à œil"), "ecaille_d_ombre_a_oeil")
attendu("bords nettoyes", B.Identifiant("  --Force brute!  "), "force_brute")
attendu("vide", B.Identifiant(""), "")

dire("== Registre : Construire n'enregistre rien")
local avant = #LCM.Traits.list
local t = LCM.Traits.Construire({ id = "x", cout = 2, bonus = { escalade = 1 } })
attendu("forme rendue", t.cout, 2)
attendu("rien d'enregistre", #LCM.Traits.list, avant)
attendu("le fichier genere charge toujours", LCM.Traits.Get("escalade_jungle") ~= nil, true)

dire("== Enregistrer une entree")
local ok, raison = B.Enregistrer("traits", { id = "pied_sur", label = "Pied sûr", cout = 1,
    bonus = { equilibre = 2 }, avantage = { "equilibre" } }, true)
attendu("accepte", ok, true)
attendu("jouable aussitot", LCM.Traits.Get("pied_sur") ~= nil, true)
attendu("sans marque", LCM.Traits.Get("pied_sur").brouillon, nil)
attendu("sauvegarde", LCM_MJ_DB.brouillons.traits.pied_sur.label, "Pied sûr")

ok, raison = B.Enregistrer("traits", { id = "pied_sur", label = "Autre", cout = 1 }, true)
attendu("collision en creation refusee", ok, false)
dire("     raison : " .. tostring(raison))

ok, raison = B.Enregistrer("traits", { id = "brute", label = "Brute", cout = 1, bonus = { force = 2 } }, true)
attendu("primaire refusee", ok, false)
attendu("raison sans prefixe", tostring(raison):find("^LCM/") == nil, true)
attendu("rien sauvegarde", LCM_MJ_DB.brouillons.traits.brute, nil)
dire("     raison : " .. tostring(raison))

ok, raison = B.Enregistrer("traits", { id = "cher", label = "Cher", cout = 9 }, true)
attendu("cout hors bornes refuse", ok, false)

ok, raison = B.Enregistrer("traits", { id = "escalade_jungle", label = "Copie", cout = 1 }, true)
-- Toujours refuse, mais pour la bonne raison : en CREATION, un identifiant
-- deja pris est une collision, d'ou que vienne l'entree.
attendu("identifiant deja pris", ok, false)
dire("     raison : " .. tostring(raison))

ok, raison = B.Enregistrer("objets", { id = "epee", label = "Epee" }, true)
attendu("objet sans categorie refuse", ok, false)
dire("     raison : " .. tostring(raison))
ok = B.Enregistrer("objets", { id = "epee", label = "Epee", categorie = "arme", bonus = { pen_tranchant = 2 } }, true)
attendu("objet accepte", ok, true)
attendu("objet jouable", LCM.Objets.Get("epee") ~= nil, true)
ok = B.Enregistrer("objets", { id = "gantelet", label = "Gantelet", categorie = "equipement", bonus = { force = 1 } }, true)
attendu("objet : une primaire est permise (template)", ok, true)

dire("== Modifier sur place")
local tenu = LCM.Traits.Get("pied_sur")
ok = B.Enregistrer("traits", { id = "pied_sur", label = "Pied très sûr", cout = 3, bonus = { equilibre = 4 } }, false)
attendu("modification acceptee", ok, true)
attendu("meme table", LCM.Traits.Get("pied_sur"), tenu)
attendu("cout change", tenu.cout, 3)
attendu("toujours sans marque", tenu.brouillon, nil)
attendu("avantage retire", tenu.avantage.equilibre, nil)
local n = 0 for _, x in ipairs(LCM.Traits.list) do if x.id == "pied_sur" then n = n + 1 end end
attendu("pas de doublon dans la liste", n, 1)

dire("== Supprimer")
local perso = LCM.Entities.Create("Heros", "Heros", "player")
LCM.Traits.Grant(perso, "pied_sur")
attendu("porte", LCM.Traits.Bonus(perso, "equilibre"), 4)
attendu("suppression", B.Supprimer("traits", "pied_sur"), true)
attendu("retire du jeu", LCM.Traits.Get("pied_sur"), nil)
attendu("retire de la sauvegarde", LCM_MJ_DB.brouillons.traits.pied_sur, nil)
attendu("l'entite garde l'identifiant", perso.traits and perso.traits[1], "pied_sur")
attendu("mais plus de bonus", LCM.Traits.Bonus(perso, "equilibre"), 0)
attendu("rien a supprimer", B.Supprimer("traits", "inexistant"), false)

dire("== Races")
ok = B.Enregistrer("races", { id = "centaure", label = "Centaure", morphology = "quadrupede" }, true)
attendu("race acceptee", ok, true)
attendu("race jouable", LCM.Races.Get("centaure").morphology, "quadrupede")
ok, raison = B.Enregistrer("races", { id = "blob", label = "Blob", morphology = "gelee" }, true)
attendu("morphologie inconnue refusee", ok, false)
dire("     raison : " .. tostring(raison))

dire("== Atelier : la fenetre")
local A = LCM.UI.Atelier
A.Basculer()
local f = A.Fenetre()
attendu("ouverte", f:IsShown(), true)
attendu("famille par defaut", f.famille, "traits")
attendu("panneau traits visible", f.panneaux.traits:IsShown(), true)
attendu("panneau races cache", f.panneaux.races:IsShown(), false)
attendu("enregistrer visible", f.enregistrer:IsShown(), true)
attendu("supprimer cache en creation", f.supprimer:IsShown(), false)

-- la liste : une ligne par entree. Il y en avait deux pour une entree d'un
-- fichier corrigee en seance (« publie » et « remplace le publie ») ; il n'y a
-- plus qu'une entree, la corrigee.
local lignes = {}
for _, b in ipairs(f.liste.lignes) do
    if b:IsShown() and b.entreeId == "escalade_jungle" then lignes[#lignes + 1] = b end
end
attendu("une seule ligne", #lignes, 1)
lignes[1]:Click()
attendu("elle ouvre la correction", f.edition.label, "Correction")
attendu("  modifiable", f.enregistrer:IsShown(), true)
attendu("  supprimable", f.supprimer:IsShown(), true)
attendu("  sans avertissement « remplace »", (f.message:GetText() or ""):find("REMPLACE"), nil)
attendu("plus de bouton « Modifier (brouillon) »", f.reprendre, nil)
f:Nouveau()

-- Une entree d'un fichier, que la file ne tient pas : elle se modifie comme
-- toute autre, sans « remplacer » ni detour.
local idFichier
for _, t in ipairs(LCM.Traits.list) do
    if not LCM.Brouillons.Get("traits", t.id) then idFichier = t.id break end
end
if idFichier then
    local copie = LCM.Copie(LCM.Traits.Get(idFichier))
    copie.label = "Essai"
    attendu("modifiee sans detour",
        select(1, LCM.Brouillons.Enregistrer("traits", copie, false)), true)
    attendu("  en jeu", LCM.Traits.Get(idFichier).label, "Essai")
end

dire("== Atelier : choisir une icone sans la taper")
-- Les icones proposees sont celles qui servent deja dans la campagne.
attendu("le catalogue n'est pas vide", #LCM.UI.CatalogueIcones() > 0, true)
-- Dont les icones livrees avec l'addon et celles des champs de fiche : sans
-- elles, le MJ ne peut pas rehabiller une entree comme le reste de la campagne.
local catalogue = {}
for _, chemin in ipairs(LCM.UI.CatalogueIcones()) do catalogue[chemin:lower()] = true end
attendu("les icones de la campagne y sont",
    catalogue[LCM.IconeCampagne("grimoire"):lower()], true)
attendu("celles des champs de fiche aussi",
    catalogue[LCM.IconeChamp(LCM.Schema.Field("adresse")):lower()], true)
attendu("et celles des zones du corps",
    catalogue[LCM.Body.CATEGORIES[1].icone:lower()], true)
attendu("un nom lisible", LCM.UI.NomIcone("Interface\\ICONS\\INV_Sword_05"), "INV_Sword_05")
f.onglets.boutons[3]:Click()                       -- Objets : le formulaire a une icone
local po = f.panneaux.objets
attendu("l'apercu est cliquable", po.apercuBouton ~= nil, true)
po.apercuBouton:Click()
attendu("le selecteur s'ouvre", po.selecteur:IsShown(), true)
attendu("il montre des icones", po.selecteur.nombreAffiche > 0, true)
-- La recherche filtre sur le chemin.
local avant = po.selecteur.nombreAffiche
po.selecteur.recherche:Saisir("zzzz_introuvable")
attendu("une recherche sans resultat", po.selecteur.nombreAffiche, 0)
po.selecteur.recherche:Saisir("")
attendu("et on revient a tout", po.selecteur.nombreAffiche, avant)
-- Choisir pose le chemin dans le champ.
local choisi = po.selecteur.cases[1].chemin
po.selecteur.cases[1]:Click()
attendu("le selecteur se ferme", po.selecteur:IsShown(), false)
attendu("l'icone est posee", po.icone:GetText(), choisi)
attendu("et retenue dans l'edition", f.edition.icone, choisi)
f.onglets.boutons[1]:Click()

dire("== Atelier : creer un trait")
f.nouveau:Click()
local p = f.panneaux.traits
local idOeil = f.edition.id
attendu("formulaire vierge", p.nom:GetText(), "")
p.nom:Saisir("Œil de lynx")
attendu("identifiant unique affiche", (p.ident:GetText() or ""):match("^(%S+)"), idOeil)
attendu("identifiant sans rapport avec le nom", idOeil ~= "oeil_de_lynx", true)
p.cout.plus:Click()
attendu("cout 2", f.edition.cout, 2)
p.cout.maximum:Click()
attendu("cout au max", f.edition.cout, LCM.Traits.COUT_MAX)
p.cout.plus:Click()
attendu("au-dela du max refuse", f.edition.cout, LCM.Traits.COUT_MAX)
p.cout.moins:Click() p.cout.moins:Click() p.cout.moins:Click() p.cout.moins:Click()
attendu("pas sous 1", f.edition.cout, 1)
p.description.saisie:Saisir("Voit loin.")

p.ajoutBonus:Click()
attendu("liste de choix ouverte", f.choix:IsShown(), true)
local primaire = false
local ligneVue
for _, b in ipairs(f.choix.lignes) do
    if b:IsShown() then
        if LCM.Traits.PRIMAIRES[b.choix] then primaire = true end
        if b.choix == "vue" then ligneVue = b end
    end
end
attendu("aucune primaire proposee", primaire, false)
ligneVue:Click()
attendu("choix referme", f.choix:IsShown(), false)
attendu("bonus ajoute", f.edition.bonus[1] and f.edition.bonus[1].champ, "vue")
p.lignesBonus[1].montant:Saisir("3")

p.ajoutAvantage:Click()
for _, b in ipairs(f.choix.lignes) do if b:IsShown() and b.choix == "vue" then b:Click() end end
attendu("avantage ajoute", f.edition.avantage[1], "vue")

f.enregistrer:Click()
local cree = LCM.Traits.Get(idOeil)
attendu("enregistre et jouable", cree ~= nil, true)
attendu("bonus 3", cree and cree.bonus.vue, 3)
attendu("avantage", cree and cree.avantage.vue, true)
attendu("description", cree and cree.description, "Voit loin.")
attendu("plus en creation", f.edition.creation, false)
attendu("supprimer visible", f.supprimer:IsShown(), true)
attendu("sauvegarde : avantage en liste", LCM_MJ_DB.brouillons.traits[idOeil].avantage[1], "vue")

-- Deux entrees peuvent desormais porter exactement le meme nom.
local idHomonyme = B.NouvelIdentifiant()
local okHomonyme = B.Enregistrer("traits", { id = idHomonyme, label = "Œil de lynx", cout = 1 }, true)
attendu("un homonyme est accepte", okHomonyme, true)
attendu("les homonymes ont deux identifiants", idHomonyme ~= idOeil, true)

dire("== Atelier : refus affiches")
p.ajoutBonus:Click()
for _, b in ipairs(f.choix.lignes) do if b:IsShown() and b.choix == "vue" then b:Click() end end
f.enregistrer:Click()
attendu("doublon de bonus refuse", (f.message:GetText() or ""):find("deux bonus") ~= nil, true)
p.lignesBonus[2].retirer:Click()
p.lignesBonus[1].montant:Saisir("abc")
f.enregistrer:Click()
attendu("montant illisible refuse", (f.message:GetText() or ""):find("^Refusé") ~= nil, true)
dire("     message : " .. tostring(f.message:GetText()))
attendu("la version sauvegardee est intacte", LCM_MJ_DB.brouillons.traits[idOeil].bonus.vue, 3)

f.nouveau:Click()
f.enregistrer:Click()
attendu("sans nom refuse", (f.message:GetText() or ""):find("nom") ~= nil, true)

dire("== Atelier : la ligne retiree est la bonne")
f.nouveau:Click()
p.nom:Saisir("Trois bonus")
for _, champ in ipairs({ "vue", "ouie", "pistage" }) do
    p.ajoutBonus:Click()
    for _, b in ipairs(f.choix.lignes) do if b:IsShown() and b.choix == champ then b:Click() end end
end
p.lignesBonus[2].retirer:Click()
attendu("reste 2", #f.edition.bonus, 2)
attendu("1er garde", f.edition.bonus[1].champ, "vue")
attendu("2e est l'ancien 3e", f.edition.bonus[2].champ, "pistage")
attendu("ligne 3 cachee", p.lignesBonus[3]:IsShown(), false)

dire("== Atelier : supprimer depuis la fenetre")
f:Ouvrir(idOeil)
f.supprimer:Click()
attendu("confirmation demandee", f.confirmation:IsShown(), true)
attendu("pas encore supprime", LCM.Traits.Get(idOeil) ~= nil, true)
f.confirmation.oui:Click()
attendu("supprime", LCM.Traits.Get(idOeil), nil)
B.Supprimer("traits", idHomonyme)

dire("== Atelier : races et objets")
f.onglets.boutons[2]:Click()
attendu("famille races", f.famille, "races")
attendu("panneau races", f.panneaux.races:IsShown(), true)
local pr = f.panneaux.races
local idMinotaure = f.edition.id
pr.nom:Saisir("Minotaure")
pr.morphologie:Click()
for _, b in ipairs(f.choix.lignes) do if b:IsShown() and b.choix == "quadrupede" then b:Click() end end
attendu("morphologie choisie", f.edition.morphology, "quadrupede")
f.enregistrer:Click()
attendu("race creee", LCM.Races.Get(idMinotaure) and LCM.Races.Get(idMinotaure).morphology, "quadrupede")
attendu("ouverte aux joueurs par defaut", LCM.Races.Get(idMinotaure).mjSeulement, nil)
pr.mjSeulement:Click()
f.enregistrer:Click()
attendu("la case la reserve au MJ", LCM.Races.Get(idMinotaure).mjSeulement, true)
-- Rouvrir puis enregistrer sans toucher la case : l'option survit. Le
-- formulaire ne recopiait que les cles qu'il connaissait.
f:Ouvrir(idMinotaure)
attendu("la case se relit cochee", pr.mjSeulement:EstCochee(), true)
pr.description.saisie:Saisir("Cornu.")
f.enregistrer:Click()
attendu("et l'option survit a une autre modification", LCM.Races.Get(idMinotaure).mjSeulement, true)
attendu("la description passe aussi", LCM.Races.Get(idMinotaure).description, "Cornu.")

dire("== Atelier : un objet")
f.onglets.boutons[3]:Click()
attendu("famille objets", f.famille, "objets")
local po = f.panneaux.objets
local idAmulette = f.edition.id
attendu("panneau objets", po:IsShown(), true)
attendu("pas de cout pour un objet", po.cout, nil)
attendu("enregistrement propose", f.enregistrer:IsShown(), true)
po.nom:Saisir("Amulette du guetteur")
f.enregistrer:Click()
attendu("sans categorie : refus explique", (f.message:GetText() or ""):find("catégorie") ~= nil, true)
po.categorie:Click()
local cats = {}
for _, b in ipairs(f.choix.lignes) do if b:IsShown() then cats[#cats + 1] = b.choix end end
-- Quatre depuis les outils (types d'outils, 18 octobre 2026) : c'est de la
-- structure, elle se verifie en entier.
attendu("quatre categories proposees", table.concat(cats, ","), "arme,equipement,accessoire,outil")
for _, b in ipairs(f.choix.lignes) do if b:IsShown() and b.choix == "accessoire" then b:Click() end end
attendu("categorie affichee", po.categorie.label:GetText(), "Accessoire")
po.ajoutBonus:Click()
for _, b in ipairs(f.choix.lignes) do if b:IsShown() and b.choix == "vue" then b:Click() end end
po.lignesBonus[1].montant:Saisir("2")
po.ajoutAvantage:Click()
for _, b in ipairs(f.choix.lignes) do if b:IsShown() and b.choix == "pistage" then b:Click() end end
f.enregistrer:Click()
local amulette = LCM.Objets.Get(idAmulette)
attendu("objet cree", amulette ~= nil, true)
attendu("categorie", amulette and amulette.categorie, "accessoire")
attendu("bonus", amulette and amulette.bonus.vue, 2)
attendu("avantage", amulette and amulette.avantage.pistage, true)
local sauve = LCM_MJ_DB.brouillons.objets[idAmulette]
attendu("sauvegarde sans cout", sauve.cout, nil)
attendu("sauvegarde : categorie", sauve.categorie, "accessoire")
f:Ouvrir(idAmulette)
attendu("rouvert : categorie relue", f.edition.categorie, "accessoire")

dire("== Menu")
attendu("compendium lie", LCM.UI.Menu.EstLiee("systeme_aelskar"), true)


dire("== Atelier : statuts dans la liste")
f.onglets.boutons[1]:Click()
local statuts = {}
for _, b in ipairs(f.liste.lignes) do
    if b:IsShown() then statuts[b.entreeId] = b.label:GetText() end
end
attendu("fautif marque refuse", (statuts.triche or ""):find("refusé") ~= nil, true)
-- Plus de « · publié » ni de « remplace le publié » : une entree est une entree.
attendu("une entree n'a pas de suffixe", statuts.escalade_jungle, "Correction")

dire("== Supprimer une entree venue d'un fichier")
-- Avant : supprimer le « doublon » rendait le publie. Maintenant supprimer
-- supprime, et la base suit au /reload.
attendu("supprimee", B.Supprimer("traits", "escalade_jungle"), true)
attendu("retiree du jeu", LCM.Traits.Get("escalade_jungle"), nil)
attendu("notee pour la base", B.EstMasquee("traits", "escalade_jungle"), true)

dire("== Atelier : les familles du compendium du template")
local onglets = {}
for _, b in ipairs(f.onglets.boutons) do onglets[#onglets + 1] = b.label:GetText() end
attendu("six familles", table.concat(onglets, ", "), "Traits, Races, Objets, États, Apprentissages, Sacs")

f.onglets.boutons[6]:Click()
local ps = f.panneaux.sacs
local idSac = f.edition.id
attendu("un sac n'a pas d'effets", ps.ajoutBonus:IsShown(), false)
ps.nom:Saisir("Sac d'essai")
ps.places:Saisir("12")
f.enregistrer:Click()
attendu("sac cree", LCM.Sacs.Get(idSac) and LCM.Sacs.Get(idSac).places, 12)
f.onglets.boutons[1]:Click()

f.onglets.boutons[4]:Click()
local pe = f.panneaux.etats
local idPeste = f.edition.id
pe.nom:Saisir("Peste d'essai")
f.enregistrer:Click()
attendu("etat sans categorie : refus", (f.message:GetText() or ""):find("catégorie") ~= nil, true)
pe.categorie:Click()
local cats = {}
for _, b in ipairs(f.choix.lignes) do if b:IsShown() then cats[#cats + 1] = b.choix end end
attendu("trois categories d'etats", table.concat(cats, ","), "etat,maladie,intangible")
for _, b in ipairs(f.choix.lignes) do if b:IsShown() and b.choix == "etat" then b:Click() end end
pe.ajoutBonus:Click()
local force = false
for _, b in ipairs(f.choix.lignes) do if b:IsShown() and b.choix == "force" then force = true b:Click() end end
attendu("un etat peut viser la Force", force, true)
pe.lignesBonus[1].montant:Saisir("-10")
f.enregistrer:Click()
local infection = LCM.Etats.Get(idPeste)
attendu("etat cree", infection and infection.bonus.force, -10)

f.onglets.boutons[5]:Click()
local pa = f.panneaux.apprentissages
local idEtude = f.edition.id
attendu("apprentissage : pas de categorie a choisir", pa.categorie, nil)
pa.nom:Saisir("Etude de l'acrobatie")
pa.ajoutBonus:Click()
for _, b in ipairs(f.choix.lignes) do if b:IsShown() and b.choix == "acrobaties" then b:Click() end end
f.enregistrer:Click()
attendu("apprentissage cree", LCM.Apprentissages.Get(idEtude) ~= nil, true)
attendu("categorie implicite", LCM.Apprentissages.Get(idEtude).categorie, "apprentissage")

f.onglets.boutons[2]:Click()
local prace = f.panneaux.races
local idSylvaine = f.edition.id
prace.nom:Saisir("Sylvaine")
prace.morphologie:Click()
for _, b in ipairs(f.choix.lignes) do if b:IsShown() and b.choix == "humanoide" then b:Click() end end
attendu("zones de la morphologie", prace.parties:GetText(), "Tête, Torse, Bras, Jambes, Internes")
prace.ajoutBonus:Click()
for _, b in ipairs(f.choix.lignes) do if b:IsShown() and b.choix == "perception" then b:Click() end end
prace.lignesBonus[1].montant:Saisir("4")
f.enregistrer:Click()
local race = LCM.Races.Get(idSylvaine)
attendu("race avec effets", race and race.bonus.perception, 4)
local heros = LCM.Entities.Create("h2", "H2", "player")
LCM.Entities.Set_Value(heros, "race", idSylvaine)
attendu("la race donne sa Perception", LCM.Formules.Primaire(heros, "perception"), 4)

dire("== l'atelier et le jeu d'equilibrage")
-- Le bareme de la forge BLOQUE (Core/Forge.lua) : des qu'un jeu vise une
-- categorie, une entree qui n'en choisit pas est refusee. L'atelier ignorait la
-- forge, donc il ne pouvait plus rien enregistrer dans cette categorie
-- (5 octobre 2026).
LCM.Forge.Add({
    id = "jeu_traits", label = "Création de trait", categorie = "traits",
    raretes = { { id = "commun", label = "Commun", points = 10, couleur = "FFFFFF" } },
    champs = { escalade = { cout = "2", base = "0", max = "4" } },
})
f.onglets.boutons[1]:Click()
f:Nouveau()
local idSansJeu = f.edition.id
local pe = f.panneaux.traits
pe:Remplir()
attendu("le champ d'equilibrage apparait", pe.forge:IsShown(), true)
attendu("et dit qu'il faut choisir",
    (pe.bilanForge:GetText() or ""):find("Obligatoire") ~= nil, true)

-- Sans choisir : refus, avec la raison.
f.edition.label = "Sans jeu"
table.insert(f.edition.bonus, { champ = "escalade", montant = "1" })
f:Enregistrer()
attendu("refuse sans jeu", LCM.Traits.Get(idSansJeu), nil)
attendu("et on dit pourquoi",
    (f.message:GetText() or ""):find("équilibrage") ~= nil, true)

-- En le choisissant : accepte, et le bilan compte les points.
f.edition.forge = "jeu_traits/commun"
pe:Remplir()
attendu("le bilan compte le pool", (pe.bilanForge:GetText() or ""):find("/ 10") ~= nil, true)
f:Enregistrer()
attendu("accepte avec son jeu", LCM.Traits.Get(idSansJeu) ~= nil, true)
attendu("et le jeu est retenu", LCM.Brouillons.Get("traits", idSansJeu).forge, "jeu_traits/commun")

-- Les bonus proposes viennent du JEU, pas de la feuille entiere.
f:Nouveau()
f.edition.label = "Essai bornes"
f.edition.forge = "jeu_traits/commun"
pe:Remplir()
pe.ajoutBonus:Click()
local proposes = {}
for _, b in ipairs(f.choix.lignes) do if b:IsShown() then proposes[#proposes + 1] = b.choix end end
-- Le jeu couvre TOUT le bloc de statistiques de sa categorie : ce qu'il
-- apporte, ce sont les bornes de chacune et le retrait des verrouillees.
attendu("une liste a proposer", #proposes > 0, true)
attendu("escalade y est", (("," .. table.concat(proposes, ",") .. ","):find(",escalade,")) ~= nil, true)
-- Les bornes voyagent dans l'intertitre de chaque option : on les verifie sur
-- la ligne posee, qui est ce que le MJ lit en saisissant.
attendu("une statistique verrouillee n'est pas proposee",
    (("," .. table.concat(proposes, ",") .. ","):find(",pa,")) == nil
    or LCM.Forge.Limites(LCM.Forge.Get("jeu_traits"), "pa", "commun").verrou ~= true, true)
for _, b in ipairs(f.choix.lignes) do if b:IsShown() and b.choix == "escalade" then b:Click() end end

-- La ligne porte ses bornes, et passe en rouge quand on en sort.
pe.lignesBonus[1].montant:Saisir("2")
pe:Remplir()
attendu("les bornes sont dites", (pe.lignesBonus[1].bornes:GetText() or ""):find("2 pt") ~= nil, true)
local rouge = { pe.lignesBonus[1].bornes:GetTextColor() }
pe.lignesBonus[1].montant:Saisir("9")
pe:Remplir()
local horsBornes = { pe.lignesBonus[1].bornes:GetTextColor() }
attendu("hors bareme : la couleur change", horsBornes[1] ~= rouge[1] or horsBornes[2] ~= rouge[2], true)
attendu("et le bilan refuse aussi",
    (pe.bilanForge:GetText() or ""):find("maximum") ~= nil, true)

-- « + Bonus » ouvre LA FORGE quand un jeu vise la categorie : son panneau
-- range les statistiques par dossier repliable, montre les bornes et compte le
-- pool. Une liste a plat de cent quarante entrees etait intenable.
f:Nouveau()
f.edition.label = "Par la forge"
f.edition.forge = "jeu_traits/commun"
pe:Remplir()
pe.ajoutBonus:Click()
local forge = LCM.UI.Forge.Fenetre()
attendu("la forge s'ouvre", forge:IsShown(), true)
attendu("en mode « rendre »", LCM.UI.Forge.rendre ~= nil, true)
attendu("et le bouton le dit", forge.creer.label:GetText(), "Reprendre ces valeurs")
LCM.UI.Forge.courant.valeurs.escalade = 3
forge.creer:Click()
attendu("les valeurs reviennent dans l'atelier", #f.edition.bonus, 1)
attendu("avec leur montant", f.edition.bonus[1].montant, "3")
attendu("et le jeu reste choisi", f.edition.forge, "jeu_traits/commun")
attendu("la forge se referme", forge:IsShown(), false)
attendu("le mode « rendre » est retombe", LCM.UI.Forge.rendre, nil)

-- Sans jeu choisi, la forge s'ouvre quand meme : c'est ELLE qui propose le jeu
-- et la rarete, donc on n'a plus a les choisir avant. L'atelier demandait
-- « choisis d'abord le jeu » ; ce detour n'a plus lieu d'etre.
f:Nouveau()
pe:Remplir()
attendu("rien n'est encore choisi", f.edition.forge, nil)
pe.ajoutBonus:Click()
attendu("la forge s'ouvre tout de meme", LCM.UI.Forge.Fenetre():IsShown(), true)
LCM.UI.Forge.Fenetre():Hide()
LCM.Brouillons.Supprimer("traits", idSansJeu)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
