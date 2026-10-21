-- Livres : edition MJ, compendium, lecture et transmission par loot.
-- 2,5 s incluent la preparation GPU des atlas lors du premier affichage.
local ko = 0
local function attendu(nom, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    print((ok and "  ok  " or "  KO  ") .. nom .. " = " .. tostring(obtenu)
        .. (ok and "" or " (attendu " .. tostring(voulu) .. ")"))
end

LCM.Brouillons.Set("sacs", { id = "sac_livres_temoin", label = "Sac témoin",
    places = 12, icone = "inv_misc_bag_30" })
__declencher("PLAYER_LOGIN")
__personnage()
local moi = LCM.Entities.Self()
local sacPose, raisonSac = LCM.Inventaire.Poser(moi, "sacs", 1, "sac_livres_temoin", true)
attendu("sac de test disponible", sacPose, true)
if not sacPose then print(tostring(raisonSac)) end
local categorie = LCM.Compendium.Get("livres")
attendu("categorie de compendium", categorie and categorie.label, "Livres")
attendu("livres hors de la forge", LCM.UI.Forge.EstCategorie(categorie), false)

LCM.CompendiumEditeur.Ouvrir(categorie)
local f = LCM.LivresUI.frame
attendu("editeur de livres ouvert", f and f:IsShown(), true)
if f then
    f.nom:Saisir("Chronique témoin")
    f.texte.saisie:Saisir("Recto témoin")
    f.lignes[2]:Click()
    f.texte.saisie:Saisir("Verso témoin")
    attendu("note sur deux faces", #f.travail.pages, 2)
    f.livre:Click()
    f.modele:Click()
    attendu("choix de reliure", f.travail.modele, "astral")
    f.ajouter:Click()
    attendu("ajout d'une page de livre", #f.travail.pages, 3)
    f.fond:Saisir("EEDDCC")
    f.titrePage:Saisir("Troisième page")
    f.texte.saisie:Saisir("Le récit continue.")
    attendu("enregistrement du livre", f:Enregistrer(), true)
end
local livre = f and LCM.Livres.Get(f.travail.id)
local ref = livre and "livres/" .. livre.id
attendu("livre publié", livre and livre.label, "Chronique témoin")
attendu("couleur personnalisée", livre and livre.style.fond, "EEDDCC")
attendu("reliure enregistree", livre and livre.modele, "astral")
attendu("compendium résout le livre", ref and LCM.Compendium.Resoudre(ref) ~= nil, true)
if ref then
    local depose, raisonDepot = LCM.Inventaire.Deposer(moi, ref, 1)
    attendu("livre dans l'inventaire", depose, true)
    if not depose then print(tostring(raisonDepot)) end
    local sac = LCM.UI.Inventaires.OuvrirSac("sacs", 1)
    -- Le clic choisit la case depuis la selection multiple (20 octobre
    -- 2026) : on lit au double-clic.
    sac.cases[1]:DoubleClick("LeftButton")
    attendu("double-clic inventaire lance la lecture", LCM.UI.Livres.frame:IsShown(), true)
    sac.cases[1]:Click("RightButton")
    local menu = LCM.UI.MenuContexte()
    local lirePropose = false
    for _, ligne in ipairs(menu.lignes or {}) do
        if ligne:IsShown() and ligne.texte and ligne.texte:GetText() == "Lire" then
            lirePropose = true
            ligne:Click()
            break
        end
    end
    attendu("clic droit propose Lire", lirePropose, true)
    attendu("clic droit lance la lecture", LCM.UI.Livres.frame:IsShown(), true)
    attendu("lecture au clic", LCM.UI.Livres.Ouvrir(ref), true)
    local lecture = LCM.UI.Livres.frame
    attendu("couverture affichée", lecture.compteur:GetText():match("Couverture") ~= nil, true)
    lecture:Tourner(1)
    __avancer(2.5)
    attendu("animation tourne la page", lecture.index, 2)
    attendu("double page visible", lecture.ouvert:IsShown(), true)
    attendu("page droite remplie", lecture.droite:IsShown(), true)
    lecture:Tourner(1)
    __avancer(2.5)
    attendu("derniere page impaire", lecture.index, 4)
    attendu("page droite vide masquee", lecture.droite:IsShown(), false)
    lecture:Tourner(1)
    __avancer(2.5)
    attendu("dos du livre", lecture.compteur:GetText(), "Dos")
    lecture:Tourner(-1)
    __avancer(2.5)
    attendu("retour depuis le dos", lecture.index, 4)
    local note = { id = "note_visuelle", label = "Note témoin", format = "note",
        pages = { { titre = "Recto", texte = "A" }, { titre = "Verso", texte = "B" } } }
    attendu("apercu d'une note", LCM.UI.Livres.Apercu(note), true)
    attendu("feuille distincte visible", lecture.note:IsShown(), true)
    lecture:Tourner(1)
    __avancer(2.5)
    attendu("note retournee", lecture.index, 2)

    local paquet = LCM.Recolte.Paquet({ id = "filon_livre", label = "Filon témoin",
        ressources = { { entree = ref, min = 1, max = 1 } } }, {})
    paquet = LCM.Reseau.Decoder(LCM.Reseau.Encoder(paquet))
    LCM.Livres.Retirer(livre.id)
    LCM.Recolte.Lire(paquet)
    attendu("ressource transmet la definition", LCM.Livres.Get(livre.id) ~= nil, true)
    attendu("ressource transmet la reliure", LCM.Livres.Get(livre.id).modele, "astral")
    local coffre = LCM.Coffres.Paquet({ id = "coffre_livre", label = "Coffre témoin",
        coffre = { places = 1, objets = { { entree = ref, quantite = 1 } } } }, {})
    coffre = LCM.Reseau.Decoder(LCM.Reseau.Encoder(coffre))
    LCM.Livres.Retirer(livre.id)
    LCM.Coffres.Lire(coffre)
    attendu("coffre transmet la definition", LCM.Livres.Get(livre.id) ~= nil, true)
    attendu("coffre transmet la reliure", LCM.Livres.Get(livre.id).modele, "astral")
    local valide = LCM.Points.Construire({ id = "coffre_livre_valide", nature = "coffre",
        coffre = { places = 1, objets = { { entree = ref, quantite = 1 } } } })
    attendu("livre accepte dans un coffre", valide.coffre.objets[1].entree, ref)
    local editeurCoffre = LCM.UI.CoffresMJ.Fenetre()
    editeurCoffre:Nouveau()
    editeurCoffre.depotObjets:Click()
    local dansCoffre = false
    for _, ligne in ipairs(editeurCoffre.choixObjet.lignes) do
        if ligne:IsShown() and ligne.choix == ref then dansCoffre = true end
    end
    attendu("livre proposé par l'éditeur de coffre", dansCoffre, true)
    local editeurRecolte = LCM.UI.Recoltes.Fenetre()
    editeurRecolte:Nouveau()
    editeurRecolte.creation.entree:Click()
    local enRessource = false
    for _, ligne in ipairs(editeurRecolte.choixEntree.lignes) do
        if ligne:IsShown() and ligne.choix == ref then enRessource = true end
    end
    attendu("livre proposé par l'éditeur Ressources", enRessource, true)
end

if ko == 0 then print("TOUT PASSE") else error(ko .. " échec(s)") end
