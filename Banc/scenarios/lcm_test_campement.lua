-- Le contenu du campement : tentes et accessoires (10 octobre 2026).
--
-- Ce que ce scenario tient :
--   * les deux categories existent, avec le bloc de statistiques du campement
--     (et pas celui de la fiche) ;
--   * les bonus sont des pourcentages ENTIERS : 0,3 est refuse avec ce qu'il
--     fallait ecrire, pas arrondi ;
--   * une tente ne peut pas inclure plus d'accessoires qu'elle n'en accepte ;
--   * la forge equilibre une tente comme un objet : sur SES statistiques.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end
local function contient(libelle, texte, morceau)
    local ok = tostring(texte or ""):find(morceau, 1, true) ~= nil
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(texte), ok and "" or ("(attendu « " .. morceau .. " »)"))
end

__declencher("PLAYER_LOGIN")
__personnage()
LCM.db.settings.modeJoueur = nil
LCM._masterCompanion = true

local C, T, A, B, F = LCM.Compendium, LCM.Tentes, LCM.AccessoiresCamping, LCM.Brouillons, LCM.Forge

dire("== les deux categories")
local tentes, accessoires = C.Get("tentes"), C.Get("accessoires_camping")
attendu("Tentes existe", tentes ~= nil, true)
attendu("Accessoires de camping existe", accessoires ~= nil, true)
local stats = F.Statistiques(tentes)
attendu("une tente a quatre statistiques", #stats, 4)
attendu("la premiere est la securite", stats[1] and stats[1].cle, "securite")
local etrangere = false
for _, champ in ipairs(stats) do if champ.cle == "force" then etrangere = true end end
attendu("pas de statistique de fiche", etrangere, false)
attendu("famille resolue", C.FAMILLES.tentes, "Tentes")

dire("== le contenu publie")
local auberge = T.Get("auberge_de_tephris")
attendu("l'Auberge de Tephris est chargee", auberge ~= nil, true)
attendu("sa securite en pourcentage", auberge and auberge.bonus.securite, 100)
attendu("un lit", auberge and auberge.lits, 1)
local kalea = A.Get("accessoire_reparation_kalea")
attendu("l'accessoire de Kaléa est charge", kalea ~= nil, true)
attendu("il rend de l'armure", kalea and kalea.bonus.recup_armure, 40)
attendu("et rien d'autre", kalea and kalea.bonus.recup_pv, nil)

dire("== ce qui est refuse")
local ok, err = pcall(T.Construire, { id = "t1", label = "T1", bonus = { recup_pv = 0.3 } })
attendu("un decimal est refuse", ok, false)
contient("     raison", err, "30 pour 0,3")
ok, err = pcall(T.Construire, { id = "t2", label = "T2", bonus = { force = 2 } })
attendu("un bonus de fiche est refuse", ok, false)
contient("     raison", err, "bonus de campement inconnu")
ok, err = pcall(T.Construire, { id = "t3", label = "T3", accessoiresMax = 1,
    accessoires = { "accessoire_reparation_kalea", "autre" } })
attendu("trop d'accessoires inclus refuse", ok, false)
contient("     raison", err, "2 accessoires inclus pour 1 places")
ok = pcall(T.Construire, { id = "t4", label = "T4", lits = 0 })
attendu("zero lit refuse", ok, false)

dire("== une tente peut n'agir que sur un seul bonus")
ok = B.Enregistrer("tentes", { id = "abri_sommaire", label = "Abri sommaire", bonus = { securite = -20 } }, true)
attendu("enregistree", ok, true)
attendu("elle ne porte que la securite", T.Get("abri_sommaire") and T.Get("abri_sommaire").bonus.recup_pv, nil)

dire("== un accessoire inclus apparait par son nom")
ok = B.Enregistrer("tentes", { id = "tente_l", label = "Tente de survie de Taille L", lits = 4, accessoiresMax = 6,
    accessoires = { "accessoire_reparation_kalea" }, bonus = { securite = -20, recup_fatigue = 30, recup_pv = 30 } }, true)
attendu("enregistree", ok, true)
local champ
for _, c in ipairs(C.Champs(tentes)) do if c.cle == "accessoires" then champ = c end end
attendu("champ des accessoires inclus", champ ~= nil, true)
attendu("affiche le nom", C.Texte(tentes, champ, T.Get("tente_l").accessoires),
    "Accessoire de réparation de Kaléa")

dire("== les attributs du camp : la tente plus ses accessoires")
-- Formule de securite de la feuille : tente + SOMME des accessoires. La meme
-- somme vaut pour les recuperations.
local attributs = {}
for _, a in ipairs(LCM.Campement.Attributs(T.Get("tente_l"))) do attributs[a.cle] = a.valeur end
attendu("securite de la tente", attributs.securite, -20)
attendu("armure apportee par l'accessoire inclus", attributs.recup_armure, 40)
attendu("sans tente, rien", LCM.Campement.Attributs(nil)[1].valeur, 0)

dire("== un jeu « custom » : les quatre valeurs du camp, rien d'autre")
-- Ce que l'editeur de jeux du MJ liste quand un jeu vise les tentes ou les
-- accessoires (MJ/Forge.lua lit Forge.Champs).
for _, categorie in ipairs({ "tentes", "accessoires_camping" }) do
    local noms = {}
    for _, champ in ipairs(F.Champs(categorie)) do noms[#noms + 1] = champ.label end
    attendu(categorie .. " : les quatre valeurs", table.concat(noms, ", "),
        "Sécurité (%), Fatigue (%), Soin (%), Armure (%)")
end
local cibles = {}
for _, categorie in ipairs(C.categories) do
    if categorie.statistiques == "bonus" and categorie.famille then cibles[categorie.id] = true end
end
attendu("les tentes sont une categorie cible", cibles.tentes, true)
attendu("les accessoires aussi", cibles.accessoires_camping, true)

dire("== la forge dose les statistiques du campement")
ok = B.Enregistrer("jeux", { id = "creation_tente", label = "Création de tente", categorie = "tentes",
    raretes = { { id = "commun", label = "Commun", points = 50, couleur = "FFFFFF" } },
    champs = { securite = { cout = 1 }, recup_pv = { cout = 1 } } }, true)
attendu("un jeu peut viser les tentes", ok, true)
ok, err = B.Enregistrer("tentes", { id = "sans_jeu", label = "Sans jeu", bonus = { securite = 10 } }, true)
attendu("des lors, une tente sans jeu est refusee", ok, false)
ok, err = B.Enregistrer("tentes", { id = "chere", label = "Chère", forge = "creation_tente/commun",
    bonus = { securite = 40, recup_pv = 30 } }, true)
attendu("70 pts pour un pool de 50 refuse", ok, false)
contient("     raison", err, "pool Commun")
ok = B.Enregistrer("tentes", { id = "juste", label = "Juste", forge = "creation_tente/commun",
    bonus = { securite = 30, recup_pv = 20 } }, true)
attendu("50 pts acceptes", ok, true)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
