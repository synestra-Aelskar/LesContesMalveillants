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

dire("== le combat à la volée")
-- Personne d'autre a attendre que Nytherah : l'invitation part.
attendu("le bouton compte la scène", c.combat.label:GetText(), "Combat (2 PNJ)")
attendu("pas de Terminer avant", c.terminer:IsShown(), false)
c.combat:Click()
attendu("l'invitation part", LCM.Combat.invitation ~= nil, true)
attendu("  avec toute la scène", #LCM.Combat.invitation.pnj, 2)
attendu("  le bouton propose de lancer", c.combat.label:GetText(), "Lancer sans attendre (1)")
attendu("  et d'annuler", c.terminer.label:GetText(), "Annuler")
c.combat:Click()
attendu("lancé sans attendre", LCM.Combat.EnCours(), true)
attendu("  le bouton passe au tour suivant", c.combat.label:GetText(), "Tour suivant")
LCM.Combat.Terminer()
c:AfficherCombat()
attendu("fini : le bouton revient", c.combat.label:GetText(), "Combat (2 PNJ)")

dire("== revenir en étendu")
c:Hide()
P.Basculer()
attendu("rouvert en compact, comme laissé", c:IsShown(), true)
c.versEtendu:Click()
attendu("étendre rouvre le grand panneau", f:IsShown() and not c:IsShown(), true)
attendu("  sur la page Groupe", f.onglet, "joueurs")
attendu("  les colonnes reprennent leur largeur", groupe.colCatalogue:GetWidth(), 232)
attendu("  les titres reviennent", groupe.colCatalogue.titre:IsShown(), true)
attendu("  le bouton Chiffre aussi", groupe.regain.modes.exact:IsShown(), true)
attendu("  XP revient", groupe.xpBouton:IsShown(), true)
attendu("  la préférence est oubliée", LCM.db.panneauMJ, nil)
attendu("  la page est revenue dans la grande fenêtre", groupe:GetParent(), f.contenu)

for _, instance in ipairs(LCM.Incarnation.Liste(true)) do LCM.Incarnation.Oublier(instance.id) end
print(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
