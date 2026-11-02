-- Le Panel MJ en version compacte, et la scene qui se remplit depuis le
-- panneau (2 novembre 2026).
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()
__groupe({ "Nytherah-Apertus" })
local P = LCM.UI.PanneauMJ
-- Un PNJ temoin : le catalogue de la campagne bouge a chaque seance.
LCM.PNJ.Add({ id = "pnj_compact_temoin", label = "Garde témoin" })
for _, instance in ipairs(LCM.Incarnation.Liste(true)) do LCM.Incarnation.Oublier(instance.id) end
LCM.db.panneauMJ = nil

dire("== la scene se remplit depuis le panneau")
local f = P.Basculer()
attendu("ouvert en étendu par défaut", f:IsShown(), true)
f:Onglet("pnj")
local scene = f.pages.pnj
local ligne
for _, l in ipairs(scene.lignesCatalogue) do
    if l:IsShown() and l.pnjId == "pnj_compact_temoin" then ligne = l end
end
attendu("le PNJ est au catalogue", ligne ~= nil, true)
ligne.ajouter:Click()
attendu("« + Scène » le met en jeu", #LCM.Incarnation.Liste(), 1)
attendu("  sans le jouer", LCM.Incarnation.Actuelle(), nil)
attendu("  la page le montre", scene.nombreScene, 1)
ligne.ajouter:Click()
attendu("deux fois : deux exemplaires", #LCM.Incarnation.Liste(), 2)
-- « Incarner » au catalogue fait JOUER le PNJ sans le mettre en scene : il
-- en ajoutait un exemplaire a chaque clic (le MJ, 2 novembre 2026). Seul
-- « + Scène » fait entrer.
ligne.incarner:Click()
local joue = LCM.Incarnation.Actuelle()
attendu("« Incarner » fait jouer le PNJ", joue ~= nil, true)
attendu("  hors scène", joue and joue.horsScene, true)
attendu("  la scène n'a pas bougé", scene.nombreScene, 2)
attendu("  le bandeau le dit", scene.bandeau:GetText():find("hors scène") ~= nil, true)
LCM.Incarnation.Relacher()
ligne.incarner:Click()
attendu("ré-incarner reprend le même exemplaire", LCM.Incarnation.Actuelle(), joue)
attendu("  sans en créer", #LCM.Incarnation.Liste(true), 3)
ligne.ajouter:Click()
attendu("« + Scène » en met un en scène", scene.nombreScene, 3)
attendu("  le bandeau le dit", scene.bandeau:GetText():find("Tu incarnes") ~= nil, true)
scene.relacher:Click()
attendu("reprendre sa place", LCM.Incarnation.Actuelle(), nil)
scene.lignesScene[1].prendre:Click()
attendu("« Prendre » sur une ligne de la scène", LCM.Incarnation.ActuelleId(), scene.lignesScene[1].instanceId)
LCM.Incarnation.Relacher()
scene.lignesScene[3].oublier:Click()
attendu("× retire de la scène", #LCM.Incarnation.Liste(), 2)
scene.recherche:Saisir("garde temoin")
local visibles = 0
for _, l in ipairs(scene.lignesCatalogue) do if l:IsShown() then visibles = visibles + 1 end end
attendu("la recherche ignore les accents", visibles, 1)
scene.recherche:Saisir("")

dire("== passer en compact")
f.versCompact:Click()
local c = P.compact
attendu("la fenêtre compacte s'ouvre", c:IsShown(), true)
attendu("  la grande se ferme", f:IsShown(), false)
attendu("  sur la scène, où l'on était", c.onglet, "pnj")
attendu("  la page Scène y est", scene:IsVisible(), true)
attendu("la préférence est retenue", LCM.db.panneauMJ and LCM.db.panneauMJ.compact, true)
c.barre.boutons[1]:Click()
local groupe = f.pages.joueurs
attendu("onglet Groupe", groupe:IsVisible(), true)
attendu("  les états y sont", f.pages.etats:IsVisible(), true)
-- « La plus petite possible » (le MJ, 2 novembre 2026) : 480 x 380, 150 de
-- catalogue. La premiere version faisait 720 x 540 et 196.
attendu("  la fenêtre est petite", c:GetWidth() .. "x" .. c:GetHeight(), "480x380")
attendu("  colonnes resserrées", groupe.colCatalogue:GetWidth(), 150)
attendu("  sans titres de colonne", groupe.colCatalogue.titre:IsShown(), false)
attendu("  pas de bouton Chiffre", groupe.regain.modes.exact:IsShown(), false)
attendu("  XP n'y est pas", groupe.xpBouton:IsShown(), false)
attendu("  le regain dit OK", groupe.regain.valider.label:GetText(), "OK")
attendu("  libellés courts", groupe.regain.cases.pv_internes.label:GetText(), "Internes")

dire("== poser à la pelle, en compact")
local def = { id = "etat_compact_temoin", label = "Etat compact", categorie = "etat", bonus = {} }
LCM.Etats.Add(def)
f.pages.etats:Afficher()
groupe.tousBouton:Click()
local moi = LCM.Entities.Personnage()
groupe.depot.glisserDepose({ categorie = "etats", element = def })
attendu("l'état est posé sur moi", LCM.Etats.Porte(moi, def.id), true)
attendu("et envoyé au joueur", __envois[#__envois].cible, "Nytherah-Apertus")

dire("== le regain, en compact")
groupe.lignes[2]:Click()
LCM.Entities.SetGauge(moi, "fatigue", 5, 40)
groupe:AfficherDetail()
attendu("valeur collée au nom", groupe.regain.valeurs.fatigue:GetText(), "5/40")
groupe.regain.cases.fatigue:Click()
groupe.regain.modes.max:Click()
groupe.regain.valider:Click()
attendu("OK applique le regain", LCM.Entities.Gauge(moi, "fatigue").current, 40)
-- Cliquer dans le champ, c'est choisir « Chiffre » : un geste, pas deux.
groupe.regain.montant:SetFocus()
attendu("le champ choisit le chiffre", groupe.regain.mode, "exact")
groupe.regain.montant:SetText("-7")
groupe.regain.valider:Click()
attendu("  et le chiffre s'applique", LCM.Entities.Gauge(moi, "fatigue").current, 33)
groupe.regain.montant:ClearFocus()

dire("== le combat depuis la fenêtre compacte")
-- Depuis le 2 novembre 2026 (le MJ) : le bouton OUVRE la page Combat ; on y
-- choisit les PNJ ET les joueurs invites, on lance quand tout le monde est
-- pret ; pendant le combat, il devient « Fin de combat ». Avant, il invitait
-- d'un clic tout le groupe et toute la scene.
attendu("le bouton dit Combat", c.combat.label:GetText(), "Combat")
c.combat:Click()
attendu("il ouvre la page Combat", c.onglet == "combat" and f.pages.combat:IsVisible(), true)
attendu("  sans rien lancer", LCM.Combat.invitation, nil)
local pageCombat = LCM.UI.CombatMJ.frame
-- La colonne fait 220 ; depuis la refonte visuelle (2 novembre 2026), la
-- liste vit DANS un cadre encadre et laisse 18 a sa barre de defilement.
attendu("  resserrée pour la petite fenêtre", pageCombat.colGauche:GetWidth(), 220)
attendu("  la liste dans son cadre", pageCombat.zonePNJ:GetWidth(), 202)
-- A gauche les joueurs du groupe, a droite les PNJ de la scene (le MJ,
-- 2 novembre 2026).
local ligneJoueur, lignesPnj = nil, {}
for _, l in ipairs(pageCombat.lignesPNJ) do
    if l:IsShown() and l.invite then ligneJoueur = l end
end
for _, l in ipairs(pageCombat.lignesListe) do
    if l:IsShown() and l.pnjId then lignesPnj[#lignesPnj + 1] = l end
end
attendu("à gauche, les joueurs", pageCombat.titreQui:GetText(), "Joueurs du groupe")
attendu("à droite, les PNJ de la scène", pageCombat.titreListe:GetText(), "PNJ en scène")
attendu("  les deux PNJ y sont", #lignesPnj, 2)
attendu("le joueur du groupe est proposé", ligneJoueur and ligneJoueur.cle, "Nytherah-Apertus")
attendu("  invité par défaut", ligneJoueur and ligneJoueur.case:EstCochee(), true)
ligneJoueur.case:Click()
for _, l in ipairs(lignesPnj) do l.case:Click() end
pageCombat.lancer:Click()
-- Decoche, le seul joueur n'est pas invite : personne a attendre, le combat
-- part tout de suite (regle de Combat.Inviter), avec les PNJ coches.
attendu("décoché : il n'est pas invité, le combat part", LCM.Combat.EnCours(), true)
local nPnj = 0
for _, e in ipairs(LCM.Combat.Etat().entrees) do if e.pnj then nPnj = nPnj + 1 end end
attendu("  avec les PNJ cochés", nPnj, 2)
local absent = true
for _, e in ipairs(LCM.Combat.Etat().entrees) do if e.id == "Nytherah-Apertus" then absent = false end end
attendu("  et sans le joueur décoché", absent, true)
LCM.Combat.Terminer()
pageCombat:Afficher()
ligneJoueur.case:Click()
pageCombat.lancer:Click()
attendu("recoché : il est invité", LCM.Combat.invitation.cibles["Nytherah-Apertus"], true)
c:AfficherCombat()
attendu("  le bouton le dit", c.combat.label:GetText(), "Combat (invitation)")
pageCombat.forcer:Click()
attendu("lancé quand on le décide", LCM.Combat.EnCours(), true)
c:AfficherCombat()
attendu("  le bouton reste Combat", c.combat.label:GetText(), "Combat")
attendu("  en rouge", c.combat.alerte:IsShown(), true)
c:Onglet("joueurs")
c.combat:Click()
attendu("un clic ramène à la vue Combat", c.onglet, "combat")
attendu("  sans rien terminer", LCM.Combat.EnCours(), true)
-- Le fil suit en compact : la page ne se redessinait que si le GRAND panneau
-- etait ouvert, et restait figee au round d'avant (le MJ, 2 novembre 2026).
-- On avance d'un round entier, puis on revient : aucun Afficher a la main.
local E = LCM.Combat.Etat()
local avantNom = pageCombat.bandeau:GetText()
for _ = 1, #E.entrees do pageCombat.suivant:Click() end
attendu("le fil suit en compact : round 2", LCM.Combat.Etat().r .. "/" .. tostring(pageCombat.pastilles[2]:IsShown()), "2/true")
pageCombat.precedent:Click()
attendu("  retour au round 1, et la page le montre", pageCombat.lignesListe[#E.entrees].marque:IsShown(), true)
attendu("  le bandeau nomme celui qui joue",
    pageCombat.bandeau:GetText():find(tostring(LCM.Combat.Courant().nom), 1, true) ~= nil, true)
for _ = 1, #E.entrees - 1 do pageCombat.precedent:Click() end
attendu("  revenu au début : le bandeau d'avant", pageCombat.bandeau:GetText(), avantNom)
attendu("Terminer est dans la page, même en compact", pageCombat.terminer:IsShown(), true)
pageCombat.terminer:Click()
-- IsVisible, pas IsShown : la question etait « montree » sur le grand panneau
-- cache, donc invisible en compact, et le test passait quand meme (le MJ,
-- 2 novembre 2026 : « Terminer ne fait rien »).
attendu("  qui se confirme, A L'ECRAN", pageCombat.confirmer:IsVisible(), true)
pageCombat.confirmer.oui:Click()
c:AfficherCombat()
attendu("fini : le bouton revient", c.combat.label:GetText(), "Combat")
attendu("  sans le rouge", c.combat.alerte:IsShown(), false)
attendu("  et le combat est terminé", LCM.Combat.EnCours(), false)

dire("== revenir en étendu")
c:Hide()
P.Basculer()
attendu("rouvert en compact, comme laissé", c:IsShown(), true)
c.versEtendu:Click()
attendu("étendre rouvre le grand panneau", f:IsShown() and not c:IsShown(), true)
-- On etait sur la vue Combat : le grand panneau rouvre sur la meme page.
attendu("  sur la même page (Combat)", f.onglet, "combat")
attendu("  les colonnes reprennent leur largeur", groupe.colCatalogue:GetWidth(), 232)
attendu("  les titres reviennent", groupe.colCatalogue.titre:IsShown(), true)
attendu("  le bouton Chiffre aussi", groupe.regain.modes.exact:IsShown(), true)
attendu("  XP revient", groupe.xpBouton:IsShown(), true)
attendu("  la préférence est oubliée", LCM.db.panneauMJ, nil)
attendu("  la page est revenue dans la grande fenêtre", groupe:GetParent(), f.contenu)

for _, instance in ipairs(LCM.Incarnation.Liste(true)) do LCM.Incarnation.Oublier(instance.id) end
print(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
