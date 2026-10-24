-- La fenetre Vendeur du MJ (21 octobre 2026) : les vendeurs se rangent en
-- categories, affichees en accordeons avec « Tout replier ». On cree une
-- categorie depuis la bibliotheque (« + Créer une catégorie ») — pas dans le
-- catalogue, qui n'a rien a voir — puis on y range un vendeur en le glissant
-- sur son en-tete, ou par clic droit. Et chaque emplacement pose a son bouton
-- « S'y téléporter », comme dans Coffres et Ressources.
--
-- Contenu TEMOIN uniquement.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

local HERBE = "ressources/herbe_temoin"
LCM.Brouillons.Set("ressources", { id = "herbe_temoin", label = "Herbe témoin" })
LCM.Brouillons.Set("devises", { id = "piece_temoin", label = "Pièce témoin" })
local function Vendeur(id, label)
    LCM.Brouillons.Set("points", {
        id = id, label = label, nature = "vendeur", deviseDefaut = "piece_temoin",
        onglets = { { id = "o1", label = "Articles", offres = {
            { id = "herbe", entree = HERBE, quantite = 1, prix = 3, devise = "piece_temoin" },
        } } },
        rachats = { { id = "r1", label = "Rachats", offres = {} } },
    })
end
Vendeur("etal_temoin_a", "Étal A")
Vendeur("etal_temoin_b", "Étal B")
Vendeur("etal_temoin_c", "Étal C")

__declencher("PLAYER_LOGIN")
__personnage()
__position(10, 10, 0)
local Points = LCM.Points

-- Les vendeurs de la campagne ne comptent pas : on ne regarde que les temoins.
local f = LCM.UI.MarchandsMJ.Basculer()
local function Ligne(id)
    for _, b in ipairs(f.lignes) do if b:IsShown() and b.pointId == id then return b end end
end
local function EnTete(nom)
    for _, h in ipairs(f.entetes) do if h:IsShown() and h.categorie == nom then return h end end
end

local function Creer(nom)
    f.creerCategorie:Click()
    f.nomCategorie:Saisir(nom)
    f.nomCategorie:GetScript("OnEnterPressed")(f.nomCategorie)
end

