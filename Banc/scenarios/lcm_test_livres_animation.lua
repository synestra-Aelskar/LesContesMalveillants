-- Le maillage TGA et les glyphes projetes ont ete remplaces par des atlas BLP.
-- Verifie les comportements de lecture et les ressources reellement livrees.
__declencher("PLAYER_LOGIN")
local A = LCM.UI.LivresAnimation
local definition = { id = "atlas_temoin", label = "Les chemins de l'aube", format = "livre",
    couverture = { titre = "Les chemins de l'aube", texte = "Carnet de voyage" },
    pages = { { titre = "Le départ", texte = "À l’aube, le veilleur écrivait encore." },
        { titre = "Deuxième", texte = "Feuillet recto" },
        { titre = "Troisième", texte = "Feuillet verso" },
        { titre = "Quatrième", texte = "En dessous" } } }
local function existe(texture)
    local chemin = texture:GetTexture()
    assert(chemin:match("%.blp$"), "texture du lecteur au format BLP")
    local relatif = chemin:gsub("^Interface\\AddOns\\", "")
    assert(__fichierExiste(relatif), chemin .. " absent")
end
for _, modele in ipairs(LCM.Livres.Modeles) do
    definition.modele = modele.id
    assert(LCM.UI.Livres.Apercu(definition))
    local f = LCM.UI.Livres.frame
    existe(f.ouvert.image); existe(f.couverture.image); existe(f.note.image)
    for _, planches in pairs(f.tourne.sequences) do for _, image in ipairs(planches) do existe(image) end end
    assert(f.couverture.page.titre:GetText() == definition.couverture.titre, "titre natif sur couverture")
    assert(f.couverture.page.texte:GetText() == "Carnet de voyage", "texte de couverture conserve")
    if modele.id == "necronicon" then
        local _, _, _, x, y = f.couverture.page:GetPoint()
        assert(x >= 100 and y <= -160, "titre hors du pendentif et des ferrures")
        local _, _, _, gx = f.gauche:GetPoint()
        assert(gx >= 100, "marge du papier du Necronicon")
    else
        assert(f.gauche:GetWidth() == 355, "marges classiques restaurees")
    end
    __avancer(2)
    f:Tourner(1); __avancer(1.6)
    assert(f.index == 2 and not f.animation, "ouverture terminee")
    assert(f.gauche.texte:GetText():find("veilleur"), "texte accentue intact")
    assert(f.gauche.texte:IsShown(), "texte natif visible")
    local _, taille = f.gauche.texte:GetFont()
    assert(taille >= 18, "taille de lecture minimale")
    f:Tourner(1); __avancer(.3)
    assert(f.index == 2 and f.tourne:IsShown(), "index inchange pendant le mouvement")
    assert(not f.ouvert:IsShown(), "pas de livre statique superpose a l'atlas")
    f:Hide()
    assert(not f.animation and not f.tourne:IsShown(), "interruption nettoyee")
    assert(f.droite.texte:GetText() == "Feuillet recto", "interruption conserve la page de depart")
    f:Ouvrir(LCM.Livres.Construire(definition)); f:Tourner(1); __avancer(1.6)
    f:Tourner(1); __avancer(1.6)
    f:Tourner(-1); __avancer(.3)
    assert(f.animation.miroir, "feuilletage arriere inverse visuellement")
    __avancer(1)
    assert(f.index == 2 and f.droite.texte:GetText() == "Feuillet recto", "retour arriere exact")
    f.zoom:Click()
    local _, agrandi = f.gauche.texte:GetFont()
    assert(agrandi > taille or agrandi == 18, "commande de taille appliquee")
    f:Fermer(); __avancer(1.6)
    assert(not f:IsShown() and not f.animation, "fermeture animee termine puis masque")
end

definition.modele = nil
assert(LCM.Livres.Construire(definition).modele == "necronicon", "anciens livres conservent le Necronicon")
LCM.LivresUI.Editer(definition)
assert(LCM.LivresUI.frame.travail.modele == "necronicon", "edition ancienne conserve le Necronicon")
LCM.LivresUI.frame.modele:Click()
assert(LCM.LivresUI.frame.travail.modele == "chronique", "les autres reliures restent accessibles")
definition.modele = "necronicon"
local paquet = LCM.Reseau.Decoder(LCM.Reseau.Encoder(definition))
assert(LCM.Livres.Importer("livres/" .. definition.id, paquet), "Necronicon recu")
assert(LCM.Livres.Get(definition.id).modele == "necronicon", "reliure conservee a la reception")
definition.modele = "introuvable"
assert(not pcall(LCM.Livres.Construire, definition), "modele inconnu refuse a la validation")
definition.modele = "chronique"
LCM.UI.Livres.Apercu(definition)
local f = LCM.UI.Livres.frame
__avancer(2)
-- Le client peut retarder une texture : la couverture reste lisible.
local image = f.tourne.sequences.opening[1]
image.IsObjectLoaded = function() return false end
f:Tourner(1); __avancer(.4)
assert(f.couverture:IsShown() and f.couverture.lecture:GetAlpha() == 1, "attente sans livre vide")
assert(f.index == 1, "attente sans avancer la lecture")
image.IsObjectLoaded = function() return true end
__avancer(1.6)
assert(f.index == 2 and not f.animation, "reprise apres chargement")
f:Tourner(-1); __avancer(.4)
LCM.UI.Livres.Apercu({ id = "note_atlas", label = "Note", format = "note",
    pages = { { texte = "Recto" }, { texte = "Verso" } } })
assert(f.note:IsShown() and not f.animation, "changement de livre annule l'ancien mouvement")
for _, t in ipairs(f.tourne.sequences.note) do existe(t) end
f:Tourner(1); __avancer(2.5)
assert(f.index == 2 and f.note.page.texte:GetText() == "Verso", "note retournee en BLP")
assert(#definition.pages == 4, "aucune mutation du contenu")
definition.pages[1].texte = string.rep("Une longue page à lire. ", 130)
LCM.UI.Livres.Apercu(definition); __avancer(2)
f:Tourner(1); __avancer(1.6)
assert(f.gauche.zone.debord > 0, "texte long accessible par defilement")
f.gauche.zone:Aller(100000)
assert(f.gauche.zone.decalage == f.gauche.zone.debord, "derniere ligne accessible")
f:Tourner(1); __avancer(1.6); f:Tourner(-1); __avancer(1.6)
assert(f.gauche.zone.decalage == 0, "retour au debut de la page")
print("LECTURE ET ATLAS BLP : TOUT PASSE")
