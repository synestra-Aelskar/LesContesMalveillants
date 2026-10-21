-- Les points poses dans la base commune (MJ/Poses.lua, 21 octobre 2026).
--
-- Un coffre, un filon, un vendeur poses partent dans la file d'envoi a chaque
-- changement ; un retrait y laisse sa suppression. Au chargement, la base rend
-- au MJ SES points qui manquent (une sauvegarde perdue), met ceux d'un autre MJ
-- en garde, et ne ressuscite rien de ce qu'on a retire.
local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

local MOI = LCM.PlayerId()
local SYN = "Syn-Apertus"
attendu("on se connait avant la connexion", MOI ~= nil and MOI ~= "", true)
local CARTE = LCM.Recolte.Carte()

-- Les modeles, temoins.
LCM.Objets.Add({ id = "or_pose", label = "Or témoin", categorie = "accessoire",
    icone = "inv_misc_key_01", pileMax = 10 })
LCM.Brouillons.Set("ressources", { id = "minerai_pose", label = "Minerai témoin" })
LCM.Brouillons.Set("points", { id = "coffre_pose", label = "Coffre posé", nature = "coffre",
    coffre = { places = 4, rayon = 4, verrous = 0, reset = false,
        objets = { { entree = "objets/or_pose", quantite = 1 } }, expertises = {}, outils = {} } })
LCM.Brouillons.Set("points", { id = "filon_pose", label = "Filon posé", nature = "ressource",
    offres = {}, recolte = { dd = 0, rayon = 3, limite = 1, metiers = {},
        ressources = { { entree = "ressources/minerai_pose", min = 1, max = 1, chance = 100 } } } })
LCM.Brouillons.Set("points", { id = "etal_pose", label = "Étal posé", nature = "vendeur",
    onglets = { { id = "o1", label = "Articles", offres = {
        { id = "minerai", entree = "ressources/minerai_pose", quantite = 1, prix = 0,
          stock = { limite = 5, unites = 0, minutes = 0 } } } } },
    rachats = {} })

-- La BASE, telle que le fichier genere la publierait : ce que le service a
-- rapporte du Sheet.
local function Base(id, nature, auteur, donnees, extra)
    local d = { id = id, nature = nature, label = id, auteur = auteur, epoque = 0, version = 3,
        donnees = donnees }
    for k, v in pairs(extra or {}) do d[k] = v end
    LCM.Publier(LCM.Poses, d)
end
-- Mon coffre, perdu de ma sauvegarde.
Base("c_perdu", "coffre", MOI, { def = "coffre_pose", x = 1, y = 2, z = 0, source = "monde",
    carte = CARTE, objets = { { entree = "objets/or_pose", quantite = 7 } },
    verrousRestants = 0, verrouille = false, ouvert = true, verrousOuverts = {} })
-- Le coffre de Syn.
Base("c_syn", "coffre", SYN, { def = "coffre_pose", x = 5, y = 5, z = 0, source = "monde",
    carte = CARTE, objets = { { entree = "objets/or_pose", quantite = 2 } },
    verrousRestants = 0, verrouille = false, ouvert = true, verrousOuverts = {} })
-- Mon filon et mon etal, perdus aussi.
Base("f_perdu", "ressource", MOI, { def = "filon_pose", x = 10, y = 10, z = 0, source = "monde",
    carte = CARTE, quand = 1, lignes = { ["ressources/minerai_pose"] = { actif = true } } })
local cleStock = "etal_pose/minerai"
Base("e_perdu", "vendeur", MOI, { def = "etal_pose", x = 20, y = 20, z = 0, source = "monde",
    carte = CARTE, quand = 1 }, { stock = { [cleStock] = 3 } })
-- Le filon et l'etal de Syn.
Base("f_syn", "ressource", SYN, { def = "filon_pose", x = 70, y = 70, z = 0, source = "monde",
    carte = CARTE, quand = 2, lignes = {} })
Base("e_syn", "vendeur", SYN, { def = "etal_pose", x = 80, y = 80, z = 0, source = "monde",
    carte = CARTE, quand = 2 })
-- Un filon que J'AI retire : la base l'a encore, ma suppression n'est pas
-- encore partie.
Base("f_retire", "ressource", MOI, { def = "filon_pose", x = 30, y = 30, z = 0, source = "monde",
    carte = CARTE, quand = 1, lignes = {} })