dire("== creer une categorie depuis la bibliotheque")
attendu("le catalogue n'a plus de champ categorie", f.creation.categorie, nil)
-- On ne demande plus l'ABSENCE de tout en-tete : la seance a desormais des
-- vendeurs dont la categorie est une chaine vide, et ils forment leur propre
-- groupe (24 octobre 2026). Un scenario ne compte que ses temoins — la
-- categorie qu'on s'apprete a creer, et les etals qui n'en portent aucune.
attendu("la categorie temoin n'existe pas encore", EnTete("Port témoin"), nil)
attendu("  et les etals temoins n'en portent aucune", Points.Get("etal_temoin_a").categorie, nil)
f.creerCategorie:Click()
attendu("le bouton laisse place a la saisie", f.nomCategorie:IsShown() and not f.creerCategorie:IsShown(), true)
f.nomCategorie:Saisir("Port témoin")
f.nomCategorie:GetScript("OnEnterPressed")(f.nomCategorie)
attendu("l'accordeon apparait, vide", EnTete("Port témoin") ~= nil, true)
attendu("et le bouton revient", f.creerCategorie:IsShown(), true)
attendu("aucun vendeur n'a encore bouge", Points.Get("etal_temoin_a").categorie, nil)
Creer("port TÉMOIN")
attendu("un doublon est refuse", __sansCouleur(__sorties[#__sorties]):find("existe déjà", 1, true) ~= nil, true)
f.nomCategorie:GetScript("OnEscapePressed")(f.nomCategorie)
EnTete("Port témoin").glisserDepose({ categorie = "vendeur", element = Points.Get("etal_temoin_a") })
attendu("le vendeur glisse porte la categorie", Points.Get("etal_temoin_a").categorie, "Port témoin")
attendu("elle part dans la base avec lui", LCM.Brouillons.Get("points", "etal_temoin_a").categorie, "Port témoin")
attendu("son catalogue n'a pas bouge", #Points.Get("etal_temoin_a").onglets[1].offres, 1)
attendu("un en-tete apparait", EnTete("Port témoin") ~= nil, true)
attendu("le vendeur est dessous, en retrait", select(4, Ligne("etal_temoin_a"):GetPoint(1)), 10)

dire("== ranger par glisser-deposer")
local h = EnTete("Port témoin")
local objet = { categorie = "vendeur", element = Points.Get("etal_temoin_b") }
attendu("l'en-tete accepte un vendeur", h.glisserAccepte(objet), true)
attendu("mais pas autre chose", h.glisserAccepte({ categorie = "etats", element = {} }), false)
h.glisserDepose(objet)
attendu("le vendeur glisse est range", Points.Get("etal_temoin_b").categorie, "Port témoin")
attendu("y lacher un vendeur deja dedans est refuse",
    EnTete("Port témoin").glisserAccepte({ categorie = "vendeur", element = Points.Get("etal_temoin_b") }), false)

dire("== ranger par clic droit")
f:Choisir("etal_temoin_c")
Creer("Marché témoin")
Ligne("etal_temoin_b"):Click("RightButton")
local menu = LCM.UI.menuContexte
attendu("le clic droit ouvre « Ranger dans »", menu and menu:IsShown(), true)
attendu("le clic droit ne change pas la selection", f.pointId, "etal_temoin_c")
local ranger = menu.lignes[1]
attendu("avec « Ranger dans »", ranger.texte:GetText(), "Ranger dans")
ranger:Click()
local cible
for _, l in ipairs(menu.sousLignes) do
    if l:IsShown() and l.texte:GetText() == "Marché témoin" then cible = l end
end
attendu("le sous-menu propose les autres categories", cible ~= nil, true)
cible:Click()
attendu("le vendeur y est range", Points.Get("etal_temoin_b").categorie, "Marché témoin")

dire("== les accordeons")
EnTete("Port témoin"):Click()
attendu("replier cache ses vendeurs", Ligne("etal_temoin_a"), nil)
attendu("les autres restent", Ligne("etal_temoin_b") ~= nil, true)
EnTete("Port témoin"):Click()
attendu("deplier les rend", Ligne("etal_temoin_a") ~= nil, true)
attendu("« Tout replier » se voit", f.toutReplier:IsShown(), true)
f.toutReplier:Click()
attendu("tout replie : plus aucun vendeur", Ligne("etal_temoin_a") == nil and Ligne("etal_temoin_b") == nil, true)
attendu("et le bouton propose de deplier", f.toutReplier.label:GetText(), "Tout déplier")
f.toutReplier:Click()
attendu("tout deplie", Ligne("etal_temoin_a") ~= nil and Ligne("etal_temoin_b") ~= nil, true)

dire("== sortir d'une categorie")
EnTete("").glisserDepose({ categorie = "vendeur", element = Points.Get("etal_temoin_a") })
attendu("glisse sur « Sans catégorie », il en sort", Points.Get("etal_temoin_a").categorie, nil)
attendu("le vendeur jamais range y est aussi", Points.Get("etal_temoin_c").categorie, nil)

dire("== la recherche lit aussi la categorie")
-- On ne se souvient pas toujours du nom d'un vendeur, mais de l'endroit.
LCM.UI.Points.Categoriser(Points.Get("etal_temoin_b"), "Port témoin")
f.recherche:Saisir("PORT TÉMOIN")
attendu("le vendeur se trouve par sa categorie", Ligne("etal_temoin_b") ~= nil, true)
attendu("et pas ceux d'ailleurs", Ligne("etal_temoin_c"), nil)
f.recherche:Saisir("Étal C")
attendu("le nom marche toujours", Ligne("etal_temoin_c") ~= nil, true)
f.recherche:Saisir("")

dire("== « S'y téléporter » sur ses propres emplacements")
local id = LCM.MarchandsMJ.Placer("etal_temoin_a")
attendu("un emplacement pose", id ~= nil, true)
local D = LCM.DeplacementForce
local commandeVraie, envoyee = D.Commande, nil
D.Commande = function(texte) envoyee = texte return true end
f:Choisir("etal_temoin_a")
f:Onglet("placement")
local ligne
for _, l in ipairs(f.placement.lignes) do if l:IsShown() and l.poseId == id then ligne = l end end
attendu("le bouton est la, sur le sien", ligne and ligne.teleporter:IsShown(), true)
ligne.teleporter:Click()
attendu("il envoie .worldport", envoyee and envoyee:find(".worldport ", 1, true) == 1, true)
D.Commande = commandeVraie

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
