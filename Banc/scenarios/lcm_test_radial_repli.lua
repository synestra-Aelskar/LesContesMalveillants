-- Un rafraichissement pendant qu'un eventail se replie ne doit pas bloquer
-- le menu (20 octobre 2026).
--
-- Constate en jeu : d'un coup, Personnage, Objets, Systeme et Outils ne
-- s'ouvraient plus, alors que Grimoires et Deplacement (sans dossier) si.
-- Changer de dossier replie d'abord l'eventail ouvert ; pendant ces 0,3 s,
-- `c.replie` refuse les clics. Si la fiche du joueur bouge a ce moment (une
-- blessure, un gain d'XP, une incarnation), Radial.Rafraichir redessine, ce
-- qui arrete l'animation du bandeau... et avec elle la fin du repli qui
-- devait lever le verrou. Le verrou restait pose : tout dossier refusait de
-- s'ouvrir jusqu'a la fermeture du sceau.
local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()
local R = LCM.UI.Radial
R.Basculer("fenetres")
__avancer(1)
local c = R.frame.couronnes["fenetres"]
-- Ce qui est DESSINE, pas ce qui est retenu : un clic refuse par le verrou
-- retient quand meme la categorie dans `c.choisi`.
local function Deploye(couronne, id)
    local cat
    for i = 1, couronne.nombreCategories do
        if couronne.boutonsCategorie[i].cible.id == id then cat = couronne.boutonsCategorie[i].cible end
    end
    local voulues = couronne.def.Entrees(cat)
    local b = couronne.boutonsEntree[1]
    return b ~= nil and b:IsShown() and b.cible == voulues[1] and couronne.nombreEntrees == #voulues
end
local function Bouton(id)
    for i = 1, c.nombreCategories do
        if c.boutonsCategorie[i].cible.id == id then return c.boutonsCategorie[i] end
    end
end

dire("== un dossier s'ouvre")
Bouton("objets"):Click()
__avancer(1)
attendu("Objets deploye", c.choisi .. " " .. c.nombreEntrees, "objets 4")

dire("== on change de dossier, et la fiche bouge pendant le repli")
Bouton("outils"):Click()
__avancer(0.1)
attendu("le repli est en cours", c.replie, true)
R.Rafraichir()
__avancer(1)
attendu("le verrou est leve", c.replie, nil)
attendu("Outils est deploye", Deploye(c, "outils"), true)

dire("== les dossiers s'ouvrent encore")
for _, id in ipairs({ "fiches_personnages", "objets", "systeme", "outils" }) do
    Bouton(id):Click()
    __avancer(1)
    attendu("  " .. id, Deploye(c, id), true)
end

dire("== meme chose sur la couronne des actions")
R.Basculer("actions")
__avancer(1)
local a = R.frame.couronnes["actions"]
local premier, second
for i = 1, a.nombreCategories do
    local b = a.boutonsCategorie[i]
    if #a.def.Entrees(b.cible) > 0 and not b.cible.direct then
        if not premier then premier = b elseif not second then second = b end
    end
end
premier:Click()
__avancer(1)
second:Click()
__avancer(0.1)
R.Rafraichir()
__avancer(1)
attendu("le verrou est leve", a.replie, nil)
premier:Click()
__avancer(1)
attendu("la premiere categorie se rouvre", Deploye(a, premier.cible.id), true)

-- 21 octobre 2026 : « Système » retenu, plus rien ne s'ouvrait, sans
-- rafraichissement cette fois. Toutes les animations passent par UNE boucle :
-- une qui plante a chaque image empechait les autres de finir, dont le repli
-- qui leve le verrou. Quoi qu'il arrive, le menu doit repartir.
dire("== une animation qui plante ne gele pas le menu")
R.Fermer() __avancer(1)
R.Basculer("fenetres") __avancer(1)
Bouton("systeme"):Click() __avancer(1)
local vraiSetAlpha = c.secteur.SetAlpha
c.secteur.SetAlpha = function() error("panne simulee") end
local nSorties = #__sorties
Bouton("outils"):Click()
__avancer(1)
c.secteur.SetAlpha = vraiSetAlpha
local dit = false
for i = nSorties + 1, #__sorties do if __sorties[i]:find("panne simulee", 1, true) then dit = true end end
attendu("l'erreur est dite", dit, true)
attendu("le verrou est leve", c.replie, nil)
attendu("Outils est deploye", Deploye(c, "outils"), true)

dire("== un verrou perime ne refuse plus rien")
c.replie, c.replieJusqua = true, GetTime() - 1
Bouton("objets"):Click()
__avancer(1)
attendu("Objets s'ouvre malgre le vieux verrou", Deploye(c, "objets"), true)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