-- Un coffre pose AVANT la base commune, dans ma sauvegarde.
LCM.EnsureDatabase()
LCM.db.coffresMJ = { c_ancien = { id = "c_ancien", def = "coffre_pose", x = 3, y = 3, z = 0,
    source = "monde", carte = CARTE, quand = 1, objets = { { entree = "objets/or_pose", quantite = 4 } },
    verrousRestants = 0, verrouille = false, ouvert = true, verrousOuverts = {} } }
-- Une sauvegarde MJ deja au modele 2 : la migration n'efface plus ses notes.
LCM_MJ_DB.version = 2
LCM.Brouillons.Masques("poses").f_retire = true

__declencher("PLAYER_LOGIN")
__personnage()
__avancer(1)

dire("== au chargement, la base rend ce qui manque")
local coffres, recoltes, marchands = LCM.db.coffresMJ or {}, LCM.db.recoltes or {}, LCM.db.marchands or {}
attendu("mon coffre perdu revient", coffres.c_perdu ~= nil, true)
attendu("  avec son contenu", coffres.c_perdu and coffres.c_perdu.objets[1].quantite, 7)
attendu("le coffre de Syn est en garde, pas à moi", coffres.c_syn, nil)
attendu("  il est bien gardé", LCM.db.coffresGarde and LCM.db.coffresGarde.c_syn ~= nil, true)
attendu("mon filon perdu revient", recoltes.f_perdu ~= nil, true)
attendu("  avec ses lignes", recoltes.f_perdu and recoltes.f_perdu.lignes["ressources/minerai_pose"] ~= nil, true)
attendu("le filon retiré ne revient pas", recoltes.f_retire, nil)
attendu("mon étal perdu revient", marchands.e_perdu ~= nil, true)
attendu("  et son stock perdu avec lui", LCM.Stock.Restant(cleStock), 3)
attendu("les joueurs voient mon coffre rendu", LCM.Coffres.points.c_perdu ~= nil, true)

local file = function() return LCM_MJ_DB.brouillons.poses or {} end
attendu("un coffre posé avant la base part dès le chargement", file().c_ancien ~= nil, true)
attendu("  avec son contenu", file().c_ancien and file().c_ancien.donnees.objets[1].quantite, 4)

dire("== poser un coffre l'écrit dans la file d'envoi")
local idCoffre = LCM.CoffresMJ.Placer("coffre_pose", { x = 40, y = 40, z = 0, source = "monde", carte = CARTE })
attendu("coffre posé", idCoffre ~= nil, true)
local ligne = file()[idCoffre]
attendu("  il part vers la base", ligne ~= nil, true)
attendu("  comme coffre", ligne and ligne.nature, "coffre")
attendu("  à mon nom", ligne and ligne.auteur, MOI)
attendu("  avec son contenu", ligne and ligne.donnees.objets[1].entree, "objets/or_pose")
local version = ligne and ligne.version

