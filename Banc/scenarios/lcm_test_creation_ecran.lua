-- L'ecran de creation, organise comme la Creation du template : sept onglets,
-- textes, grilles de repartition, refus visibles.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end
local function dernierMessage() return __sansCouleur(__sorties[#__sorties] or "") end
local function compteur(page, champ)
    for _, c in ipairs(page.compteurs) do if c.champ == champ then return c end end
end
local function budget(page, categorie)
    for _, b in ipairs(page.budgets) do if b.categorie == categorie then return b end end
end

__declencher("PLAYER_LOGIN")

dire("== le bouton + du carrousel ouvre la creation")
local carrousel = LCM.UI.Personnages.Ouvrir()
carrousel.creer:Click()
local f = LCM.UI.Creation.frame
attendu("fenetre ouverte", f:IsShown(), true)
local noms = {}
for _, b in ipairs(f.barre.boutons) do noms[#noms + 1] = b.label:GetText() end
attendu("les onglets du template", table.concat(noms, ", "),
    "Bienvenue, Générale, Statistiques, Expertises, Pénétrations, Résistances, Traits")
attendu("on demarre sur Bienvenue", f.etape, "bienvenue")
attendu("brouillon neuf", f.brouillon.nom, "")
attendu("les textes du template", f.pages.bienvenue.blocs[1].paragraphe:GetText():find("Syn ou Talyah") ~= nil, true)
local finRangee = 0
for _, b in ipairs(f.barre.boutons) do
    local _, _, _, x = b:GetPoint(1)
    finRangee = math.max(finRangee, (x or 0) + b:GetWidth())
end
attendu("aucun onglet ne deborde", finRangee <= f.barre:GetWidth() + 0.5, true)
attendu("les sept etapes sur une seule ligne", f.barre.rangees, 1)

dire("== une ligne de repartition tient dans sa colonne")
-- Le libelle, les boutons (R - chiffre + M) et le total doivent tenir dans la
-- largeur du compteur. Sinon le total deborde sur la colonne voisine et les
-- deux se chevauchent — c'est ce qui est arrive en resserrant la fenetre.
local function tientDansSaColonne(compteur)
    local pris = 6 + (compteur.label:GetWidth() or 0) + compteur.largeurBoutons
    if compteur.total and compteur.total:IsShown() then
        pris = pris + 8 + (compteur.total:GetWidth() or 0)
    end
    return pris <= (compteur:GetWidth() or 0) + 0.5
end

dire("== Generale : identite, race, niveau, points")
f.barre.boutons[2]:Click()
local g = f.pages.generale
attendu("niveau de depart affiche", g.niveau.valeur, 5)
attendu("et dans sa saisie", g.niveau.saisie:GetText(), "5")
-- La race est un emplacement (conteneur du template), vide au depart.
attendu("emplacement de race vide", g.race.nom:GetText(), "Emplacement")
attendu("creation bloquee", f.valider:IsEnabled(), false)
attendu("et on dit pourquoi", f.probleme:GetText(), "il faut un nom.")
g.nom:Saisir("Ysolde")
attendu("nom retenu", f.brouillon.nom, "Ysolde")
attendu("il manque encore la race", f.probleme:GetText(), "il faut choisir une race.")
-- On la glisse depuis le compendium : un trait est refuse, une race acceptee.
local Comp = LCM.UI.Compendium.Ouvrir("traits")
local ligne = Comp.rangees[1]
__souris.LeftButton = true
ligne:GetScript("OnDragStart")(ligne)
attendu("fantome affiche", LCM.UI.Glisser.fantome:IsShown(), true)
g.race.__survol = true
__souris.LeftButton = false
__avancer(0.05)
attendu("un trait est refuse", f.brouillon.race, "")
attendu("fantome range", LCM.UI.Glisser.fantome:IsShown(), false)
Comp:ChoisirCategorie("races")
ligne = Comp.rangees[1]
__souris.LeftButton = true
ligne:GetScript("OnDragStart")(ligne)
__souris.LeftButton = false
__avancer(0.05)
g.race.__survol = nil
attendu("race retenue", f.brouillon.race, "humain")
attendu("la case la montre", g.race.nom:GetText(), "Humain")
Comp:Hide()
-- Depuis le 3 octobre 2026, un nom et une race ne suffisent plus : tant qu'il
-- reste des points a placer, le bouton reste eteint, et il dit lequel.
attendu("creation refusee : des points trainent", f.valider:IsEnabled(), false)
attendu("et on dit pourquoi", f.probleme:GetText():find("il reste") ~= nil, true)
g.age:Saisir("28")
attendu("age retenu", f.brouillon.valeurs.age, 28)
g.poids:Saisir("64")
attendu("poids retenu", f.brouillon.valeurs.poids, 64)
g.sexes[1]:Click()
attendu("sexe retenu", f.brouillon.valeurs.sexe, "Féminin")
-- 17 + 3 x 5 ; 12 + 4 x 5 ; 8 + 2 x 5
attendu("points de statistiques", g.infos[1].valeur:GetText(), "32")
attendu("points secondaires", g.infos[2].valeur:GetText(), "32")
attendu("points d'expertises", g.infos[3].valeur:GetText(), "18")
-- Le niveau se saisit dans sa ligne ; une saisie illisible reste, en rouge,
-- et bloque la creation en disant pourquoi.
g.niveau.saisie:Saisir("0")
attendu("niveau 0 refuse", f.valider:IsEnabled(), false)
attendu("la raison", (f.probleme:GetText() or ""):find("1 au minimum") ~= nil, true)
attendu("la saisie reste", g.niveau.saisie:GetText(), "0")
attendu("en rouge", select(1, g.niveau.saisie:GetTextColor()), LCM.UI.C.plein[1])
g.niveau.saisie:Saisir("7")
attendu("niveau 7 retenu", f.brouillon.niveau, 7)
attendu("budget au niveau 7 (17 + 3 x 7)", g.infos[1].valeur:GetText(), "38")
g.niveau.saisie:Saisir("5")
attendu("toujours refusee tant qu'il reste des points", f.valider:IsEnabled(), false)

dire("== Generale : la tabulation passe d'un champ a l'autre")
local g = f.pages.generale
attendu("Nom mene a Age", g.nom.suivant == g.age, true)
attendu("Age mene a Poids", g.age.suivant == g.poids, true)
attendu("et Poids revient en arriere", g.poids.precedent == g.age, true)
g.nom:Tabuler()
attendu("le focus a suivi", _G.__focus == g.age, true)

dire("== Generale : « Autre » demande de preciser")
attendu("cache au depart", g.sexeAutre:IsShown(), false)
g.sexes[3]:Click()
attendu("choisi", f.brouillon.valeurs.sexe, "Autre")
attendu("le champ apparait", g.sexeAutre:IsShown(), true)
g.sexeAutre:Saisir("Indéterminé")
attendu("la precision est retenue", f.brouillon.sexeAutre, "Indéterminé")
g.sexes[1]:Click()
attendu("un autre choix le referme", g.sexeAutre:IsShown(), false)

dire("== Generale : le niveau est fixe pour les joueurs")
attendu("le MJ le saisit", g.niveau.saisie:IsShown(), true)
LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = false
f:Actualiser()
attendu("un joueur ne le saisit pas", g.niveau.saisie:IsShown(), false)
attendu("il le lit", g.niveau.lecture:IsShown(), true)
attendu("et c'est cinq", g.niveau.lecture:GetText(), "5")
LCM._masterCompanion = true
__addonsCharges["LesContesMalveillants_MJ"] = true
f:Actualiser()

dire("== Generale : la race se choisit, elle ne se tape pas")
-- La saisie libre a ete retiree le 3 octobre 2026 : une race tapee a la main
-- n'apportait ni bonus ni morphologie, et laissait croire le contraire.
attendu("plus de champ libre", g.raceLibre, nil)

dire("== Generale : choisir sa race dans le compendium")
local slot = f.pages.generale.race
local raceAvant = f.brouillon.race
attendu("le compendium a des races", #LCM.Races.list > 1, true)
slot:Click("LeftButton")
attendu("le menu s'ouvre", slot.menu:IsShown(), true)
slot.menu.onChoix(LCM.Races.list[2].id)
attendu("race choisie", f.brouillon.race, LCM.Races.list[2].id)
attendu("et la case la nomme", f.pages.generale.race.nom:GetText(), LCM.Races.list[2].label)
-- Une fois une race posee, on peut n'en vouloir aucune.
slot:Click("LeftButton")
slot.menu.onChoix("")
attendu("retiree", f.brouillon.race, "")
attendu("la case redevient un emplacement", f.pages.generale.race.nom:GetText(), "Emplacement")
slot.menu:Hide()
-- On remet celle que la suite du scenario attend.
f.brouillon.race = raceAvant
f:Actualiser()

dire("== Generale : choisir son artwork")
local portrait = f.pages.generale.portrait
attendu("la vignette est la", portrait ~= nil, true)
attendu("aucun au depart", portrait.nom:GetText(), "Aucun")
attendu("elle invite a choisir", portrait.aide:GetText(), "Cliquer pour choisir")
-- Sans choix, l'apercu montre le repli : on voit ce qu'on aura.
attendu("apercu : la silhouette",
    LCM.Portraits.Appliquer(portrait.art, { values = f.brouillon.valeurs }), "silhouette")
f.brouillon.valeurs.portrait = LCM.Portraits.list[1].id
f:Actualiser()
attendu("l'artwork choisi est nomme", portrait.nom:GetText(), LCM.Portraits.list[1].label)
attendu("et l'apercu le montre",
    LCM.Portraits.Appliquer(portrait.art, { values = f.brouillon.valeurs }), "portrait")
f.brouillon.valeurs.portrait = nil
f:Actualiser()
attendu("on peut n'en vouloir aucun", portrait.nom:GetText(), "Aucun")

dire("== Statistiques : primaires")
f.barre.boutons[3]:Click()
local st = f.pages.statistiques
attendu("page affichee", f.etape, "statistiques")
local force = compteur(st, "force")
attendu("plafond lu du moteur (5 + 4)", force.plafond, 9)
for _ = 1, 9 do force.plus:Click() end
attendu("neuf clics, neuf points", f.brouillon.valeurs.force, 9)
attendu("budget dans le titre du bloc", budget(st, "primaires").budget:GetText(), "23 / 32")
force.plus:Click()
attendu("le dixieme est refuse", f.brouillon.valeurs.force, 9)
attendu("et il est explique", dernierMessage():find("plafond") ~= nil, true)
force.moins:Click()
attendu("on peut redescendre", f.brouillon.valeurs.force, 8)
force.remise:Click()
attendu("R remet la ligne a zero", f.brouillon.valeurs.force, nil)
local adresse = compteur(st, "adresse")
attendu("plafond de l'adresse (5 + 2)", adresse.plafond, 7)
adresse.maximum:Click()
attendu("M monte au plafond", LCM.Creation.Valeur(f.brouillon, "adresse"), 7)
attendu("deux points le cran", LCM.Creation.Depense(f.brouillon, "primaires"), 14)
budget(st, "primaires").remise:Click()
attendu("le R du bloc vide la categorie", LCM.Creation.Depense(f.brouillon, "primaires"), 0)
for _ = 1, 8 do force.plus:Click() end

dire("== Statistiques : l'apercu suit la repartition")
local constitution = compteur(st, "constitution")
for _ = 1, 4 do constitution.plus:Click() end
-- PV : 2 + 7,5 + 0 + 4 x (2 + 4 x 0,25) = 21,5 -> 21 ; Fatigue : 15 + 10 + 0 + 8 + 1 = 34
attendu("points de vie", st.pv.valeur:GetText(), "21")
attendu("fatigue", st.fatigue.valeur:GetText(), "34")
for _ = 1, 4 do constitution.moins:Click() end

dire("== Statistiques : le total tient compte de la race")
local page = f.pages.statistiques
local function compteurDe(champ)
    for _, c in ipairs(page.compteurs) do if c.champ == champ then return c end end
end
-- Une race qui donne un bonus a une primaire : le total le montre, la valeur
-- investie ne bouge pas.
local forceC = compteurDe("force")
attendu("le total existe", forceC.total ~= nil, true)
local investi = LCM.Creation.Valeur(f.brouillon, "force")
attendu("sans bonus, total = investi", forceC.total:GetText(), tostring(investi))
attendu("le cout n'est plus ecrit sur la ligne", forceC.bonus, 0)
-- Le cout est passe en infobulle sur le « + ».
attendu("une infobulle sur le +", forceC.plus:GetScript("OnEnter") ~= nil, true)

dire("== Statistiques : secondaires et leur cout")
local pa = compteur(st, "sec_pa")
pa.plus:Click()
attendu("un point d'action pris", f.brouillon.valeurs.sec_pa, 1)
attendu("huit points depenses", LCM.Creation.Depense(f.brouillon, "secondaires"), 8)
attendu("budget secondaire", budget(st, "secondaires").budget:GetText(), "24 / 32")
local sec = compteur(st, "sec_expertises")
for _ = 1, 3 do sec.plus:Click() end
attendu("expertises : deux points le cran (template)", LCM.Creation.Depense(f.brouillon, "secondaires"), 14)

dire("== Statistiques : ce qu'un point secondaire rapporte")
-- A droite d'une ligne secondaire, on ne montre pas les points poses mais ce
-- qu'ils donnent : des PV, de la fatigue, des points a repartir ailleurs.
local sec = f.pages.statistiques
local function secDe(champ)
    for _, c in ipairs(sec.compteurs) do if c.champ == champ then return c end end
end
-- On note ce qui etait pose : la suite du scenario compte dessus.
local avantSec = {}
for _, champ in ipairs({ "sec_vitalite", "sec_deplacement", "sec_expertises" }) do
    avantSec[champ] = LCM.Creation.Valeur(f.brouillon, champ)
end
LCM.Creation.Definir(f.brouillon, "secondaires", "sec_vitalite", 3)
LCM.Creation.Definir(f.brouillon, "secondaires", "sec_deplacement", 2)
LCM.Creation.Definir(f.brouillon, "secondaires", "sec_expertises", 4)
f:Actualiser()
local function lire(champ) return __sansCouleur(secDe(champ).total:GetText()) end
attendu("vitalite : des PV", lire("sec_vitalite"):find("PV") ~= nil, true)
attendu("fatigue : de la fatigue", lire("sec_fatigue"):find("fatigue") ~= nil, true)
attendu("initiative", lire("sec_initiative"):find("init%.") ~= nil, true)
-- Quatre de base, plus ce qui a ete investi.
attendu("points d'action : quatre de base plus l'investi", lire("sec_pa"),
    string.format("%d PA", LCM.Equilibrage.pa.base + LCM.Creation.Valeur(f.brouillon, "sec_pa")))
-- Terrestre 8 + 2, Nage 5 + 2, Vol 0 + 2.
attendu("deplacement : les trois modes", lire("sec_deplacement"), "10 / 7 / 2")
attendu("et chacun dans sa couleur", secDe("sec_deplacement").total:GetText():find("|c") ~= nil, true)
attendu("expertises : des points a repartir",
    lire("sec_expertises"), string.format("%d pts", LCM.Creation.Total(f.brouillon, "expertises")))
attendu("mecanique aussi",
    lire("sec_mecanique"), string.format("%d pts", LCM.Creation.Total(f.brouillon, "mecaniques")))
attendu("penetration aussi",
    lire("sec_penetration"), string.format("%d pts", LCM.Creation.Total(f.brouillon, "penetration")))
-- On remet ce qu'on a trouve.
for champ, valeur in pairs(avantSec) do
    LCM.Creation.Definir(f.brouillon, "secondaires", champ, valeur)
end
f:Actualiser()

dire("== Expertises et mecaniques")
f.barre.boutons[4]:Click()
local ex = f.pages.expertises
attendu("page expertises", f.etape, "expertises")
local n = 0
for _, c in ipairs(ex.compteurs) do if c.categorie == "expertises" then n = n + 1 end end
attendu("25 expertises", n, 25)
attendu("budget 18 + 3 x 2", budget(ex, "expertises").budget:GetText(), "24 / 24")
local soin = compteur(ex, "meca_soin")
attendu("les mecaniques dans le meme onglet", soin ~= nil, true)
attendu("plafond d'une mecanique", soin.plafond, 10)
for _ = 1, 4 do soin.plus:Click() end
attendu("quatre points de soin", f.brouillon.valeurs.meca_soin, 4)
-- Deux colonnes : c'est la page la plus serree de la creation.
local deborde = 0
for _, c in ipairs(ex.compteurs) do
    if not tientDansSaColonne(c) then deborde = deborde + 1 end
end
attendu("aucune ligne ne deborde de sa colonne", deborde, 0)

dire("== Penetrations")
f.barre.boutons[5]:Click()
local pen = f.pages.penetrations
attendu("15 types", #pen.compteurs, 15)
local tranchant = compteur(pen, "pen_tranchant")
-- force 8 -> 8 / 1,75 = 4, plus la base de 3.
attendu("plafond suivant la force investie", tranchant.plafond, 7)
for _ = 1, 7 do tranchant.plus:Click() end
attendu("sept points poses", f.brouillon.valeurs.pen_tranchant, 7)

dire("== Resistances")
f.barre.boutons[6]:Click()
local res = f.pages.resistances
attendu("15 types", #res.compteurs, 15)
attendu("plafond 3 + Constitution / 0,25 (sans constitution)", compteur(res, "resi_feu").plafond, 3)

dire("== baisser la force fait apparaitre le debordement")
f.barre.boutons[3]:Click()
for _ = 1, 8 do compteur(st, "force").moins:Click() end
attendu("la creation est bloquee", f.valider:IsEnabled(), false)
attendu("le debordement est nomme", f.probleme:GetText():find("Tranchant") ~= nil, true)
f.barre.boutons[5]:Click()
attendu("la ligne est marquee", tranchant.valeur > tranchant.plafond, true)

dire("== Traits : des emplacements, pas de liste a prendre ou laisser")
f.barre.boutons[7]:Click()
local tr = f.pages.traits
attendu("traits totaux : 2 + 5/5", budget(tr, "traits").budget:GetText(), "3 / 3")
attendu("plus de liste de traits", tr.traits, nil)
attendu("une case libre", #tr.emplacements, 1)
attendu("vide : Emplacement", tr.emplacements[1].nom:GetText(), "Emplacement")
LCM.Creation.AjouterTrait(f.brouillon, LCM.Traits.list[1].id)
f:Actualiser()
attendu("un trait pris occupe une case", tr.emplacements[1].nom:GetText(), LCM.Traits.list[1].label)
attendu("et une case libre suit", tr.emplacements[2]:IsShown() and tr.emplacements[2].nom:GetText(), "Emplacement")
LCM.Creation.RetirerTrait(f.brouillon, LCM.Traits.list[1].id)
f:Actualiser()
attendu("retire : une seule case", tr.emplacements[2]:IsShown(), false)

dire("== Traits : chaque case se choisit comme la race")
-- Oubli signale par le binome le 3 octobre 2026 : les cases existaient, mais
-- rien ne permettait d'y mettre un trait.
local unPoint = {}
for _, t in ipairs(LCM.Traits.list) do
    if t.cout == 1 then unPoint[#unPoint + 1] = t end
end
attendu("le compendium a deux traits a 1 point", #unPoint >= 2, true)
local case1 = tr.emplacements[1]
case1:Click("LeftButton")
attendu("le menu s'ouvre", tr.menu:IsShown(), true)
tr.menu.onChoix(unPoint[1].id)
attendu("trait pris", f.brouillon.traits[1], unPoint[1].id)
attendu("la case le nomme", case1.nom:GetText(), unPoint[1].label)
attendu("une case libre suit", tr.emplacements[2]:IsShown() and tr.emplacements[2].nom:GetText(), "Emplacement")
-- Clic gauche sur une case prise : le trait est remplace, a la meme place.
case1:Click("LeftButton")
tr.menu.onChoix(unPoint[2].id)
attendu("remplace", f.brouillon.traits[1], unPoint[2].id)
attendu("sans doublon", #f.brouillon.traits, 1)
-- Un trait trop cher est refuse, et le refus est dit. Deux traits a 1 point
-- laissent 1 point sur 3 : un trait a 2 ne passe plus.
local cher
for _, t in ipairs(LCM.Traits.list) do
    if t.cout >= 2 then cher = t break end
end
attendu("le compendium a un trait a 2 points ou plus", cher ~= nil, true)
tr.emplacements[2]:Click("LeftButton")
tr.menu.onChoix(unPoint[1].id)
attendu("deuxieme trait pris", #f.brouillon.traits, 2)
local alertes = 0
local alerteAvant = LCM.Alerte
LCM.Alerte = function() alertes = alertes + 1 end
tr.emplacements[3]:Click("LeftButton")
tr.menu.onChoix(cher.id)
LCM.Alerte = alerteAvant
attendu("trop cher : refuse", #f.brouillon.traits, 2)
attendu("et le refus est dit", alertes, 1)
-- En remplacement, le point du trait remplace est rendu d'abord : 1 + 1
-- rendu = 2, le trait a 2 passe, a la place du premier.
case1:Click("LeftButton")
tr.menu.onChoix(cher.id)
attendu("remplace par plus cher", f.brouillon.traits[1], cher.id)
attendu("a sa place", f.brouillon.traits[2], unPoint[1].id)
-- Clic droit : retirer.
LCM.Creation.RetirerTrait(f.brouillon, unPoint[1].id)
f:Actualiser()
case1:Click("RightButton")
tr.menu.onChoix("retirer")
attendu("retire par clic droit", #f.brouillon.traits, 0)
attendu("la case redevient un emplacement", case1.nom:GetText(), "Emplacement")

dire("== la page defile quand elle depasse")
attendu("la zone rogne", f.zone:DoesClipChildren(), true)
f.barre.boutons[4]:Click()
attendu("la page expertises est longue", ex.hauteur > 400, true)
attendu("et la zone le sait", f.zone.hauteurContenu, ex.hauteur)

dire("== tout remettre a zero, avec confirmation")
f.barre.boutons[3]:Click()
for _ = 1, 3 do compteur(st, "force").plus:Click() end
attendu("des points depenses", LCM.Creation.Depense(f.brouillon, "primaires"), 3)
f.remiseTotale:Click()
attendu("on demande confirmation", f.confirmation:IsShown(), true)
attendu("rien n'a bouge", LCM.Creation.Depense(f.brouillon, "primaires"), 3)
f.confirmation.non:Click()
attendu("annuler ne touche a rien", LCM.Creation.Depense(f.brouillon, "primaires"), 3)
f.remiseTotale:Click()
f.confirmation.oui:Click()
attendu("confirme : tout est rendu", LCM.Creation.Depense(f.brouillon, "primaires"), 0)
attendu("le nom est conserve", f.brouillon.nom, "Ysolde")
attendu("la race aussi", f.brouillon.race, "humain")

dire("== creer le personnage")
attendu("plus de debordement", #LCM.Creation.Debordements(f.brouillon), 0)
-- Tant qu'il reste un point quelque part, non.
attendu("refusee avec des points en poche", f.valider:IsEnabled(), false)

local C2 = LCM.Creation
for _, categorie in ipairs(C2.CATEGORIES) do
    if categorie == "traits" then
        while C2.PeutEncoreDepenser(f.brouillon, "traits") do
            local pris = false
            for _, trait in ipairs(LCM.Traits.list) do
                if (trait.cout or 1) <= C2.Budget(f.brouillon, "traits").reste
                    and not C2.ATrait(f.brouillon, trait.id) then
                    C2.AjouterTrait(f.brouillon, trait.id) pris = true break
                end
            end
            if not pris then break end
        end
    else
        while C2.PeutEncoreDepenser(f.brouillon, categorie) do
            local pose = false
            for _, ligne in ipairs(C2.Lignes(categorie)) do
                local id = ligne.id or ligne
                if C2.Maximum(f.brouillon, categorie, id) > C2.Valeur(f.brouillon, id) then
                    C2.Definir(f.brouillon, categorie, id, C2.Maximum(f.brouillon, categorie, id))
                    pose = true break
                end
            end
            if not pose then break end
        end
    end
end
f:Actualiser()

dire("   la navigation d'une etape a l'autre")
f:Afficher(LCM.Creation.ETAPES[1].id)
attendu("sur la premiere, on ne recule pas", f.precedent:IsEnabled(), false)
attendu("et « Créer » ne s'y montre pas", f.valider:IsShown(), false)
attendu("c'est « Suivant » qui occupe la place", f.suivant:IsShown(), true)
-- Le 3 octobre 2026 : « Précédent » chevauchait son voisin (+8 au lieu d'un
-- ecart), et restait accroche a « Suivant » cache sur la derniere etape, sous
-- « Créer le personnage ».
local _, voisin, _, ecart = f.precedent:GetPoint(1)
attendu("Precedent s'accroche a Suivant", voisin == f.suivant, true)
attendu("avec un ecart, sans chevauchement", ecart < 0, true)
-- La rangee passe au-dessus du liseré et de l'equerre du coin.
local emprise = LCM.UI.AelEmprise(f)
local _, _, _, _, basSuivant = f.suivant:GetPoint(1)
attendu("l'habillage mange le bas de la fenetre", emprise.bas > 0, true)
attendu("Suivant passe au-dessus", f.insetBas + basSuivant >= emprise.bas, true)
f.suivant:Click()
attendu("une etape plus loin", f.etape, LCM.Creation.ETAPES[2].id)
f.precedent:Click()
attendu("et on revient", f.etape, LCM.Creation.ETAPES[1].id)
-- Jusqu'au bout : « Suivant » disparait, « Créer » apparait.
for _ = 1, #LCM.Creation.ETAPES do f.suivant:Click() end
attendu("arrive a la derniere", f.etape, LCM.Creation.ETAPES[#LCM.Creation.ETAPES].id)
attendu("on n'avance plus", f.suivant:IsShown(), false)
attendu("« Créer le personnage » est la", f.valider:IsShown(), true)
local _, voisinFin = f.precedent:GetPoint(1)
attendu("Precedent s'accroche alors a Creer", voisinFin == f.valider, true)
attendu("tout place : creation possible", f.valider:IsEnabled(), true)

dire("   les gestes qui defont sont a gauche, sous le recapitulatif")
local _, ancre = f.abandonner:GetPoint(1)
attendu("Abandonner est ancre au contenu", ancre == f.contenu, true)
attendu("et large comme le recapitulatif", f.abandonner:GetWidth(), f.recap:GetWidth())
local _, ancreRemise = f.remiseTotale:GetPoint(1)
attendu("la remise a zero est au-dessus", ancreRemise == f.abandonner, true)
f.valider:Click()
attendu("la fenetre se ferme", f:IsShown(), false)
attendu("le personnage existe", LCM.Personnages.Compte(), 1)
attendu("et il est joue", LCM.Entities.Self().name, "Ysolde")
attendu("sa fiche s'ouvre", LCM.UI.Fiche.frame:IsShown(), true)

dire("== rouvrir repart d'un brouillon neuf")
LCM.UI.Creation.Ouvrir()
attendu("nom vide", f.brouillon.nom, "")
attendu("aucune valeur", next(f.brouillon.valeurs), nil)
attendu("sur Bienvenue", f.etape, "bienvenue")

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
