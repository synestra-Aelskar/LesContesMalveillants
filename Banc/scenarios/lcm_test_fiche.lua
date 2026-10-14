-- La Fiche, organisee comme celle du template : onglets Statistiques,
-- Facultes, Traits ; blocs, lignes, en-tete, defilement.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

-- Une race TEMOIN, sans aucun bonus : ces scenarios verifient des FORMULES.
-- Ils se posaient sur « humain », dont l'equilibrage a ensuite donne +3 a
-- toutes les statistiques — et les PV, le poids et les sauts ont bouge sans
-- qu'une ligne de formule ait change (constate le 11 octobre 2026). Une race
-- neutre les rend insensibles au reglage du jeu, qui a le droit de bouger.
LCM.Brouillons.Set("races", { id = "temoin", label = "Témoin", morphology = "humanoide" })

__declencher("PLAYER_LOGIN")
__personnage()   -- ce scenario joue un personnage : il le dit

local moi = LCM.Entities.Self()
LCM.Entities.Set_Value(moi, "race", "temoin")
LCM.Entities.Set_Value(moi, "niveau", 5)
LCM.Entities.Set_Value(moi, "constitution", 6)
LCM.Entities.Set_Value(moi, "sec_vitalite", 4)
LCM.Entities.Set_Value(moi, "force", 4)
LCM.Entities.Set_Value(moi, "adresse", 3)

dire("== ouverture")
SlashCmdList.LCM("fiche")
local f = LCM.UI.Fiche.frame
attendu("la fenetre existe", f ~= nil, true)
attendu("elle est affichee", f:IsShown(), true)
attendu("elle porte le nom de l entite", f.nom:GetText(), "Reika")
attendu("titre en capitales", f.titre:GetText(), "FICHE")
-- Le nom vit dans l'en-tete : entre le titre et le filet d'or, pas dessus.
local _, _, _, _, yTitre = f.titre:GetPoint(1)
local _, _, _, _, yNom = f.sousTitre:GetPoint(1)
local _, _, _, _, yRegle = f.regle:GetPoint(1)
attendu("le nom est sous le titre", yNom < yTitre, true)
-- Le bas du texte, pas son centre, et mesure sur sa police : un « 7 » en dur
-- ne veut plus rien dire des qu'une fenetre change de largeur.
local hautNom = select(2, f.sousTitre:GetFont()) / 2
attendu("et au-dessus du filet", yNom - hautNom > yRegle, true)