dire("== un geste le réécrit, plus récent")
LCM.CoffresMJ.Traiter(MOI, { i = idCoffre, a = "prendre", e = "objets/or_pose", q = 1, edition = true })
ligne = file()[idCoffre]
attendu("  le contenu suit", ligne and #ligne.donnees.objets, 0)
attendu("  la version monte", ligne and ligne.version > version, true)

dire("== retirer le coffre note la suppression")
LCM.CoffresMJ.Retirer(idCoffre)
attendu("  la ligne quitte la file", file()[idCoffre], nil)
attendu("  la suppression part", LCM_MJ_DB.masques.poses[idCoffre], true)

dire("== poser un filon et un vendeur")
__position(50, 50, 0)
local idFilon = LCM.Recoltes.Placer("filon_pose")
attendu("filon posé", idFilon ~= nil, true)
attendu("  il part vers la base", file()[idFilon] and file()[idFilon].nature, "ressource")
LCM.Recoltes.Allumer(idFilon)
attendu("  allumé, la ligne suit", file()[idFilon] and file()[idFilon].donnees.lignes["ressources/minerai_pose"] ~= nil, true)
local idEtal = LCM.MarchandsMJ.Placer("etal_pose")
attendu("vendeur posé", idEtal ~= nil, true)
attendu("  il part vers la base", file()[idEtal] and file()[idEtal].nature, "vendeur")
attendu("  avec le reste de son stock", file()[idEtal] and file()[idEtal].stock[cleStock], 3)
LCM.Recoltes.Retirer(idFilon)
attendu("retirer le filon note sa suppression", LCM_MJ_DB.masques.poses[idFilon], true)

dire("== une garde perdue n'est plus écrite par moi")
local idGarde = LCM.CoffresMJ.Placer("coffre_pose", { x = 60, y = 60, z = 0, source = "monde", carte = CARTE })
local repris = LCM.Copie(LCM.db.coffresMJ[idGarde])
repris.auteur, repris.epoque, repris.version = SYN, 1, 1
LCM.CoffresMJ.RecevoirCopie(SYN, repris)
attendu("  il n'est plus dans mon magasin", LCM.db.coffresMJ[idGarde], nil)
attendu("  ma ligne ne part plus", file()[idGarde], nil)
attendu("  sans suppression : elle est à Syn", LCM_MJ_DB.masques.poses[idGarde], nil)

dire("== les listes de placement sont personnelles (le MJ, 21 octobre 2026)")
-- Ce qu'une liste montre : le texte de chaque ligne visible, et si on peut la
-- retirer.
local function Lignes(lignes, champ)
    local out = {}
    for _, l in ipairs(lignes) do
        if l:IsShown() then
            out[#out + 1] = { texte = l[champ]:GetText(), retirable = l.retirer:IsShown(), pose = l.pose }
        end
    end
    return out
end
local function Cherche(lignes, id)
    for _, l in ipairs(lignes) do if l.pose and l.pose.id == id then return l end end
end

local fc = LCM.UI.CoffresMJ.Fenetre()
fc:Montrer()
fc:Choisir("coffre_pose")
fc:Onglet("placement")
local liste = Lignes(fc.placements, "label")
attendu("coffres : par défaut, seulement les miens", Cherche(liste, "c_syn"), nil)
attendu("  le mien est là", Cherche(liste, "c_perdu") ~= nil, true)
attendu("  le sélecteur le dit", fc.placement.filtre.label:GetText():find("les miens", 1, true) ~= nil, true)
fc.placement.filtre:Click()
liste = Lignes(fc.placements, "label")
local syn = Cherche(liste, "c_syn")
attendu("« tous » : celui de Syn apparaît", syn ~= nil, true)
attendu("  posé par Syn", syn and syn.texte:find("par Syn", 1, true) ~= nil, true)
attendu("  en lecture seule", syn and syn.retirable, false)
attendu("  le mien reste retirable", Cherche(liste, "c_perdu") and Cherche(liste, "c_perdu").retirable, true)
fc.placement.filtre:Click()
liste = Lignes(fc.placements, "label")
attendu("« posés par Syn » : les siens seulement", #liste == 1 and liste[1].pose.id, "c_syn")
attendu("  le sélecteur le dit", fc.placement.filtre.label:GetText():find("posés par Syn", 1, true) ~= nil, true)
fc:Hide()

local fr = LCM.UI.Recoltes.Fenetre()
fr:Montrer()
fr:Choisir("filon_pose")
fr:Onglet("placement")
liste = Lignes(fr.placement.lignes, "texte")
attendu("filons : par défaut, seulement les miens", Cherche(liste, "f_syn"), nil)
fr.placement.filtre:Click()
liste = Lignes(fr.placement.lignes, "texte")
syn = Cherche(liste, "f_syn")
attendu("« tous » : celui de Syn apparaît", syn ~= nil, true)
attendu("  en lecture seule", syn and syn.retirable, false)
fr:Hide()

local fm = LCM.UI.MarchandsMJ.Fenetre()
fm:Montrer()
fm:Choisir("etal_pose")
fm:Onglet("placement")
liste = Lignes(fm.placement.lignes, "texte")
attendu("vendeurs : par défaut, seulement les miens", Cherche(liste, "e_syn"), nil)
fm.placement.filtre:Click()
liste = Lignes(fm.placement.lignes, "texte")
syn = Cherche(liste, "e_syn")
attendu("« tous » : celui de Syn apparaît", syn ~= nil, true)
attendu("  en lecture seule", syn and syn.retirable, false)
fm:Hide()

dire("== qui a posé ne change pas quand la garde passe")
attendu("mon coffre posé dit qui l'a posé", LCM.db.coffresMJ.c_ancien and LCM.db.coffresMJ.c_ancien.posePar, MOI)
local ligne = file().c_ancien
attendu("  et la base le sait", ligne and ligne.donnees.posePar, MOI)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
