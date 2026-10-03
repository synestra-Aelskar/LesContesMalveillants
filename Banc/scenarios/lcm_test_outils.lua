-- Le Panel MJ refait (3 octobre 2026) : ses quatre onglets, et les outils
-- partages (annonces, compteurs, barres, notes) de Core/Outils.lua, du MJ
-- jusqu'a l'ecran du joueur.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end
local function dernierMessage() return __sansCouleur(__sorties[#__sorties] or "") end

__declencher("PLAYER_LOGIN")
__groupe({ "Nytherah-Apertus" })
local O = LCM.Outils

dire("== le panneau : quatre onglets")
local p = LCM.UI.PanneauMJ.Basculer()
attendu("ouvert sur Joueurs", p:IsShown() and p.onglet, "joueurs")
local ids = {}
for _, b in ipairs(p.barre.boutons) do ids[#ids + 1] = b.ongletId end
attendu("les onglets", table.concat(ids, ","), "joueurs,combat,contenu,outils")
local function onglet(id)
    for _, b in ipairs(p.barre.boutons) do if b.ongletId == id then b:Click() end end
    return p.pages[id]
end
local joueurs = p.pages.joueurs
attendu("une ligne par membre", joueurs.nombreAffiche, 1)
attendu("le motif n'est plus dans la liste",
    select(2, joueurs.raison:GetPoint(1)) == joueurs, true)
attendu("la ligne dit si l'addon est la", joueurs.lignes[1].detail:GetText():find("addon") ~= nil, true)
attendu("et que la fiche n'est pas consultee",
    joueurs.lignes[1].detail:GetText():find("pas encore consultée", 1, true) ~= nil, true)

dire("== PNJ & contenu")
local contenu = onglet("contenu")
attendu("seule la page Contenu se voit", contenu:IsShown() and not joueurs:IsShown(), true)
attendu("aucun PNJ en scene", contenu.nombreScene, 0)
attendu("et la page le dit", contenu.sceneVide:GetText():find("Incarner", 1, true) ~= nil, true)
LCM.Incarnation.Instancier(LCM.PNJ.list[1].id, "Garde")
contenu:Afficher()
attendu("un PNJ mis en scene apparait", contenu.nombreScene, 1)
attendu("sous son nom", contenu.lignesScene[1].nom:GetText(), "Garde")
contenu.boutons.atelier:Click()
attendu("l'Atelier s'ouvre", LCM.UI.Atelier.Fenetre():IsShown(), true)
LCM.UI.Atelier.Fenetre():Hide()

dire("== les outils : ce qui est refuse, et pourquoi")
local outils = onglet("outils")
attendu("rien de partage", outils.nombre, 0)
outils.libelle:Saisir("")
outils.creerCompteur:Click()
attendu("sans libelle : refuse", dernierMessage():find("libellé", 1, true) ~= nil, true)
attendu("et rien n'est cree", #O.Liste(), 0)
outils.libelle:Saisir("Rituel")
outils.valeur:Saisir("12")
outils.maximum:Saisir("10")
outils.creerBarre:Click()
attendu("une barre au-dessus de son maximum : refusee", dernierMessage():find("entre 0 et 10", 1, true) ~= nil, true)
attendu("la saisie reste pour corriger", outils.libelle:GetText(), "Rituel")
attendu("toujours rien", #O.Liste(), 0)

dire("== du MJ au joueur")
-- La boucle rend chaque envoi au MJ lui-meme, comme s'il venait de Nytherah :
-- on joue les deux bouts.
__reseauBoucle(true, "Nytherah-Apertus")
outils.valeur:Saisir("3")
outils.creerBarre:Click()
attendu("la barre est creee", #O.Liste(), 1)
attendu("elle se liste", outils.nombre, 1)
attendu("avec sa valeur", outils.lignes[1].valeur:GetText(), "3 / 10")
local recus = O.Recus()
attendu("elle arrive chez le joueur", #recus, 1)
attendu("avec son libelle", recus[1].libelle, "Rituel")
local W = LCM.UI.Outils.frame
attendu("la fenetre du joueur s'ouvre", W ~= nil and W:IsShown(), true)
attendu("elle dit de qui ca vient", W.titre:GetText(), "Outils de Nytherah")
attendu("la barre est remplie", W.lignes[1].barre.courant .. "/" .. W.lignes[1].barre.maximum, "3/10")
outils.lignes[1].plus:Click()
attendu("+1 se voit chez le MJ", outils.lignes[1].valeur:GetText(), "4 / 10")
attendu("et chez le joueur", W.lignes[1].barre.courant, 4)
for _ = 1, 7 do outils.lignes[1].plus:Click() end
attendu("une barre ne depasse pas son maximum", O.Liste()[1].valeur, 10)
attendu("et le refus est dit", dernierMessage():find("entre 0 et 10", 1, true) ~= nil, true)

outils.libelle:Saisir("Rounds")
outils.valeur:Saisir("0")
outils.creerCompteur:Click()
outils.libelle:Saisir("Indice")
outils.texte:SetText("Le pont s'effondre au troisième round.")
outils.creerNote:Click()
attendu("trois outils", #O.Liste(), 3)
attendu("trois chez le joueur", #O.Recus(), 3)
attendu("une note n'a pas de +1", outils.lignes[3].plus:IsShown(), false)
W.lignes[3]:Click()
local note = LCM.UI.Outils.note
attendu("la note se lit chez le joueur", note:IsShown() and note.texte:GetText(), "Le pont s'effondre au troisième round.")
attendu("aucun message au-dessus de 255 octets", __plusGrosEnvoi() <= 255, true)

dire("== l'annonce")
outils.annonce:Saisir("Le plafond tremble !")
outils.annoncer:Click()
local a = LCM.UI.Outils.annonce
attendu("elle s'affiche en grand", a ~= nil and a:IsShown() and a.texte:GetText(), "Le plafond tremble !")
attendu("avec qui l'envoie", a.qui:GetText(), "— Nytherah")
attendu("le champ se vide", outils.annonce:GetText(), "")
__avancer(7)
attendu("et elle s'efface", a:IsShown(), false)
outils.annoncer:Click()
attendu("une annonce vide est refusee", dernierMessage():find("vide", 1, true) ~= nil, true)

dire("== retirer")
outils.lignes[2].retirer:Click()
attendu("le compteur part chez le MJ", #O.Liste(), 2)
attendu("et chez le joueur", #O.Recus(), 2)
note:Show()
LCM.UI.Outils.note.lue = O.recus["Nytherah-Apertus#" .. O.Liste()[2].id]
outils.lignes[2].retirer:Click()
attendu("une note retiree se ferme chez le joueur", note:IsShown(), false)
outils.lignes[1].retirer:Click()
attendu("plus rien : la fenetre du joueur se ferme", W:IsShown(), false)

dire("== un joueur qui arrive rattrape le reste")
O.Creer("compteur", "Tension", 2)
for cle in pairs(O.recus) do O.recus[cle] = nil end
attendu("le joueur a tout perdu (rechargement)", #O.Recus(), 0)
O.Demander()
attendu("sa demande lui rend tout", #O.Recus(), 1)
__reseauBoucle(false)

dire("== un joueur ne cree rien")
LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = false
attendu("creer : refuse", (O.Creer("compteur", "Triche", 1)), nil)
attendu("annoncer : refuse", (O.Annoncer("Triche")), false)
LCM._masterCompanion = true
__addonsCharges["LesContesMalveillants_MJ"] = true

dire("== on n'ecoute que son groupe")
local avant = #O.Recus()
__groupe({})
LCM.Reseau.Recevoir("Inconnu-Apertus", "1:1:1:outil|id=o9;k=compteur;l=Faux;v=1")
attendu("un inconnu n'affiche rien", #O.Recus(), avant)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