dire("== les onglets du template")
local noms = {}
for _, b in ipairs(f.barre.boutons) do noms[#noms + 1] = b.label:GetText() end
attendu("trois onglets", table.concat(noms, ", "), "Statistiques, Facultés, Traits")
attendu("le premier est actif", f.barre.actif, "statistiques")
attendu("sa page est visible", f.pages.statistiques:IsShown(), true)
attendu("les autres non", f.pages.facultes:IsShown(), false)
local largeurBandeau = f.barre:GetWidth()
local finRangee = 0
for _, b in ipairs(f.barre.boutons) do
    local _, _, _, x = b:GetPoint(1)
    finRangee = math.max(finRangee, (x or 0) + b:GetWidth())
end
attendu("aucun onglet ne deborde", finRangee <= largeurBandeau + 0.5, true)
attendu("onglet actif dore", select(1, f.barre.boutons[1].label:GetTextColor()) > 0.95, true)

dire("== Statistiques : les blocs du template, dans l'ordre")
local page = f.pages.statistiques
local titres = {}
for _, bloc in ipairs(page.blocs) do titres[#titres + 1] = bloc.titre and bloc.titre:GetText() or "?" end
-- Les primaires sont en deux blocs : celles qui se lancent (Habilites) et
-- celles qui se lisent.
attendu("blocs", table.concat(titres, ", "),
    "GÉNÉRALE, HABILITÉS, STATISTIQUES, CARACTÉRISTIQUES, DÉPLACEMENT")
local generale = {}
for _, l in ipairs(page.blocs[1].lignes) do generale[#generale + 1] = l.field.id end
attendu("Generale", table.concat(generale, ","), "corps,armure,fatigue,pa")
-- La jauge d'armure portee existe toujours dans le schema : c'est la ligne de
-- la fiche qu'on a retiree le 3 octobre 2026, pas la mecanique.
attendu("le champ existe encore", LCM.Schema.Field("armure_portee") ~= nil, true)
local corps = page.blocs[1].lignes[1]
attendu("les PV seuls (les zones sont dans Sante)", #corps.zones, 0)
attendu("jauge des PV", corps.total.barre.label:GetText(), "42 / 42")
local habilites, stats = {}, {}
for _, l in ipairs(page.blocs[2].lignes) do habilites[#habilites + 1] = l.field.id end
for _, l in ipairs(page.blocs[3].lignes) do stats[#stats + 1] = l.field.id end
attendu("les deux qui se lancent", table.concat(habilites, ","), "adresse,esprit")
attendu("et les quatre qui se lisent", table.concat(stats, ","),
    "force,mystique,perception,constitution")

dire("== le survol d'une statistique reprend le style de la fiche")
local force = page.blocs[3].lignes[1]
LCM.UI.Fiche.Bulle(force, "Force", LCM.UI.Fiche.Decomposition(moi, force.field, 2, 0))
force:GetScript("OnEnter")(force)
local bulle = LCM.UI.Infobulle()
attendu("la bulle nomme la statistique", bulle.titre:GetText(), "Force")
-- Les points un par un, texte a gauche et valeur a droite, le total en
-- dernier (demande du 13 octobre 2026 : le total ouvrait la bulle).
attendu("la premiere ligne dit ce qui est investi", bulle.lignes[1]:GetText(), "Points investis")
attendu("sa valeur est a droite", bulle.droites[1]:GetText(), "2")
local derniere = bulle.nombreLignes
attendu("le total ferme la bulle", bulle.lignes[derniere]:GetText(), "Total")
attendu("avec sa valeur a droite", bulle.droites[derniere]:GetText() ~= nil, true)
attendu("un filet separe le total", bulle.filets[derniere - 1]:IsShown(), true)
-- Une source qui donne quelque chose se lit element par element.
local detail = LCM.UI.Fiche.Decomposition(moi, { id = "force" }, 0, 0)
for _, ligne in ipairs(detail) do
    attendu("une ligne par element : " .. ligne[1], ligne[1]:find(" · ", 1, true) ~= nil, true)
end
attendu("elle utilise le fond de l'interface", bulle.fond.__color[1], LCM.UI.C.fond[1])
attendu("elle est visible", bulle:IsShown(), true)
force:GetScript("OnLeave")(force)
attendu("elle disparait en quittant la ligne", bulle:IsShown(), false)
bulle:SetText("Court")
local largeurCourte = bulle:GetWidth()
bulle:SetText("Une longue infobulle partagee entre plusieurs survols")
attendu("une autre bulle peut s'elargir", bulle:GetWidth() > largeurCourte, true)
bulle:Hide()

dire("== rien ne traine a droite d'une ligne")
-- Le gabarit arrete sa derniere colonne a 762 unites sur 786 ; reportees
-- telles quelles, ces 24 unites laissaient une bande vide entre le dernier
-- bouton et le bord. Les colonnes de droite se calent donc sur le bord.
local L = LCM.Vues.Get("fiche").largeur - 24 - 2 * LCM.UI.Fiche.MARGE_BLOC
local col = LCM.UI.AelColonnes(L)
attendu("le dernier bouton finit au bord", col.boutons[3] + col.boutonL, L)
attendu("le bouton d'action aussi", col.action + col.actionLargeur, L)
attendu("et la jauge s'arrete juste avant les boutons", col.barreFin < col.boutons[1], true)

-- La plage (« 0-15 ») tient ENTRE le nom et la valeur, a toute largeur. Elle
-- etait calculee a reculons depuis la valeur, elle-meme ramenee contre le nom :
-- dans un volet etroit (Expertises) elle retombait DANS la colonne du nom et
-- « 15 » s'ecrivait par-dessus « Communication » (5 octobre 2026).
local plageMal = {}
for largeur = 320, 1600, 20 do
    local cc = LCM.UI.AelColonnes(largeur)
    local finNom = cc.nom + cc.nomLargeur
    if cc.plage < finNom or cc.plage + cc.plageLargeur > cc.valeur then
        plageMal[#plageMal + 1] = largeur
    end
end
attendu("la plage ne mord ni sur le nom ni sur la valeur", table.concat(plageMal, ","), "")

dire("== une icone n'ecrase pas son libelle")
-- `Fiche.Nom` a deux colonnes : avec icone et sans. Oublier de dire laquelle
-- pose le texte a l'interieur de l'icone — c'est arrive sur les trois types de
-- ligne a la fois le 1er octobre 2026.
local function nomApresIcone(ligne)
    if not ligne.icone then return true end
    local _, _, _, xIcone = ligne.icone:GetPoint(1)
    local _, _, _, xNom = ligne.nom:GetPoint(1)
    return (xNom or 0) >= (xIcone or 0) + (ligne.icone:GetWidth() or 0)
end
local chevauche, avecIcone = 0, 0
for _, bloc in ipairs(page.blocs) do
    for _, ligne in ipairs(bloc.lignes) do
        if ligne.icone and ligne.nom then
            avecIcone = avecIcone + 1
            if not nomApresIcone(ligne) then chevauche = chevauche + 1 end
        end
    end
end
attendu("des lignes portent une icone", avecIcone > 0, true)
attendu("aucun libelle sous son icone", chevauche, 0)
-- Le separateur tombe ENTRE l'icone et le nom, a toutes les largeurs : il
-- etait reste a la place du gabarit (72 unites) et coupait le nom en deux
-- (« Emp|lacement », 3 octobre 2026).
local separateurMal = {}
for _, largeur in ipairs({ 300, 420, 560, 786, 1000 }) do
    local cc = LCM.UI.AelColonnes(largeur)
    local finIcone = cc.icone + math.min(cc.iconeTaille, cc.ligne - 4) + 2
    if cc.separateur < finIcone or cc.separateur + 12 * cc.echelle > cc.nom then
        separateurMal[#separateurMal + 1] = largeur
    end
end
attendu("separateur entre icone et nom", table.concat(separateurMal, ","), "")
local sepDansNom = 0
for _, bloc in ipairs(page.blocs) do
    for _, ligne in ipairs(bloc.lignes) do
        if ligne.separateur and ligne.nom then
            local _, _, _, xSep = ligne.separateur:GetPoint(1)
            local _, _, _, xNom = ligne.nom:GetPoint(1)
            if xSep + ligne.separateur:GetWidth() > xNom then sepDansNom = sepDansNom + 1 end
        end
    end
end
attendu("aucun separateur sur un nom", sepDansNom, 0)
attendu("initiative", page.blocs[4].lignes[1].field.id, "initiative")
attendu("deplacement", #page.blocs[5].lignes, 2)

dire("== Facultes (formules du template)")
f.barre.boutons[2]:Click()
local fac = f.pages.facultes
attendu("bloc Physiques", fac.blocs[1].titre:GetText(), "PHYSIQUES")
local valeurs = {}
for _, l in ipairs(fac.lignes) do valeurs[l.field.id] = l.valeur:GetText() end
-- 5 + 5 x 4 = 25 ; 4/2 + 3/3 = 3 ; 4/2 + 3/4 = 2,75 -> 2
-- Les sauts sont ARRONDIS A L'INFERIEUR depuis le 4 octobre 2026 : « 2.75 m »
-- n'est pas une distance qu'on annonce a une table.
attendu("poids soulevable", valeurs.poids_soulevable, "25")
attendu("saut horizontal", valeurs.saut_horizontal, "3")
attendu("saut vertical arrondi a l'inferieur", valeurs.saut_vertical, "2")

dire("== Traits")
f.barre.boutons[3]:Click()
attendu("la liste des traits", f.pages.traits.lignes[1].field.id, "traits_portes")

dire("== ce qui depasse reste dans la fenetre")
f.barre.boutons[1]:Click()
local zone = f.zone
attendu("la zone rogne ce qui depasse", zone:DoesClipChildren(), true)
zone:SetHeight(300)
zone:Regler(page.hauteur)
attendu("la page est plus haute que la zone", page.hauteur > 300, true)
attendu("la barre apparait", zone.barre:IsShown(), true)
zone:GetScript("OnMouseWheel")(zone, -1)
attendu("la molette descend", zone.decalage > 0, true)
for _ = 1, 100 do zone:GetScript("OnMouseWheel")(zone, -1) end
attendu("sans depasser le bas", zone.decalage, zone.debord)
zone:Aller(-50)
attendu("ni le haut", zone.decalage, 0)
zone:Regler(100)
attendu("contenu court : pas de barre", zone.barre:IsShown(), false)

dire("== fermeture")
SlashCmdList.LCM("fiche")
attendu("la fenetre se referme", f:IsShown(), false)

dire("== la fiche ouverte suit les jauges en direct")
-- Une action qui coute des PA se voyait seulement apres avoir ferme et rouvert
-- la fiche : autant dire qu'elle ne s'affichait pas (3 octobre 2026).
SlashCmdList.LCM("fiche")
attendu("la fiche est ouverte", f:IsShown(), true)
local moi = LCM.Entities.Self()
local function texteJauge()
    for _, ligne in ipairs(f.pages[f.onglet].lignes) do
        if ligne.barre and ligne.nom and ligne.nom:GetText() == "PA" then
            return ligne.barre.label:GetText()
        end
    end
end
local avant = texteJauge()
attendu("les PA sont affiches", avant ~= nil, true)
local jauge = LCM.Entities.Gauge(moi, "pa")
LCM.Entities.SetGauge(moi, "pa", math.max(0, jauge.current - 1))
attendu("l'affichage a suivi sans rouvrir", texteJauge() ~= avant, true)
SlashCmdList.LCM("fiche")

dire("== une ligne de jet montre son total, dans sa colonne")
-- Le bloc elargit sa colonne de noms pour ne couper aucun libelle, puis epingle
-- la valeur au bord droit de la ligne. Sur une ligne de JET ce bord est pris par
-- le bouton : le total passait DESSOUS, et on lisait « +1 » (le bonus) a cote
-- d'un vide (5 octobre 2026).
local cible
LCM.Schema.EachField(function(champ)
    if champ.kind == "roll" and tostring(champ.label or "") == "Équilibre" then cible = champ end
end)
attendu("une expertise de reference", cible ~= nil, true)
LCM.Entities.Set_Value(moi, cible.id, 2)

local vue = LCM.UI.Vues.Fenetre("expertise")
vue:Montrer(moi)
vue:Afficher("athletisme")
local jet
for _, page in pairs(vue.pages or {}) do
    for _, bloc in ipairs(page.blocs or {}) do
        for _, ligne in ipairs(bloc.lignes or {}) do
            if ligne.field and ligne.field.id == cible.id then jet = ligne end
        end
    end
end
attendu("la ligne existe", jet ~= nil, true)

local attendu_total = (tonumber(LCM.Entities.Get_Value(moi, cible.id)) or 0)
    + LCM.Formules.Apport(moi, cible.id) + LCM.Effets.Bonus(moi, cible.id)
attendu("elle affiche le total", jet.valeur:GetText(), tostring(attendu_total))

-- Et chaque colonne reste a sa place : nom, plage, valeur, bonus, bouton.
local function x(region)
    local _, _, _, ax = region:GetPoint(1)
    return ax or 0
end
attendu("la plage vient apres le nom", x(jet.plage) > x(jet.nom) + jet.nom:GetWidth(), true)
attendu("la valeur vient apres la plage",
    x(jet.valeur) >= x(jet.plage) + jet.plage:GetWidth(), true)
attendu("le bonus vient apres la valeur",
    x(jet.bonus) >= x(jet.valeur) + jet.valeur:GetWidth(), true)
attendu("et le bouton ferme la marche",
    x(jet.lancer) >= x(jet.bonus) + jet.bonus:GetWidth(), true)

dire("== un jet d'expertise demande DD/NF et applique le resultat")
attendu("expertise configuree pour DD/NF", cible.jetExpertise, true)
jet.lancer:Click()
attendu("la saisie expertise s'ouvre", jet.saisieExpertise:IsShown(), true)
attendu("DD vide affiche son indication", jet.saisieExpertise.dd.indication:IsShown(), true)
attendu("NF vide affiche son indication", jet.saisieExpertise.nf.indication:IsShown(), true)
jet.saisieExpertise.lancer:Click()
attendu("DD est obligatoire", jet.saisieExpertise:IsShown(), true)

local ancienRandom = math.random
local jaugeFatigue = LCM.Entities.Gauge(moi, "fatigue")
local fatigueAvant = jaugeFatigue.current
math.random = function(minimum) return minimum end
local echec, erreur = LCM.Roll.ResoudreExpertise(moi, cible.id, 9999, 3)
attendu("DD trop eleve produit un echec", echec and echec.issue, "Échec")
attendu("NF est perdu en echec", echec and echec.perteFatigue, 3)
attendu("la fatigue est retiree", LCM.Entities.Gauge(moi, "fatigue").current, fatigueAvant - 3)

local jetMinimum = LCM.Roll.Field(moi, cible.id)
local ddPartiel = jetMinimum.total
local partiel = LCM.Roll.ResoudreExpertise(moi, cible.id, ddPartiel, 2)
attendu("egaliser DD est une reussite partielle", partiel and partiel.issue, "Réussite partielle")
attendu("NF est perdu en partiel", partiel and partiel.perteFatigue, 2)

math.random = function(_, maximum) return maximum end
local critique = LCM.Roll.ResoudreExpertise(moi, cible.id, 9999, 4)
attendu("le maximum du de est une reussite totale", critique and critique.issue, "Réussite totale")
attendu("le critique ne coute pas de fatigue", critique and critique.perteFatigue, 0)
math.random = ancienRandom
jet.saisieExpertise:Hide()
vue:Hide()

dire("== les jauges de ressource : les boutons sont au MJ")
-- PA, fatigue et boucliers etaient verrouilles pour TOUT LE MONDE. Le joueur
-- ne doit pas les fabriquer a la main ; le MJ, lui, en a besoin pour poser une
-- situation ou essayer une regle sans jouer une action entiere, comme il le
-- fait deja sur les zones du corps (11 octobre 2026).
f.barre.boutons[1]:Click()
local generale = f.pages.statistiques.blocs[1]
local function ligne(id)
    for _, l in ipairs(generale.lignes) do if l.field and l.field.id == id then return l end end
end
for _, id in ipairs({ "pa", "fatigue", "armure" }) do
    local l = ligne(id)
    attendu("la jauge " .. id .. " existe", l ~= nil, true)
    attendu("  elle a ses trois boutons", l and #(l.boutons or {}), 3)
    attendu("  et le MJ les voit", l and l.boutons[1]:IsShown(), true)
end

-- Vu du joueur. On passe par le mode joueur, le vrai levier : la presence du
-- compagnon ne suffit pas a le simuler, `LCM._masterCompanion` court-circuite.
LCM.BasculerModeJoueur(true)
local pa = ligne("pa")
local avantPA = LCM.Entities.Gauge(moi, "pa").current
pa:Actualiser(moi)
attendu("en mode joueur, plus un bouton", pa.boutons[1]:IsShown(), false)
pa.boutons[2]:Click()
attendu("  et le clic ne donne rien", LCM.Entities.Gauge(moi, "pa").current, avantPA)
attendu("  on lui dit pourquoi",
    __sansCouleur(__sorties[#__sorties]):find("maître du jeu") ~= nil, true)
LCM.BasculerModeJoueur(false)
pa:Actualiser(moi)
attendu("le MJ les retrouve", pa.boutons[1]:IsShown(), true)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
