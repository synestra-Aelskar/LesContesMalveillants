-- L'XP de metier depuis le Panel MJ (2 novembre 2026) : la fenetre
-- « Attribuer de l'expérience » donne de l'XP de personnage OU de metier, et
-- pour un metier en XP ou en NIVEAUX.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end
local function dernier() return __sansCouleur(__sorties[#__sorties] or "") end

__declencher("PLAYER_LOGIN")
__personnage()
local M = LCM.Metiers
local moi = LCM.Personnages and LCM.Personnages.Actif() or LCM.Entities.Self()
M.Gagner(moi, "mineur", -M.XP(moi, "mineur"))

dire("== le coeur : en XP, en niveaux")
local r = M.Donner(moi, "mineur", 0, 1)
attendu("un niveau depuis zero : Rose 1", r and r.apres.rang, 1)
attendu("  l'XP exacte du palier", M.XP(moi, "mineur"), M.XPPourNiveau(1))
M.Gagner(moi, "mineur", 3)
r = M.Donner(moi, "mineur", 0, 2)
-- L'XP deja gagnee dans le palier compte : on arrive au debut du palier vise.
attendu("deux niveaux de plus : rang 3", r and r.apres.rang, 3)
attendu("  au debut du palier vise", M.XP(moi, "mineur"), M.XPPourNiveau(3))
r = M.Donner(moi, "mineur", 5, 0)
attendu("en XP : +5", M.XP(moi, "mineur"), M.XPPourNiveau(3) + 5)
attendu("rien : refuse", (M.Donner(moi, "mineur", 0, 0)), nil)
attendu("métier inconnu : refuse", (M.Donner(moi, "inexistant", 5)), nil)
M.Gagner(moi, "mineur", M.XPPourNiveau(M.RangMax()))
attendu("maîtrisé : un niveau de plus est refusé", select(2, M.Donner(moi, "mineur", 0, 1)),
    "ce métier est déjà maîtrisé.")
M.Gagner(moi, "mineur", -M.XP(moi, "mineur"))

dire("== ce qui arrive chez le joueur")
-- Un gain ne vient que du groupe (meme regle que l'XP de personnage).
__groupe({ "Nytherah-Apertus" })
LCM.Reseau.Recevoir("Nytherah-Apertus", "1:1:1:xpm|i=mineur;n=1;r=la mine")
attendu("un niveau reçu : Rose 1", M.Palier(moi, "mineur").rang, 1)
attendu("  et on dit qui l'a donné", dernier():find("Nytherah", 1, true) ~= nil
    or __sansCouleur(__sorties[#__sorties - 1]):find("Nytherah", 1, true) ~= nil, true)
local avant = M.XP(moi, "mineur")
LCM.Reseau.Recevoir("Nytherah-Apertus", "1:1:1:xpm|i=mineur;m=7")
attendu("7 XP reçus", M.XP(moi, "mineur") - avant, 7)
M.Gagner(moi, "mineur", -M.XP(moi, "mineur"))

dire("== la fenêtre du Panel MJ")
__groupe({ "Nytherah-Apertus" })
local panneau = LCM.UI.PanneauMJ.Basculer()
panneau:Afficher()
local xp = panneau.pages.joueurs.xpPanneau
xp:Ouvrir()
attendu("par défaut : l'XP de personnage", xp.mode, "personnage")
attendu("  sans choix de métier", xp.metier:IsShown(), false)
xp.modeMetier:Click()
attendu("Métier : le choix du métier paraît", xp.metier:IsShown(), true)
attendu("  et l'unité", xp.uniteNiveaux:IsShown(), true)
attendu("  la colonne dit « Palier »", xp.enteteNiveau:GetText(), "Palier")
xp.metier:Definir("mineur")
xp.metier.choisir("mineur")
local maLigne, saLigne
for rang = 1, xp.nombre do
    local l = xp.lignes[rang]
    if tostring(l.joueur):find("Nytherah", 1, true) then saLigne = l else maLigne = l end
end
attendu("ma ligne montre le palier du métier", maLigne.niveau:GetText(), "Niveau 0")
xp.uniteNiveaux:Click()
attendu("en niveaux, le bouton le dit", xp.envoyer.label:GetText(), "Donner les niveaux")
xp.montant:Saisir("2")
maLigne.case:Click()
saLigne.case:Click()
local envoisAvant = #__envois
xp.envoyer:Click()
attendu("moi : deux niveaux, tout de suite", M.Palier(moi, "mineur").rang, 2)
attendu("lui : un message xpm part", __envois[#__envois] and
    __envois[#__envois].message:find("xpm", 1, true) ~= nil and #__envois > envoisAvant, true)
attendu("  qui porte les niveaux, pas l'XP", __envois[#__envois].message:find("n=2", 1, true) ~= nil, true)
attendu("l'envoi est annoncé", dernier():find("2 niveaux de Mineur", 1, true) ~= nil, true)
attendu("la fenêtre se ferme", xp:IsShown(), false)
xp:Ouvrir()
xp.modePersonnage:Click()
attendu("retour au personnage : plus d'unité", xp.uniteNiveaux:IsShown(), false)
attendu("  le bouton redevient « Attribuer l'XP »", xp.envoyer.label:GetText(), "Attribuer l'XP")
xp:Hide()
M.Gagner(moi, "mineur", -M.XP(moi, "mineur"))

print(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
