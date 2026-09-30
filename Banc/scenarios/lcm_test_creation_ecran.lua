-- L'ecran de creation : pages, compteurs, refus visibles.
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

__declencher("PLAYER_LOGIN")

dire("== le bouton + du carrousel ouvre la creation")
local carrousel = LCM.UI.Personnages.Ouvrir()
carrousel.creer:Click()
local f = LCM.UI.Creation.frame
attendu("fenetre ouverte", f:IsShown(), true)
attendu("sept etapes", #f.barre.boutons, 7)
attendu("on demarre sur l'identite", f.etape, "identite")
attendu("brouillon neuf", f.brouillon.nom, "")

dire("== identite")
local identite = f.pages.identite
attendu("niveau de depart affiche", identite.niveau.valeur, 5)
attendu("une race proposee", #identite.races, 1)
attendu("nom du bouton de race", identite.races[1].label:GetText(), "Humain")
attendu("creation bloquee", f.valider:IsEnabled(), false)
attendu("et on dit pourquoi", f.probleme:GetText(), "il faut un nom.")

identite.nom:Saisir("Ysolde")
attendu("nom retenu", f.brouillon.nom, "Ysolde")
attendu("il manque encore la race", f.probleme:GetText(), "il faut choisir une race.")
identite.races[1]:Click()
attendu("race retenue", f.brouillon.race, "humain")
attendu("creation possible", f.valider:IsEnabled(), true)
attendu("plus rien a signaler", f.probleme:GetText(), "")

dire("== identite : age, sexe, poids")
identite.age:Saisir("28")
attendu("age retenu", f.brouillon.valeurs.age, 28)
identite.poids:Saisir("64")
attendu("poids retenu", f.brouillon.valeurs.poids, 64)
attendu("trois choix de sexe", #identite.sexes, 3)
identite.sexes[1]:Click()
attendu("sexe retenu", f.brouillon.valeurs.sexe, "Féminin")
attendu("marque dans le bouton", identite.sexes[1].__selectionne, true)

dire("== les onglets tiennent sur trois rangees")
attendu("trois par rangee", f.barre.boutons[4]:GetPoint(1) ~= nil, true)
local _, _, _, _, y1 = f.barre.boutons[1]:GetPoint(1)
local _, _, _, _, y4 = f.barre.boutons[4]:GetPoint(1)
attendu("le quatrieme passe a la ligne", y4 < y1, true)

dire("== statistiques primaires")
f.barre.boutons[2]:Click()
attendu("page affichee", f.etape, "primaires")
attendu("six lignes", #f.pages.primaires.compteurs, 6)
local force = compteur(f.pages.primaires, "force")
attendu("plafond lu du moteur", force.plafond, 9)
for _ = 1, 9 do force.plus:Click() end
attendu("neuf clics, neuf points", f.brouillon.valeurs.force, 9)
attendu("budget mis a jour", f.pages.primaires.entete.budget:GetText(), "23 / 32")
force.plus:Click()
attendu("le dixieme est refuse", f.brouillon.valeurs.force, 9)
attendu("et il est explique", dernierMessage():find("plafond") ~= nil, true)
force.moins:Click()
attendu("on peut redescendre", f.brouillon.valeurs.force, 8)

dire("== R, M et l'en-tete de groupe")
local page = f.pages.primaires
attendu("l'en-tete annonce le budget", page.entete.budget:GetText(), "24 / 32")
force.remise:Click()
attendu("R remet la ligne a zero", f.brouillon.valeurs.force, nil)
attendu("les points reviennent", page.entete.budget:GetText(), "32 / 32")
local adresse = compteur(page, "adresse")
attendu("plafond de l'adresse", adresse.plafond, 7)
adresse.maximum:Click()
attendu("M monte au plafond", LCM.Creation.Valeur(f.brouillon, "adresse"), 7)
attendu("et il a coute deux points le cran", LCM.Creation.Depense(f.brouillon, "primaires"), 14)
page.entete.remise:Click()
attendu("le R du groupe vide la categorie", LCM.Creation.Depense(f.brouillon, "primaires"), 0)
for _ = 1, 8 do force.plus:Click() end
attendu("huit points de force", LCM.Creation.Valeur(f.brouillon, "force"), 8)

dire("== coloration de l'investissement")
local mystique = compteur(page, "mystique")
local function couleur(c) local r = c.chiffre.__textColor return r and r[1] or -1 end
attendu("gris a zero", math.abs(couleur(mystique) - LCM.UI.C.discret[1]) < 0.01, true)
mystique.plus:Click()
attendu("dore des le premier point", math.abs(couleur(mystique) - LCM.UI.C.accent[1]) < 0.01, true)
force.maximum:Click()
attendu("rouge au plafond", math.abs(couleur(force) - LCM.UI.C.plein[1]) < 0.01, true)
-- On repose la force a 8 : la suite du scenario compte dessus.
page.entete.remise:Click()
for _ = 1, 8 do force.plus:Click() end
attendu("force reposee", LCM.Creation.Valeur(f.brouillon, "force"), 8)

dire("== les points secondaires affichent leur cout")
f.barre.boutons[3]:Click()
attendu("neuf pools", #f.pages.secondaires.compteurs, 9)
local pa = compteur(f.pages.secondaires, "sec_pa")
pa.plus:Click()
attendu("un point d'action pris", f.brouillon.valeurs.sec_pa, 1)
attendu("huit points depenses", LCM.Creation.Depense(f.brouillon, "secondaires"), 8)
attendu("budget affiche", f.pages.secondaires.entete.budget:GetText(), "24 / 32")

dire("== investir en Expertises agrandit le budget de l'etape suivante")
local sec = compteur(f.pages.secondaires, "sec_expertises")
for _ = 1, 3 do sec.plus:Click() end
f.barre.boutons[4]:Click()
attendu("page expertises", f.etape, "expertises")
attendu("25 expertises", #f.pages.expertises.compteurs, 25)
attendu("budget 18 + 3x2", f.pages.expertises.entete.budget:GetText(), "24 / 24")

dire("== penetrations et resistances, cote a cote")
f.barre.boutons[5]:Click()
attendu("30 lignes", #f.pages.types.compteurs, 30)
attendu("deux en-tetes de budget", f.pages.types.enteteDroite.label:GetText(), "RÉSISTANCES")
local tranchant = compteur(f.pages.types, "pen_tranchant")
-- force 8 → 8 / 1,75 = 4, plus la base de 3.
attendu("plafond suivant la force investie", tranchant.plafond, 7)
for _ = 1, 7 do tranchant.plus:Click() end
attendu("sept points poses", f.brouillon.valeurs.pen_tranchant, 7)

dire("== baisser la force fait apparaitre le debordement")
f.barre.boutons[2]:Click()
local force2 = compteur(f.pages.primaires, "force")
for _ = 1, 8 do force2.moins:Click() end
attendu("force a zero", LCM.Creation.Valeur(f.brouillon, "force"), 0)
attendu("la creation est bloquee", f.valider:IsEnabled(), false)
attendu("le debordement est nomme", f.probleme:GetText():find("Tranchant") ~= nil, true)
f.barre.boutons[5]:Click()
attendu("la ligne est marquee en rouge", compteur(f.pages.types, "pen_tranchant").valeur >
    compteur(f.pages.types, "pen_tranchant").plafond, true)

dire("== mecaniques")
f.barre.boutons[6]:Click()
attendu("page mecaniques", f.etape, "mecaniques")
attendu("21 lignes", #f.pages.mecaniques.compteurs, 21)
local soin = compteur(f.pages.mecaniques, "meca_soin")
attendu("plafond", soin.plafond, 10)
for _ = 1, 4 do soin.plus:Click() end
attendu("quatre points de soin", f.brouillon.valeurs.meca_soin, 4)
attendu("budget affiche", f.pages.mecaniques.entete.budget:GetText():find("/") ~= nil, true)

dire("== traits")
f.barre.boutons[7]:Click()
attendu("un trait propose", #f.pages.traits.traits, 1)
local trait = f.pages.traits.traits[1]
attendu("son cout est affiche", trait.nom:GetText():find("2 pts") ~= nil, true)
trait.bouton:Click()
attendu("pris", #f.brouillon.traits, 1)
attendu("le bouton propose de le retirer", trait.bouton.label:GetText(), "Retirer")
trait.bouton:Click()
attendu("retire", #f.brouillon.traits, 0)

dire("== le recapitulatif de gauche")
attendu("huit categories", #f.recap.entetes, 8)
attendu("Identite en premier", f.recap.entetes[1].label:GetText(), "- Identité")
attendu("son budget n'a pas de sens", f.recap.entetes[1].compte:GetText(), "")
attendu("Statistiques affiche le sien", f.recap.entetes[2].compte:GetText():find("/") ~= nil, true)
-- Replier / deplier.
f.recap.entetes[1]:Click()
attendu("replie", f.recap.entetes[1].label:GetText(), "+ Identité")
f.recap.entetes[1]:Click()
attendu("deplie", f.recap.entetes[1].label:GetText(), "- Identité")
local vus = {}
for _, l in ipairs(f.recap.lignes) do if l:IsShown() then vus[#vus + 1] = l.nom:GetText() .. "=" .. l.valeur:GetText() end end
dire("   " .. table.concat(vus, "  |  "))
local trouve = false
for _, v in ipairs(vus) do if v == "Nom=Ysolde" then trouve = true end end
attendu("le nom y figure", trouve, true)
attendu("la zone connait sa hauteur", f.defilement.hauteurContenu > 0, true)

dire("== tout remettre a zero, avec confirmation")
f.barre.boutons[2]:Click()
for _ = 1, 3 do compteur(f.pages.primaires, "force").plus:Click() end
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
f.barre.boutons[5]:Click()
local t = compteur(f.pages.types, "pen_tranchant")
for _ = 1, 7 do t.moins:Click() end
attendu("plus de debordement", #LCM.Creation.Debordements(f.brouillon), 0)
attendu("creation possible", f.valider:IsEnabled(), true)
f.valider:Click()
attendu("la fenetre se ferme", f:IsShown(), false)
attendu("le personnage existe", LCM.Personnages.Compte(), 1)
attendu("et il est joue", LCM.Entities.Self().name, "Ysolde")
attendu("sa fiche s'ouvre", LCM.UI.Fiche.frame:IsShown(), true)

dire("== rouvrir repart d'un brouillon neuf")
LCM.UI.Creation.Ouvrir()
attendu("nom vide", f.brouillon.nom, "")
attendu("aucune valeur", next(f.brouillon.valeurs), nil)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
