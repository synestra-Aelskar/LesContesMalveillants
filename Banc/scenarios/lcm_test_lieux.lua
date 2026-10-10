-- Les Lieux : nommer les endroits, et le dire quand on y entre (10 octobre 2026).
--
-- Reprise de l'idee du module Zone Gate d'Omega Hub, avec trois ecarts qu'on
-- verifie ici parce que ce sont eux qui peuvent casser :
--   * une porte se pose avec DEUX BORNES, pas avec l'orientation du
--     personnage — elle est donc inerte tant que la seconde manque ;
--   * la position passe par le DEPLACEMENT FORCE, qui a trois sources qui ne
--     comptent pas dans la meme unite : un seuil ne se mesure qu'avec celle
--     qui l'a capture ;
--   * le nom se DECOUVRE en entrant, sauf si le MJ a coupe la decouverte.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()
LCM.db.settings.modeJoueur = nil
LCM._masterCompanion = true

local L = LCM.Lieux

-- Les bannieres, interceptees : c'est le seul effet visible d'un
-- franchissement, et on veut savoir LEQUEL s'est produit.
local vues = {}
L.onFranchir = function(titre, sous, lieu, seuil, sens)
    vues[#vues + 1] = { titre = titre, sous = sous, sens = sens, seuil = seuil.id }
end
local function derniere() return vues[#vues] end
local function vider() for i = #vues, 1, -1 do vues[i] = nil end end

-- Un battement sur place : le premier note le cote sans rien annoncer, les
-- suivants comparent.
local function allerA(x, y)
    __position(x, y, 0)
    L.Tick()
end

-- Repartir d'un cote connu, sans rien annoncer : on rearme, on se place, on
-- bat une fois. Sans ca chaque bloc heriterait du cote ou le precedent s'est
-- arrete, et son simple deplacement de mise en place franchirait le seuil.
local function depuis(x, y)
    L.Rearmer()
    __position(x, y, 0)
    L.Tick()
    vider()
end

dire("== un lieu se cree, et il se decouvre en entrant par defaut")
__position(0, 0, 0)
local lieu = L.Creer("Les Marches Grises")
attendu("le lieu existe", lieu ~= nil, true)
attendu("il porte mon nom", lieu.auteur, "Reika-Apertus")
attendu("et il se decouvre tout seul", lieu.decouverte, true)
attendu("aucun seuil pour l'instant", #L.Seuils(lieu.id), 0)
attendu("un lieu sans nom n'est pas sans nom", L.Creer("").nom, "Lieu sans nom")

dire("== une porte sans sa seconde borne est INERTE")
-- C'est tout l'ecart avec Zone Gate : la largeur d'un passage ne se devine
-- pas, elle se marche.
local porte = L.CreerSeuil(lieu.id, "Porte du Nord", "porte")
attendu("le seuil est pose ici", porte ~= nil, true)
attendu("il a pris la carte", porte.carte, 1)
attendu("et la source du monde", porte.source, "monde")
local complet, manque = L.Complet(porte)
attendu("incomplet", complet, false)
attendu("et il dit quoi", manque, "il manque la seconde borne.")
attendu("rien a battre", L.Regler(), false)
-- Traverser une porte inachevee ne doit RIEN produire.
allerA(5, 5)
allerA(-5, 5)
attendu("aucune banniere", #vues, 0)

dire("== la seconde borne fait la porte")
__position(0, 0, 0)
attendu("les bornes au meme endroit : refus", (L.PoserBorne(porte.id)), false)
__position(0, 10, 0)
attendu("borne posee dix metres plus loin", L.PoserBorne(porte.id), true)
attendu("complete", L.Complet(porte), true)
attendu("il y a de quoi battre", L.Regler(), true)

dire("== on la franchit, dans un sens puis dans l'autre")
L.Rearmer()
vider()
allerA(5, 5)
attendu("le premier battement ne dit rien", #vues, 0)
allerA(-5, 5)
attendu("une banniere", #vues, 1)
attendu("on entre", derniere().sens, "entree")
attendu("le lieu est nomme", derniere().titre, "Les Marches Grises")
attendu("et le seuil aussi", derniere().sous, "Porte du Nord")
allerA(5, 5)
attendu("deux bannieres", #vues, 2)
attendu("on sort", derniere().sens, "retour")

dire("== l'horloge bat d'elle-meme")
-- Partout ailleurs on appelle Tick a la main : ca ne prouve ni que le cadre
-- OnUpdate est branche, ni que l'intervalle s'accumule.
depuis(5, 5)
__position(-5, 5, 0)
__avancer(0.4)
attendu("le battement vient sans qu'on l'appelle", #vues >= 1, true)

dire("== on ne franchit pas une porte en la contournant")
-- Trente metres au-dela des bornes, on est hors de l'emprise du passage : le
-- cote ne compte meme pas, et l'etat se rearme.
depuis(5, 5)
allerA(-5, 40)
attendu("rien annonce", #vues, 0)
attendu("l'etat est rearme", L.etats[porte.id], nil)
-- Et en revenant dans l'emprise, le premier battement ne declenche pas.
allerA(-5, 5)
attendu("toujours rien", #vues, 0)

dire("== se tenir PILE sur le seuil ne fait pas clignoter")
depuis(5, 5)
allerA(0.4, 5)
attendu("dans la bande morte : rien", #vues, 0)
attendu("et rearme", L.etats[porte.id], nil)

dire("== inverser le sens echange entree et retour")
attendu("sens inverse", L.Inverser(porte.id), true)
depuis(5, 5)
allerA(-5, 5)
attendu("une banniere", #vues, 1)
attendu("le meme passage se lit a l'envers", derniere().sens, "retour")
L.Inverser(porte.id)

dire("== la banniere se coupe par sens")
L.Sens(porte.id, "retour", false)
depuis(5, 5)
allerA(-5, 5)
attendu("on entre : banniere", #vues, 1)
allerA(5, 5)
attendu("on sort : rien", #vues, 1)
L.Sens(porte.id, "retour", true)

dire("== un seuil eteint ne declenche plus")
L.Activer(porte.id, false)
depuis(5, 5)
allerA(-5, 5)
attendu("rien", #vues, 0)
L.Activer(porte.id, true)

dire("== le message du franchissement est local")
L.Message(porte.id, "Le vent tombe d'un coup.")
depuis(5, 5)
local avant, avantEnvois = #__sorties, #__envois
allerA(-5, 5)
local trouve = false
for i = avant + 1, #__sorties do
    if tostring(__sorties[i]):find("Le vent tombe", 1, true) then trouve = true end
end
attendu("il s'imprime dans le chat", trouve, true)
-- Le TEXTE voyage avec le seuil — c'est le client de celui qui franchit qui
-- l'imprime. Ce qui ne doit rien envoyer, c'est le franchissement lui-meme.
attendu("et franchir n'envoie rien", #__envois, avantEnvois)
L.Message(porte.id, "")

dire("== une autre carte ne repond pas")
depuis(5, 5)
__carte(2, 1000, 1000)
allerA(-5, 5)
attendu("rien : le seuil est sur la carte 1", #vues, 0)
__carte(1, 1000, 1000)

dire("== une autre source de position ne repond pas non plus")
-- Melanger des yards du monde et des yards de carte ferait franchir une porte
-- sans bouger. Le seuil retient sa source, et sans elle il se tait.
depuis(5, 5)
__positionMonde(false)
allerA(-5, 5)
attendu("rien : la porte a ete posee « monde »", #vues, 0)
attendu("et on ne peut pas y poser de borne", (L.PoserBorne(porte.id)), false)
__positionMonde(true)

dire("== le cercle : un village")
__position(0, 0, 0)
local cercle = L.CreerSeuil(lieu.id, "Le Hameau", "cercle")
attendu("rayon par defaut", cercle.rayon, 12)
attendu("un rayon nul : refus", (L.Rayon(cercle.id, 0)), false)
attendu("rayon a dix", L.Rayon(cercle.id, 10), true)
depuis(40, 0)
allerA(0, 0)
attendu("on entre dans le hameau", #vues, 1)
attendu("c'est bien une entree", derniere().sens, "entree")
allerA(40, 0)
attendu("et on en sort", derniere().sens, "retour")
L.RetirerSeuil(cercle.id)

dire("== la region : un contour a plusieurs points")
__position(0, 0, 0)
local region = L.CreerSeuil(lieu.id, "Le Sous-Bois", "region")
attendu("elle part d'ici", #region.points, 1)
attendu("ouverte, elle est incomplete", (L.Complet(region)), false)
attendu("et on ne peut pas la fermer a un point", (L.Fermer(region.id)), false)
__position(20, 0, 0)
L.AjouterPoint(region.id)
__position(20, 20, 0)
L.AjouterPoint(region.id)
__position(0, 20, 0)
L.AjouterPoint(region.id)
attendu("quatre points", #region.points, 4)
attendu("fermee", L.Fermer(region.id), true)
attendu("complete", L.Complet(region), true)
depuis(60, 10)
allerA(10, 10)
attendu("on entre dans le sous-bois", #vues, 1)
attendu("le centre est au milieu", string.format("%d,%d", region.x, region.y), "10,10")
-- Retirer un point rouvre le contour : il faut revalider.
attendu("un point retire", L.RetirerPoint(region.id), true)
attendu("le contour est rouvert", region.ferme, false)
depuis(60, 10)
allerA(10, 10)
attendu("une region ouverte est inerte", #vues, 0)
L.RetirerSeuil(region.id)

dire("== ce qui n'est pas a moi se lit, ne se modifie pas")
-- On rejoue le lieu tel qu'il est PARTI sur le reseau : c'est le seul moyen de
-- verifier que l'aller-retour ne casse rien. Le decodeur rend tout en texte, et
-- un nombre relu sans tonumber ne retrouverait jamais sa carte.
__groupe({ "Autre-Apertus" })
local depart = #__envois
L.Diffuser(lieu.id)
__avancer(2)
local messages = {}
for i = depart + 1, #__envois do messages[#messages + 1] = __envois[i].message end
attendu("le lieu est parti", #messages > 0, true)

local idLieu, idPorte = lieu.id, porte.id
LCM.db.lieux = {}
for _, message in ipairs(messages) do LCM.Reseau.Recevoir("Autre-Apertus", message) end
local recu = L.Get(idLieu)
attendu("le lieu est revenu", recu ~= nil, true)
attendu("il est a l'autre", recu.auteur, "Autre-Apertus")
attendu("son nom a traverse", recu.nom, "Les Marches Grises")
local recuPorte = L.Seuil(idPorte)
attendu("sa porte aussi", recuPorte ~= nil, true)
attendu("la carte est un NOMBRE", type(recuPorte.carte), "number")
attendu("et c'est la bonne", recuPorte.carte, 1)
attendu("la source a traverse", recuPorte.source, "monde")
attendu("les bornes aussi", string.format("%d,%d", recuPorte.bx, recuPorte.by), "0,10")
attendu("et elle est complete", L.Complet(recuPorte), true)
attendu("renommer est refuse", (L.Renommer(idLieu, "Chez moi")), false)
attendu("retirer aussi", (L.Retirer(idLieu)), false)

dire("== un nom inconnu se lit masque, en gardant sa silhouette")
-- Les deux noms ont ete appris plus haut, quand le lieu etait encore le mien
-- (son auteur voit toujours tout). On les oublie pour se mettre a la place du
-- joueur qui le decouvre.
L.Oublier(idLieu, idPorte)
attendu("masque", L.Masquer("Porte du Nord"), "????? ?? ????")
attendu("un accent reste UN caractere", L.Masquer("Gué"), "???")
local titre, sous = L.Titre(recuPorte, recu)
attendu("le lieu est inconnu", titre, "Lieu inconnu")
attendu("le seuil est masque", sous, "????? ?? ????")

dire("== on l'apprend en entrant")
depuis(5, 5)
allerA(-5, 5)
attendu("une banniere", #vues, 1)
attendu("elle nomme le lieu", derniere().titre, "Les Marches Grises")
attendu("et le seuil", derniere().sous, "Porte du Nord")
titre, sous = L.Titre(recuPorte, recu)
attendu("c'est retenu", titre, "Les Marches Grises")

dire("== un lieu dont la decouverte est coupee reste cache")
L.Oublier(idLieu, idPorte)
recu.decouverte = false
depuis(5, 5)
allerA(-5, 5)
attendu("la banniere vient quand meme", #vues, 1)
attendu("mais elle ne dit rien", derniere().titre, "Lieu inconnu")
attendu("ni du seuil", derniere().sous, "????? ?? ????")
titre = L.Titre(recuPorte, recu)
attendu("et rien n'a ete appris", titre, "Lieu inconnu")
-- Le MJ le revele a la main : c'est la seule autre porte d'entree.
L.Apprendre(idLieu, idPorte)
titre, sous = L.Titre(recuPorte, recu)
attendu("revele, on lit le lieu", titre, "Les Marches Grises")
attendu("et le seuil", sous, "Porte du Nord")

dire("== un lieu recu n'ecrase jamais un lieu qui est a moi")
LCM.db.lieux = {}
local mien = L.Creer("Les Marches Grises")
-- On lui renvoie un lieu du MEME identifiant, venu d'ailleurs.
LCM.db.lieux[mien.id] = nil
mien.id = idLieu
LCM.db.lieux[idLieu] = mien
for _, message in ipairs(messages) do LCM.Reseau.Recevoir("Autre-Apertus", message) end
attendu("c'est toujours le mien", L.Get(idLieu).auteur, "Reika-Apertus")
attendu("et il n'a pas pris ses seuils", #L.Seuils(idLieu), 0)

dire("== l'atelier du MJ s'ouvre et montre l'arbre")
local atelier = LCM.UI.LieuxMJ.Fenetre()
atelier:Montrer()
attendu("ouvert", atelier:IsShown(), true)
local textes = table.concat(__textes(atelier), " | ")
attendu("le lieu est dans l'arbre", textes:find("Les Marches Grises", 1, true) ~= nil, true)
LCM.UI.LieuxMJ.lieu = idLieu
LCM.UI.LieuxMJ.seuil = nil
atelier:Afficher()
textes = table.concat(__textes(atelier), " | ")
attendu("la ligne d'etat dit la carte", textes:find("Carte 1", 1, true) ~= nil, true)
atelier:Hide()

dire("== on passe d'une forme a l'autre en cliquant, et le radar suit")
-- C'est le geste qui a casse en jeu : l'atelier doit montrer les commandes de
-- la forme choisie, CELLES-LA seulement, et dessiner le seuil.
local A = LCM.UI.LieuxMJ
-- Un lieu a moi, avec un seuil complet, pour avoir le droit de tout toucher.
LCM.db.lieux = {}
__position(0, 0, 0)
local atelierLieu = L.Creer("Les Marches Grises")
local atelierSeuil = L.CreerSeuil(atelierLieu.id, "Porte du Nord", "porte")
__position(0, 10, 0)
L.PoserBorne(atelierSeuil.id)
__position(4, 5, 0)

A.lieu, A.seuil = atelierLieu.id, atelierSeuil.id
local af = A.Fenetre()
af:Montrer()

attendu("porte : la 1re borne est proposée", af.borneA:IsShown(), true)
attendu("porte : le débord aussi", af.debord:IsShown(), true)
attendu("porte : pas de rayon", af.rayon:IsShown(), false)
attendu("porte : pas de points", af.point:IsShown(), false)
attendu("le radar trace la porte", af.radar.porte:IsShown(), true)
attendu("et ses deux bornes", af.radar.borneA:IsShown() and af.radar.borneB:IsShown(), true)
attendu("il nomme les deux côtés", af.radar.dedans:IsShown(), true)
attendu("la distance se lit", __sansCouleur(af.distance:GetText()):find("m") ~= nil, true)

-- Le bouton « Cercle » : deuxieme de la rangee des formes.
af.formes[2]:Click()
attendu("la forme a change", L.Seuil(atelierSeuil.id).forme, "cercle")
attendu("cercle : le rayon apparaît", af.rayon:IsShown(), true)
attendu("cercle : le centre aussi", af.centre:IsShown(), true)
attendu("cercle : les bornes ont disparu", af.borneA:IsShown(), false)
attendu("cercle : le débord aussi", af.debord:IsShown(), false)
attendu("le radar trace le disque", af.radar.disque:IsShown(), true)
attendu("et plus la porte", af.radar.porte:IsShown(), false)

-- Et le rayon se regle depuis le champ, comme en jeu.
af.rayon:SetText("25")
af.rayonOk:Click()
attendu("le rayon est pris", L.Seuil(atelierSeuil.id).rayon, 25)

-- Le bouton « Région ».
af.formes[3]:Click()
attendu("la forme a change", L.Seuil(atelierSeuil.id).forme, "region")
attendu("région : on pose des points", af.point:IsShown(), true)
attendu("région : on valide", af.valider:IsShown(), true)
attendu("région : plus de rayon", af.rayon:IsShown(), false)
attendu("le radar range le disque", af.radar.disque:IsShown(), false)
attendu("il dit combien il en manque",
    __sansCouleur(af.points:GetText()):find("au moins 3") ~= nil, true)

-- Trois points de plus, puis on valide : le contour se ferme sur le radar.
for _, p in ipairs({ { 20, 0 }, { 20, 20 }, { 0, 20 } }) do
    __position(p[1], p[2], 0)
    af.point:Click()
end
attendu("quatre points", #L.Seuil(atelierSeuil.id).points, 4)
attendu("le bouton propose de valider", af.valider.label:GetText(), "Valider la région")
af.valider:Click()
attendu("le contour est fermé", L.Seuil(atelierSeuil.id).ferme, true)
attendu("et le bouton propose de rouvrir", af.valider.label:GetText(), "Rouvrir le contour")
attendu("le radar pose les sommets", af.radar.points[4]:IsShown(), true)
attendu("et referme le contour", af.radar.aretes[4]:IsShown(), true)

-- Ce qui habille la fenetre replace ses propres pieces — la croix de
-- fermeture, la pastille — a chaque fois qu'il se redispose. Un bouton de
-- l'atelier qui porterait le MEME nom de champ qu'une de ces pieces partirait
-- se loger dans le coin, a la taille d'une croix, et disparaitrait de sa
-- rangee. C'est arrive a « Valider la région », qui s'appelait `fermer`
-- (10 octobre 2026) ; hors du jeu l'habillage ne se redispose jamais, donc on
-- le force ici.
local avantLargeur = af.valider:GetWidth()
af:PlacerCoinsHaut()
attendu("l'habillage n'a pas volé le bouton", af.valider:GetWidth(), avantLargeur)
attendu("il est toujours à sa place", af.valider:IsShown(), true)
attendu("et la croix de la fenêtre est intacte", af.fermer ~= af.valider, true)

-- Retour a la porte : les bornes reviennent, et elles sont toujours la.
af.formes[1]:Click()
attendu("porte : les bornes reviennent", af.borneA:IsShown(), true)
attendu("elles n'ont pas été perdues", L.Complet(L.Seuil(atelierSeuil.id)), true)
attendu("le radar retrace la porte", af.radar.porte:IsShown(), true)

dire("== un lieu selectionne, sans seuil, ne montre pas le radar")
A.seuil = nil
af:Afficher()
attendu("le radar est rangé", af.radar:IsShown(), false)
attendu("la couleur du lieu est proposée", af.couleur:IsShown(), true)
af:Hide()

dire("== l'atelier a sa branche dans l'eventail des Outils")
local noeud = LCM.UI.Menu.Trouver("lieux")
attendu("l'entrée existe", noeud ~= nil, true)
attendu("elle est libellée", noeud and noeud.label, "Lieux")
attendu("réservée au MJ", noeud and noeud.mjSeulement, true)
attendu("et elle ouvre quelque chose", LCM.UI.Menu.EstLiee("lieux"), true)

-- Le dossier Outils est passe a NEUF branches. L'eventail ne sait dessiner que
-- les longueurs de bandeau qui existent, et au-dela d'elles il escamote la
-- derniere branche SANS RIEN DIRE : le plafond et le dessin doivent rester
-- d'accord.
local outils
for _, n in ipairs(LCM.UI.Menu.STRUCTURE) do if n.id == "outils" then outils = n end end
attendu("neuf fenêtres dans Outils", outils and #outils.enfants, 9)
attendu("et l'éventail en accepte autant", LCM.UI.Radial.MAX_ENTREES >= 9, true)
attendu("le neuvième bandeau est dessiné", __fichierExiste(
    "LesContesMalveillants/ressources/radial/grimoire-fan-9.tga"), true)

dire("== le MJ les voit toutes les neuf")
local visibles = LCM.UI.Menu.Visibles(outils.enfants)
attendu("neuf branches", #visibles, 9)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
