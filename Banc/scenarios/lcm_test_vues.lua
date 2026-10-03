-- Les fenetres tirees de la fiche, organisees comme dans le template :
-- registre, onglets, liaison au menu, Sante, Expertises, Penetration &
-- Resistances, Deplacement.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()   -- ce scenario joue un personnage : il le dit
local V = LCM.Vues
local M = LCM.UI.Menu

dire("== le registre refuse les references fausses")
local function refus(definition)
    local ok, err = pcall(V.Add, definition)
    return ok == false and tostring(err) or "ACCEPTE"
end
local avant = #V.list
dire("   " .. refus({ id = "a", blocs = { { onglet = "inexistant" } } }))
attendu("onglet inconnu", refus({ id = "a", blocs = { { onglet = "inexistant" } } }):find("onglet inconnu") ~= nil, true)
attendu("section inconnue", refus({ id = "b", blocs = { { section = { "general", "Nulle part" } } } }):find("absente") ~= nil, true)
attendu("champ inconnu", refus({ id = "c", blocs = { { champs = { "force", "rien" } } } }):find("champ inconnu") ~= nil, true)
attendu("vue vide", refus({ id = "d", blocs = {} }):find("vue vide") ~= nil, true)
attendu("onglet vide", refus({ id = "e", onglets = { { id = "x", blocs = {} } } }):find("onglet vide") ~= nil, true)
attendu("bloc sans cible", refus({ id = "f", blocs = { { label = "x" } } }):find("designe") ~= nil, true)
attendu("doublon", refus({ id = "sante", blocs = { { onglet = "general" } } }):find("en double") ~= nil, true)
attendu("rien d'enregistre par les refus", #V.list, avant)

dire("== les fenetres du template")
local ids = {}
for _, v in ipairs(V.list) do ids[#ids + 1] = v.id end
attendu("vues", table.concat(ids, ","), "regles,fiche,sante,equipement,apprentissage,expertise,penetrations_resistances,deplacement,statistiques")
local function onglets(id)
    local out = {}
    for _, o in ipairs(V.Get(id).onglets) do out[#out + 1] = o.label end
    return table.concat(out, ", ")
end
attendu("Sante", onglets("sante"), "Physique, États, Maladies, Intangible")
attendu("Equipements", onglets("equipement"), "Armes, Armures, Accessoires")
attendu("Expertises", onglets("expertise"), "Observations, Athlétisme, Filouterie")
attendu("Pen & Res : resistances d'abord", onglets("penetrations_resistances"), "Résistances, Pénétrations")
local n = 0
for _, o in ipairs(V.Get("expertise").onglets) do
    for _, s in ipairs(o.sections) do n = n + #s.fields end
end
attendu("26 expertises", n, 26)
for _, id in ipairs(ids) do attendu("  " .. id .. " : entree du menu allumee", M.EstLiee(id), true) end

dire("== Sante")
local moi = LCM.Entities.Self()
LCM.Entities.Set_Value(moi, "race", "humain")
LCM.Entities.Set_Value(moi, "niveau", 5)
LCM.Entities.Set_Value(moi, "constitution", 6)
LCM.Entities.Set_Value(moi, "sec_vitalite", 4)
M.Trouver("sante").onClick()
local fs = LCM.UI.Vues.frames.sante
attendu("ouverte", fs:IsShown(), true)
attendu("titre en capitales", fs.titre:GetText(), "SANTÉ")
attendu("nom du personnage", fs.nom:GetText(), tostring(moi.name))
attendu("onglet Physique", fs.onglet, "physique")
local corps = fs.pages.physique.lignes[1]
attendu("les zones, sans la jauge globale", corps.total:IsShown(), false)
local zones = 0
for _, z in ipairs(corps.zones) do if z:IsShown() then zones = zones + 1 end end
attendu("cinq zones", zones, 5)

dire("== la blessure se voit dans la fiche")
local bras
for _, z in ipairs(corps.zones) do if z.partieId == "bras" then bras = z end end
bras.boutons[1]:Click()
attendu("la zone perd un point", bras.barre.label:GetText(), "11 / 12")
SlashCmdList.LCM("fiche")
local ligneFiche = LCM.UI.Fiche.frame.pages.statistiques.lignes[1]
attendu("la jauge des PV de la fiche le montre", ligneFiche.total.barre.label:GetText(), "41 / 42")
SlashCmdList.LCM("fiche")
bras.boutons[3]:Click()

dire("== Sante : Intangible")
fs.barre.boutons[4]:Click()
local intangible = fs.pages.intangible
local noms = {}
for _, l in ipairs(intangible.lignes) do if l.barre then noms[#noms + 1] = l.label:GetText() .. " " .. l.barre.label:GetText() end end
attendu("Esprit et Ame sur 100", table.concat(noms, ", "), "Esprit 100 / 100, Âme 100 / 100")
attendu("et les etats intangibles (10)", intangible.blocs[2].occupation:GetText(), "0 / 10")

dire("== Sante : Etats et Maladies")
LCM.Brouillons.Enregistrer("etats", { id = "peste_d_essai", label = "Peste d'essai", categorie = "etat",
    description = "Le sang s'empoisonne.", bonus = { force = -10 } }, true)
fs.barre.boutons[2]:Click()
local etats = fs.pages.etats
attendu("30 emplacements", etats.blocs[1].occupation:GetText(), "0 / 30")
local conteneur = etats.blocs[1].conteneur
attendu("une seule case libre montree", #conteneur.emplacements, 1)
attendu("case vide", conteneur.emplacements[1].nom:GetText(), "Emplacement")
conteneur.emplacements[1].action:Click()
local choix = LCM.UI.Fiche.choixConteneur
for _, b in ipairs(choix.lignes) do if b:IsShown() and b.choix == "peste_d_essai" then b:Click() end end
attendu("etat pose", LCM.Etats.Porte(moi, "peste_d_essai"), true)
attendu("affiche", conteneur.emplacements[1].nom:GetText(), "Peste d'essai  |cff99907f·|r")
attendu("ses effets", conteneur.emplacements[1].effets:GetText(), "Force -10")
attendu("une nouvelle case libre apparait", conteneur.emplacements[2]:IsShown(), true)
attendu("vide", conteneur.emplacements[2].nom:GetText(), "Emplacement")
attendu("pas plus", conteneur.emplacements[3], nil)
attendu("la Force s'en ressent", LCM.Formules.Primaire(moi, "force"), -10)
conteneur.emplacements[1].action:Click()
attendu("retire", LCM.Etats.Porte(moi, "peste_d_essai"), false)
fs.barre.boutons[3]:Click()
attendu("Maladies : 10", fs.pages.maladies.blocs[1].occupation:GetText(), "0 / 10")

dire("== Apprentissage")
LCM.Brouillons.Enregistrer("apprentissages", { id = "etude_acrobatie", label = "Étude de l'acrobatie : Base Volume 1",
    bonus = { acrobaties = 1 } }, true)
M.Trouver("apprentissage").onClick()
local fa = LCM.UI.Vues.frames.apprentissage
attendu("60 emplacements", fa.page.blocs[1].occupation:GetText(), "0 / 60")
LCM.Apprentissages.Placer(moi, "etude_acrobatie")
fa:Actualiser()
attendu("l'etude compte", LCM.Effets.Bonus(moi, "acrobaties"), 1)
attendu("et s'affiche", fa.page.blocs[1].occupation:GetText(), "1 / 60")
fa:Hide()

dire("== Expertises")
LCM.Entities.Set_Value(moi, "escalade", 4)
LCM.Traits.Grant(moi, "escalade_jungle")
M.Trouver("expertise").onClick()
local fe = LCM.UI.Vues.frames.expertise
attendu("ouverte", fe:IsShown(), true)
attendu("onglet Observations", fe.onglet, "observations")
attendu("9 observations", #fe.pages.observations.lignes, 9)
fe.barre.boutons[2]:Click()
attendu("10 en athletisme", #fe.pages.athletisme.lignes, 10)
local escalade
for _, l in ipairs(fe.pages.athletisme.lignes) do if l.label:GetText() == "Escalade" then escalade = l end end
attendu("valeur", escalade.valeur:GetText(), "4")
attendu("bonus de trait dans sa colonne", escalade.bonus:GetText(), "+3")
attendu("case d'avantage", escalade.avantage:IsShown(), true)
local nSorties = #__sorties
escalade.lancer:Click()
attendu("le jet part", #__sorties > nSorties, true)
dire("   " .. __sansCouleur(__sorties[#__sorties]))
attendu("pas a la meme place que Sante", select(4, fe:GetPoint(1)) ~= select(4, fs:GetPoint(1)), true)

dire("== reclic : se referme ; rouvrir relit le personnage joue")
M.Trouver("expertise").onClick()
attendu("refermee", fe:IsShown(), false)
local autre = LCM.Personnages.Creer("Ysolde", { race = "humain", niveau = 3 })
LCM.Personnages.Choisir(autre.id)
M.Trouver("expertise").onClick()
attendu("montre le nouveau personnage", fe.nom:GetText(), "Ysolde")
attendu("plus le bonus de l'ancien", escalade.bonus:GetText(), "")
attendu("meme fenetre, pas une nouvelle", LCM.UI.Vues.frames.expertise, fe)

dire("== Penetration & Resistances")
M.Trouver("penetrations_resistances").onClick()
local fr = LCM.UI.Vues.frames.penetrations_resistances
attendu("ouverte sur les resistances", fr.onglet, "resistances")
attendu("quinze types", #fr.pages.resistances.lignes, 15)

dire("== Statistiques : le recapitulatif du template")
LCM.Personnages.Choisir(moi.id)
LCM.Entities.Set_Value(moi, "force", 3)
LCM.Brouillons.Enregistrer("objets", { id = "gantelets", label = "Gantelets", categorie = "equipement",
    bonus = { force = 2, force_attaque = 3, pa = 1 } }, true)
LCM.Objets.Placer(moi, "gantelets")   -- geste brut : on teste le recapitulatif, pas les sacs
M.Trouver("statistiques").onClick()
local fst = LCM.UI.Vues.frames.statistiques
-- En deux volets depuis le 3 octobre 2026 : les familles en sommaire a gauche
-- (la piece des Regles), la famille choisie seule a droite. Avant, dix-huit
-- dossiers replies ou ouverts s'empilaient dans une colonne.
attendu("pas de bande d'onglets", fst.barre, nil)
attendu("un sommaire", fst.sommaire ~= nil, true)
local function entreesStats()
    local out = {}
    for _, e in ipairs(fst.sommaire.entrees) do
        if e:IsShown() then out[#out + 1] = e end
    end
    return out
end
attendu("dix-huit familles, pas un sous-chapitre de plus", #entreesStats(), 18)
attendu("ouverte sur la premiere", fst.onglet, "statistiques")
attendu("et le sommaire le dit", entreesStats()[1].marque, "ici")
-- Le libelle d'une famille de combat vient de sa section, pas d'une copie.
attendu("libelle repris de la section", entreesStats()[8].label:GetText(), "Attaques & Défense")
attendu("la page garde sa largeur d'avant", fst.pages.statistiques.blocs[1]:GetWidth(), 312)

local function famille(id)
    for _, e in ipairs(entreesStats()) do
        if e.ongletId == id then e:Click() end
    end
    return fst.pages[id].blocs[1]
end
local stats = famille("statistiques")
-- Le paragraphe d'introduction a ete retire le 3 octobre 2026 : la fenetre
-- s'appelle « Statistiques », elle n'a pas besoin de dire qu'elle en contient.
attendu("pas de paragraphe d'introduction", stats.paragraphe, nil)
attendu("un seul bloc par page", #fst.pages.statistiques.blocs, 1)
attendu("qui ne se replie plus", stats.bascule, nil)
attendu("ses lignes visibles", stats.lignes[1]:IsShown(), true)
attendu("Force totale : 3 + 2 (objet)", stats.lignes[1].valeur:GetText(), "5")
local attaques = famille("attaques_defense")
attendu("cliquer une famille l'affiche", fst.onglet, "attaques_defense")
attendu("et cache l'autre", fst.pages.statistiques:IsShown(), false)
attendu("Force d'attaque : l'objet", attaques.lignes[1].valeur:GetText(), "3")
local bonus = famille("bonus")
attendu("Bonus : PA +1", bonus.lignes[1].valeur:GetText(), "+1")
attendu("Bonus : Fatigue sans bonus", bonus.lignes[2].valeur:GetText(), "0")
for _, e in ipairs(entreesStats()) do
    if e.ongletId == "bonus" then attendu("la puce suit la famille", e.marque, "ici") end
end
LCM.Entities.Set_Value(moi, "force", 4)
fst:Montrer()
attendu("rouvrir garde la famille", fst.onglet, "bonus")
famille("statistiques")
attendu("et relit le personnage", fst.pages.statistiques.blocs[1].lignes[1].valeur:GetText(), "6")
fst:Hide()
attendu("les statistiques de combat sont des cibles de bonus",
    LCM.Schema.Field("force_attaque") and LCM.Schema.Field("force_attaque").kind, "stat")

dire("== la fenetre prend la hauteur de son contenu")
local fiche = LCM.UI.Vues.Fenetre("fiche")
fiche:Montrer()
local page = fiche.pages[fiche.onglet]
-- On compare aux memes grandeurs que le code : le banc ne resout pas les
-- hauteurs d'ancrage, donc `zone:GetHeight()` y vaut zero et ne prouve rien.
local chrome = fiche.insetHaut + fiche.insetBas + fiche.hautZone
attendu("la fenetre fait la taille de son contenu",
    math.abs(fiche:GetHeight() - (chrome + page.hauteur)) < 1, true)
attendu("et la zone connait toute la page", fiche.zone.hauteurContenu, page.hauteur)

dire("   une page plus courte raccourcit la fenetre")
local grande = fiche:GetHeight()
fiche:Afficher("traits")
attendu("l'onglet Traits est plus court", fiche:GetHeight() < grande, true)

dire("   tirer la poignee reprend la main")
fiche:SetHeight(200)
fiche.hauteurChoisie = true
fiche:Afficher(fiche.onglet)
attendu("la hauteur choisie est gardee", fiche:GetHeight(), 200)
fiche.hauteurChoisie = nil
fiche:Hide()

dire("== Regles : la fenetre du template")
M.Trouver("regles").onClick()
local r = LCM.UI.Vues.frames and LCM.UI.Vues.frames.regles or LCM.UI.Vues.Fenetre("regles")
attendu("ouverte", r:IsShown(), true)
-- Les Regles se lisent : leurs chapitres sont dans un sommaire a gauche, pas
-- dans une bande d'onglets en haut.
attendu("pas de bande d'onglets", r.barre, nil)
attendu("un sommaire", r.sommaire ~= nil, true)
local function entrees()
    local out = {}
    for _, e in ipairs(r.sommaire.entrees) do
        if e:IsShown() then out[#out + 1] = e end
    end
    return out
end
local chapitres = {}
for _, e in ipairs(entrees()) do
    if e.cible == 0 then chapitres[#chapitres + 1] = e.label:GetText() end
end
attendu("les huit chapitres", table.concat(chapitres, ", "),
    "Fondamentaux, Principe, Personnages, Ressources, Tests et Expertises, Combat, Magie et effets, Équipement, Progression")
local fond = r.pages.fondamentaux
attendu("cinq blocs, un par separateur", #fond.blocs, 5)
attendu("premier bloc", fond.blocs[1].titre:GetText(), "PRINCIPE")
attendu("texte d'origine", fond.blocs[1].paragraphe:GetText():find("^Les contes malveillants sont") ~= nil, true)
attendu("taille 14", select(2, fond.blocs[1].paragraphe:GetFont()), 14)
attendu("le dernier separateur, sans texte", fond.blocs[5].paragraphe, nil)
attendu("pas de personnage en sous-titre", r.sousTitre:IsShown() and r.sousTitre:GetText() ~= "" , false)

dire("   les titres de blocs sont les sous-chapitres")
local sous = {}
for _, e in ipairs(entrees()) do
    if e.cible ~= 0 then sous[#sous + 1] = e.label:GetText() end
end
-- Le premier bloc est a l'ordonnee zero : il est compte plus haut avec les
-- chapitres, les quatre suivants ont une cible.
attendu("quatre blocs plus bas", table.concat(sous, ", "),
    "Maitres du jeu, Les joueurs :, Le principe des tests, [NF] - No Fatigue")
local cible = nil
for _, e in ipairs(entrees()) do
    if e.label:GetText() == "Le principe des tests" then cible = e end
end
cible:Click()
attendu("cliquer un sous-chapitre fait defiler", r.zone.decalage > 0, true)
attendu("jusqu'a son bloc", math.abs(r.zone.decalage - cible.cible) < 0.5, true)
-- On interroge l'etat, pas le dessin : la puce est une gemme de l'atlas
-- quand il est la, un chevron sinon.
attendu("et le sommaire marque l'endroit", cible.marque, "ici")

dire("   le marquage suit la molette, pas seulement le clic")
-- Remonter d'un cran doit rendre la puce au bloc precedent : un sommaire qui
-- ne bouge qu'au clic ment des qu'on fait defiler a la main.
local precedent = nil
for _, e in ipairs(entrees()) do
    if e.label:GetText() == "Les joueurs :" then precedent = e end
end
r.zone:Aller(precedent.cible)
attendu("la puce a suivi", precedent.marque, "ici")
-- Un sous-chapitre qu'on a quitte n'a plus de puce du tout : seuls les
-- chapitres en portent une en permanence.
attendu("et l'autre s'est eteinte", cible.marque, "")
r.zone:Aller(0)

dire("   un autre chapitre")
local vers = nil
for _, e in ipairs(entrees()) do
    if e.label:GetText() == "Personnages" then vers = e end
end
vers:Click()
attendu("un onglet vide s'affiche", r.onglet, "personnages")
attendu("le defilement repart du haut", r.zone.decalage, 0)
attendu("et le chapitre vide n'a pas de sous-chapitre", #entrees(), 8)
attendu("sans bloc", #r.pages.personnages.blocs, 0)
attendu("onglet vide non declare : refuse", refus({ id = "vide_x", onglets = { { id = "a", label = "A" } } }):find("onglet vide") ~= nil, true)
M.Trouver("regles").onClick()
attendu("refermee", r:IsShown(), false)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
