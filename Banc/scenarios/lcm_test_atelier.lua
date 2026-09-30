-- Atelier du MJ : saisie des brouillons en seance, refus, modification,
-- suppression, et la fenetre pilotee au clic.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = obtenu == voulu
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

-- Brouillons d'une seance precedente, deja en sauvegarde : un valide, un
-- fautif, et un qui reprend l'identifiant d'un contenu publie.
LCM.Brouillons.Set("traits", { id = "agile", label = "Agile", cout = 1, bonus = { acrobaties = 2 } })
LCM.Brouillons.Set("traits", { id = "triche", label = "Triche", cout = 1, bonus = { force = 5 } })
LCM.Brouillons.Set("traits", { id = "escalade_jungle", label = "Correction", cout = 1 })

__declencher("PLAYER_LOGIN")
local B = LCM.Brouillons

dire("== A la connexion")
attendu("brouillon valide jouable", LCM.Traits.Get("agile") and LCM.Traits.Get("agile").brouillon, true)
attendu("brouillon fautif ecarte", LCM.Traits.Get("triche"), nil)
attendu("le fichier fait foi", LCM.Traits.Get("escalade_jungle").label, "Escalade de la jungle")
local annonce = false
for _, l in ipairs(__sorties) do
    if l:find("brouillon refuse %(traits%)") and l:find("primaire") then annonce = true end
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

dire("== Enregistrer un brouillon")
local ok, raison = B.Enregistrer("traits", { id = "pied_sur", label = "Pied sûr", cout = 1,
    bonus = { equilibre = 2 }, avantage = { "equilibre" } }, true)
attendu("accepte", ok, true)
attendu("jouable aussitot", LCM.Traits.Get("pied_sur") ~= nil, true)
attendu("marque brouillon", LCM.Traits.Get("pied_sur").brouillon, true)
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
attendu("contenu publie protege", ok, false)
dire("     raison : " .. tostring(raison))

ok, raison = B.Enregistrer("objets", { id = "epee", label = "Epee" }, true)
attendu("objet sans categorie refuse", ok, false)
dire("     raison : " .. tostring(raison))
ok = B.Enregistrer("objets", { id = "epee", label = "Epee", categorie = "arme", bonus = { pen_tranchant = 2 } }, true)
attendu("objet accepte", ok, true)
attendu("objet jouable", LCM.Objets.Get("epee") and LCM.Objets.Get("epee").brouillon, true)
ok = B.Enregistrer("objets", { id = "gantelet", label = "Gantelet", categorie = "equipement", bonus = { force = 1 } }, true)
attendu("objet : primaire refusee aussi", ok, false)

dire("== Modifier sur place")
local tenu = LCM.Traits.Get("pied_sur")
ok = B.Enregistrer("traits", { id = "pied_sur", label = "Pied très sûr", cout = 3, bonus = { equilibre = 4 } }, false)
attendu("modification acceptee", ok, true)
attendu("meme table", LCM.Traits.Get("pied_sur"), tenu)
attendu("cout change", tenu.cout, 3)
attendu("toujours brouillon", tenu.brouillon, true)
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

-- la liste : le trait publie y est, en lecture seule
local trouve
local doublon
for _, b in ipairs(f.liste.lignes) do
    if b:IsShown() and b.entreeId == "escalade_jungle" then
        if b.publie then trouve = b else doublon = b end
    end
end
attendu("doublon liste a part", doublon ~= nil, true)
attendu("publie liste", trouve ~= nil, true)
trouve:Click()
attendu("publie : lecture seule", f.enregistrer:IsShown(), false)
attendu("publie : bonus charges", #f.edition.bonus, 1)
attendu("publie : avantage charge", f.edition.avantage[1], "escalade")
attendu("publie : pas de suppression", f.supprimer:IsShown(), false)
doublon:Click()
attendu("doublon : brouillon ouvert", f.edition.label, "Correction")
attendu("doublon : pas d'enregistrement", f.enregistrer:IsShown(), false)
attendu("doublon : suppression possible", f.supprimer:IsShown(), true)
attendu("doublon : explique", (f.message:GetText() or ""):find("déjà publié") ~= nil, true)

dire("== Atelier : creer un trait")
f.nouveau:Click()
local p = f.panneaux.traits
attendu("formulaire vierge", p.nom:GetText(), "")
p.nom:Saisir("Œil de lynx")
attendu("identifiant derive", (p.ident:GetText() or ""):match("^(%S+)"), "oeil_de_lynx")
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
local cree = LCM.Traits.Get("oeil_de_lynx")
attendu("enregistre et jouable", cree ~= nil, true)
attendu("bonus 3", cree and cree.bonus.vue, 3)
attendu("avantage", cree and cree.avantage.vue, true)
attendu("description", cree and cree.description, "Voit loin.")
attendu("plus en creation", f.edition.creation, false)
attendu("supprimer visible", f.supprimer:IsShown(), true)
attendu("sauvegarde : avantage en liste", LCM_MJ_DB.brouillons.traits.oeil_de_lynx.avantage[1], "vue")

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
attendu("la version sauvegardee est intacte", LCM_MJ_DB.brouillons.traits.oeil_de_lynx.bonus.vue, 3)

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
f:Ouvrir("oeil_de_lynx")
f.supprimer:Click()
attendu("confirmation demandee", f.confirmation:IsShown(), true)
attendu("pas encore supprime", LCM.Traits.Get("oeil_de_lynx") ~= nil, true)
f.confirmation.oui:Click()
attendu("supprime", LCM.Traits.Get("oeil_de_lynx"), nil)

dire("== Atelier : races et objets")
f.onglets.boutons[2]:Click()
attendu("famille races", f.famille, "races")
attendu("panneau races", f.panneaux.races:IsShown(), true)
local pr = f.panneaux.races
pr.nom:Saisir("Minotaure")
pr.morphologie:Click()
for _, b in ipairs(f.choix.lignes) do if b:IsShown() and b.choix == "quadrupede" then b:Click() end end
attendu("morphologie choisie", f.edition.morphology, "quadrupede")
f.enregistrer:Click()
attendu("race creee", LCM.Races.Get("minotaure") and LCM.Races.Get("minotaure").morphology, "quadrupede")

dire("== Atelier : un objet")
f.onglets.boutons[3]:Click()
attendu("famille objets", f.famille, "objets")
local po = f.panneaux.objets
attendu("panneau objets", po:IsShown(), true)
attendu("pas de cout pour un objet", po.cout, nil)
attendu("enregistrement propose", f.enregistrer:IsShown(), true)
po.nom:Saisir("Amulette du guetteur")
f.enregistrer:Click()
attendu("sans categorie : refus explique", (f.message:GetText() or ""):find("catégorie") ~= nil, true)
po.categorie:Click()
local cats = {}
for _, b in ipairs(f.choix.lignes) do if b:IsShown() then cats[#cats + 1] = b.choix end end
attendu("trois categories proposees", table.concat(cats, ","), "arme,equipement,accessoire")
for _, b in ipairs(f.choix.lignes) do if b:IsShown() and b.choix == "accessoire" then b:Click() end end
attendu("categorie affichee", po.categorie.label:GetText(), "Accessoire")
po.ajoutBonus:Click()
for _, b in ipairs(f.choix.lignes) do if b:IsShown() and b.choix == "vue" then b:Click() end end
po.lignesBonus[1].montant:Saisir("2")
po.ajoutAvantage:Click()
for _, b in ipairs(f.choix.lignes) do if b:IsShown() and b.choix == "pistage" then b:Click() end end
f.enregistrer:Click()
local amulette = LCM.Objets.Get("amulette_du_guetteur")
attendu("objet cree", amulette ~= nil, true)
attendu("categorie", amulette and amulette.categorie, "accessoire")
attendu("bonus", amulette and amulette.bonus.vue, 2)
attendu("avantage", amulette and amulette.avantage.pistage, true)
local sauve = LCM_MJ_DB.brouillons.objets.amulette_du_guetteur
attendu("sauvegarde sans cout", sauve.cout, nil)
attendu("sauvegarde : categorie", sauve.categorie, "accessoire")
f:Ouvrir("amulette_du_guetteur")
attendu("rouvert : categorie relue", f.edition.categorie, "accessoire")

dire("== Radial")
attendu("compendium lie", LCM.UI.Radial.EstLiee("compendium"), true)


dire("== Atelier : statuts dans la liste")
f.onglets.boutons[1]:Click()
local statuts = {}
for _, b in ipairs(f.liste.lignes) do
    if b:IsShown() then statuts[b.entreeId .. (b.publie and ":publie" or "")] = b.label:GetText() end
end
attendu("fautif marque refuse", (statuts.triche or ""):find("refusé") ~= nil, true)
attendu("doublon marque", (statuts.escalade_jungle or ""):find("déjà publié") ~= nil, true)
attendu("publie marque", (statuts["escalade_jungle:publie"] or ""):find("· publié") ~= nil, true)

dire("== Supprimer un doublon laisse le publie en place")
attendu("le brouillon doublon part", B.Supprimer("traits", "escalade_jungle"), true)
attendu("le trait publie reste", LCM.Traits.Get("escalade_jungle") ~= nil, true)
attendu("et reste publie", LCM.Traits.Get("escalade_jungle").brouillon, nil)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
