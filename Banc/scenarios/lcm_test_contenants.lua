-- Les outils contenants (le MJ, 23 octobre 2026, Core/Contenants.lua).
--
-- Ce que ce scenario tient :
--   * le contenant se declare dans la definition d'un outil (taille, retrait
--     par usage, types acceptes, contenu de depart), et seulement d'un outil ;
--   * une dose remplit : verser une Eau porte la gourde a sa taille, chaque
--     usage applique l'effet entier et retire le retrait ;
--   * une seule sorte a la fois, et seulement les types acceptes ;
--   * un outil nait plein si la forge le dit ;
--   * une ressource contenue reste accessible : un paiement la voit et la prend ;
--   * la forge des outils regle le contenant.
--
-- Tout se pose sur du contenu TEMOIN.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = obtenu == voulu
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

local B = LCM.Brouillons
B.Set("races", { id = "temoin", label = "Témoin", morphology = "humanoide" })
B.Set("listes", { id = "t_boisson", label = "Boisson témoin", liste = "consommables" })
B.Set("listes", { id = "t_soin", label = "Soin témoin", liste = "consommables" })
B.Set("listes", { id = "t_bave", label = "Bave témoin", liste = "ressources" })
B.Set("consommables", { id = "eau", label = "Eau", type = "t_boisson", bonus = { ["rend:fatigue"] = 4 } })
B.Set("consommables", { id = "soin", label = "Potion de soin", type = "t_soin", bonus = { ["rend:pv"] = 5 } })
B.Set("ressources", { id = "bave", label = "Bave de dragon", type = "t_bave" })
B.Set("objets", { id = "gourde", label = "Gourde", categorie = "outil",
    contenant = { taille = 100, retrait = 20, types = { "t_boisson" } } })
B.Set("objets", { id = "gourde_pleine", label = "Gourde d'eau", categorie = "outil",
    contenant = { taille = 100, retrait = 50, types = { "t_boisson" }, depart = "consommables/eau" } })
B.Set("objets", { id = "fiole", label = "Fiole de prélèvement", categorie = "outil",
    contenant = { taille = 1, retrait = 1, types = { "t_bave" } } })
B.Set("objets", { id = "gourde_runique", label = "Gourde runique", categorie = "outil",
    transfertDe = { "ressources/gourde_runique", "consommables/gourde_runique" },
    contenant = { taille = 100, retrait = 20, types = { "t_boisson" } } })
B.Set("sacs", { id = "sac_contenants", label = "Sac d'essai", places = 10 })
__declencher("PLAYER_LOGIN")
__personnage()

local K, I, C = LCM.Contenants, LCM.Inventaire, LCM.Compendium
local moi = LCM.Entities.Self()
LCM.Entities.Set_Value(moi, "race", "temoin")
I.Poser(moi, "sacs", 1, "sac_contenants")
I.Ranger(moi, "sacs", 1, 1, "objets/gourde", 1)
I.Ranger(moi, "sacs", 1, 2, "consommables/eau", 2)
I.Ranger(moi, "sacs", 1, 3, "consommables/soin", 1)
I.Ranger(moi, "sacs", 1, 4, "objets/fiole", 1)
I.Ranger(moi, "sacs", 1, 5, "ressources/bave", 1)
local GOURDE, FIOLE = { onglet = "sacs", index = 1, case = 1 }, { onglet = "sacs", index = 1, case = 4 }
local function Exemplaire(ou) return I.Case(I.Emplacement(moi, ou.onglet, ou.index), ou.case).exemplaires[1] end
local function Combien(ref) return LCM.Prix.Avoir(moi, ref) end

dire("== Le modele")
local gourde = LCM.Objets.Get("gourde")
attendu("la gourde est un contenant", gourde.contenant and gourde.contenant.taille, 100)
attendu("  qui retire 20 par usage", gourde.contenant.retrait, 20)
attendu("  et n'accepte que les boissons", table.concat(gourde.contenant.types, ","), "t_boisson")
attendu("une arme ne contient rien", (B.Enregistrer("objets", { id = "epee_creuse", label = "Épée creuse",
    categorie = "arme", contenant = { taille = 1, retrait = 1 } }, true)), false)
local refus, raison = B.Enregistrer("objets", { id = "gourde_folle", label = "Gourde folle", categorie = "outil",
    contenant = { taille = 10, retrait = 20 } }, true)
attendu("un retrait plus grand que la taille : refuse", refus, false)
attendu("  et on dit pourquoi", tostring(raison):find("plus que le contenant") ~= nil, true)
attendu("la carte resume le contenant", C.Get("outils").lire.contenantResume(gourde),
    "Boisson témoin — taille 100, 20 par usage")

dire("== Ce qu'elle accepte")
attendu("l'eau", K.Accepte(gourde, "consommables/eau"), true)
attendu("pas la potion", (K.Accepte(gourde, "consommables/soin")), false)
attendu("  et on dit pourquoi", select(2, K.Accepte(gourde, "consommables/soin")),
    "« Gourde » n'accepte que : Boisson témoin.")
attendu("pas une arme", (K.Accepte(gourde, "objets/gourde")), false)
local versables = K.Versables(moi, GOURDE)
attendu("remplir propose l'eau, et seulement elle", #versables == 1 and versables[1].ref, "consommables/eau")

dire("== Une dose remplit")
attendu("vide au depart", K.Texte(gourde, Exemplaire(GOURDE)), "vide")
attendu("on verse une eau", K.Remplir(moi, GOURDE, "consommables/eau"), true)
attendu("  une eau de moins dans le sac", I.Case(I.Emplacement(moi, "sacs", 1), 2).quantite, 1)
attendu("  la gourde est pleine", K.Texte(gourde, Exemplaire(GOURDE)), "Eau, 100 %")
attendu("pleine, elle refuse", select(2, K.Remplir(moi, GOURDE, "consommables/eau")), "« Gourde » est déjà à 100 %.")
attendu("la potion n'y entre pas", (K.Remplir(moi, GOURDE, "consommables/soin")), false)

dire("== Chaque usage applique l'effet entier")
LCM.Entities.SetGauge(moi, "fatigue", 0)
local bilan = K.Utiliser(moi, GOURDE)
attendu("une gorgee", bilan ~= nil, true)
attendu("  +4 en fatigue", LCM.Entities.Gauge(moi, "fatigue").current, 4)
attendu("  il en reste 80 %", K.Texte(gourde, Exemplaire(GOURDE)), "Eau, 80 %")
for _ = 1, 4 do K.Utiliser(moi, GOURDE) end
attendu("cinq gorgees en tout", LCM.Entities.Gauge(moi, "fatigue").current, 20)
attendu("  et la voila vide", K.Texte(gourde, Exemplaire(GOURDE)), "vide")
attendu("vide, elle ne sert plus", select(2, K.Utiliser(moi, GOURDE)), "« Gourde » est vide.")
attendu("on la remplit de nouveau", K.Remplir(moi, GOURDE, "consommables/eau"), true)
attendu("on la vide", K.Vider(moi, GOURDE), true)
attendu("  et elle l'est", K.Texte(gourde, Exemplaire(GOURDE)), "vide")

dire("== Une seule sorte a la fois")
B.Set("consommables", { id = "lait", label = "Lait", type = "t_boisson", bonus = { ["rend:fatigue"] = 1 } })
LCM.Consommables.Add({ id = "lait", label = "Lait", type = "t_boisson", bonus = { ["rend:fatigue"] = 1 } })
I.Ranger(moi, "sacs", 1, 6, "consommables/lait", 1)
I.Ranger(moi, "sacs", 1, 2, "consommables/eau", 1)
K.Remplir(moi, GOURDE, "consommables/lait")
LCM.Contenants.Utiliser(moi, GOURDE)
attendu("du lait entame refuse l'eau", select(2, K.Remplir(moi, GOURDE, "consommables/eau")),
    "« Gourde » contient déjà autre chose : vide son contenu d'abord.")

dire("== Des boissons, mais uniquement de l'eau")
local seuleEau = { label = "Gourde à eau", contenant = { taille = 10, retrait = 1, types = { "t_boisson" },
    entrees = { "consommables/eau" } } }
attendu("l'eau passe", K.Accepte(seuleEau, "consommables/eau"), true)
attendu("le lait, boisson pourtant, non", select(2, K.Accepte(seuleEau, "consommables/lait")),
    "« Gourde à eau » n'accepte, en Boisson témoin, que : Eau.")
attendu("un type sans entree nommee reste entier", K.Accepte(gourde, "consommables/lait"), true)
-- Hors des jeux de la seance : depuis que le MJ en a forge un qui vise les
-- outils, un enregistrement sans rarete est refuse POUR CELA, et ce n'est pas
-- la regle qu'on verifie ici (24 octobre 2026).
__sansJeux("outils", function()
    attendu("la definition le garde", (B.Enregistrer("objets", { id = "gourde_eau", label = "Gourde à eau",
        categorie = "outil", contenant = seuleEau.contenant }, true)), true)
    attendu("la carte le dit", C.Get("outils").lire.contenantResume(LCM.Objets.Get("gourde_eau")),
        "Boisson témoin (Eau) — taille 10, 1 par usage")
end)

dire("== Une case d'avant le transfert")
-- La Gourde runique du MJ : ressource, puis consommable, puis outil. Sa case
-- la tenait encore sous « ressources/... » : elle s'affichait « (vide) » mais
-- n'avait aucun exemplaire, et refusait d'etre remplie (23 octobre 2026).
I.Emplacement(moi, "sacs", 1).cases[9] = { ref = "ressources/gourde_runique", quantite = 1 }
local RUNIQUE = { onglet = "sacs", index = 1, case = 9 }
I.Ranger(moi, "sacs", 1, 10, "consommables/eau", 1)
attendu("on la remplit", K.Remplir(moi, RUNIQUE, "consommables/eau"), true)
attendu("  sa case passe a sa reference d'aujourd'hui", I.Case(I.Emplacement(moi, "sacs", 1), 9).ref,
    "objets/gourde_runique")
attendu("  et elle est pleine", K.Texte(LCM.Objets.Get("gourde_runique"), Exemplaire(RUNIQUE)), "Eau, 100 %")

dire("== Livree pleine")
I.Ranger(moi, "sacs", 1, 7, "objets/gourde_pleine", 1)
local pleine = LCM.Objets.Get("gourde_pleine")
attendu("la gourde d'eau nait pleine",
    K.Texte(pleine, I.Case(I.Emplacement(moi, "sacs", 1), 7).exemplaires[1]), "Eau, 100 %")

dire("== Une ressource reste accessible")
attendu("la bave entre dans la fiole", K.Remplir(moi, FIOLE, "ressources/bave"), true)
attendu("  plus de bave dans le sac", I.Case(I.Emplacement(moi, "sacs", 1), 5), nil)
attendu("  mais on en a toujours une", Combien("ressources/bave"), 1)
attendu("elle ne s'utilise pas", select(2, K.Utiliser(moi, FIOLE)), "ce qu'il contient ne s'utilise pas : ça se transporte.")
attendu("un paiement la voit", LCM.Prix.Peut(moi, { { ref = "ressources/bave", quantite = 1 } }), true)
LCM.Prix.Payer(moi, { { ref = "ressources/bave", quantite = 1 } })
attendu("  et la prend dans la fiole", K.Texte(LCM.Objets.Get("fiole"), Exemplaire(FIOLE)), "vide")
attendu("  il n'en reste plus", Combien("ressources/bave"), 0)

dire("== Dans le sac")
LCM.UI.Menu.Trouver("inventaires").onClick()
local fi = LCM.UI.Inventaires.frame
fi:CarteDe("sacs", 1):Click("LeftButton")
attendu("l'outil dit ce qu'il contient", fi.lignes[7].nom:GetText(), "Gourde d'eau  (Eau, 100 %)")
attendu("  et vide, il le dit aussi", fi.lignes[4].nom:GetText(), "Fiole de prélèvement  (vide)")
fi.lignes[7]:Click("RightButton")
local menu = LCM.UI.MenuContexte()
local libelles = {}
for _, l in ipairs(menu.lignes) do if l:IsShown() then libelles[#libelles + 1] = l.texte:GetText() end end
local options = table.concat(libelles, ",")
attendu("le menu propose de s'en servir", options:find("Utiliser %(Eau%)") ~= nil, true)
attendu("  de le remplir", options:find("Remplir avec") ~= nil, true)
attendu("  et de le vider", options:find("Vider") ~= nil, true)
for _, l in ipairs(menu.lignes) do
    if l:IsShown() and l.texte:GetText() == "Utiliser (Eau)" then l:Click() end
end
attendu("Utiliser : une gorgee bue", K.Texte(pleine, I.Case(I.Emplacement(moi, "sacs", 1), 7).exemplaires[1]), "Eau, 50 %")
attendu("  et la ligne suit", fi.lignes[7].nom:GetText(), "Gourde d'eau  (Eau, 50 %)")
fi:Hide()

dire("== La forge des outils regle le contenant")
LCM.Forge.Add({
    id = "jeu_outils_contenant", label = "Outils témoin", categorie = "outils",
    raretes = { { id = "commun", label = "Commun", points = 10, couleur = "FFFFFF" } },
    champs = {},
})
local F = LCM.UI.Forge
attendu("la forge s'ouvre", F.Ouvrir("outils"), true)
F.courant.jeuId, F.courant.rareteId = "jeu_outils_contenant", "commun"
local fe = F.Fenetre()
fe:Rafraichir()
attendu("le bouton Contenant est la", fe.contenant:IsShown(), true)
attendu("  il dit Non", fe.contenant.label:GetText(), "Non")
local g = F.OuvrirContenant()
attendu("son reglage s'ouvre", g:IsShown(), true)
attendu("  la taille est cachee tant que la case n'est pas cochee", g.taille:IsShown(), false)
g.actif:Click()
attendu("cocher montre la taille", g.taille:IsShown(), true)
attendu("le tableau est vide : tout passe", g.vide:IsShown(), true)
-- « Ajouter une entree » propose les types ; choisir Boisson ouvre son panneau.
local p = F.ChoisirType("t_boisson")
attendu("le panneau du type s'ouvre", p:IsShown(), true)
local function CaseDe(ref)
    for _, case in ipairs(p.cases) do if case:IsShown() and case.ref == ref then return case end end
end
attendu("  il montre l'eau et le lait", CaseDe("consommables/eau") ~= nil and CaseDe("consommables/lait") ~= nil, true)
p.recherche:Saisir("ea")
attendu("  la recherche trie", CaseDe("consommables/eau") ~= nil and CaseDe("consommables/lait") == nil, true)
p.tout:Click()
p.valider:Click()
attendu("tout le type : une ligne « (Tout) »", g.lignes[1]:IsShown() and __sansCouleur(g.lignes[1].texte:GetText()),
    "Boisson témoin  (Tout)")
attendu("  et rien d'autre", g.lignes[2] == nil or not g.lignes[2]:IsShown(), true)
attendu("  rien a choisir de plus", next(F.ContenantCourant().entrees), nil)
g.lignes[1].modifier:Click()
p = LCM.UI.Forge.fenetreChoixType
attendu("Modifier rouvre le panneau, en « tout »", p.tout:EstCochee(), true)
p.tout:Click()
p.recherche:Saisir("")
CaseDe("consommables/eau"):Click()
p.valider:Click()
attendu("seulement l'eau : sa ligne, son type a cote", __sansCouleur(g.lignes[1].texte:GetText()), "Eau  (Boisson témoin)")
attendu("  l'eau est retenue", F.ContenantCourant().entrees["consommables/eau"], true)
F.ContenantCourant().depart = "consommables/eau"
g:Rafraichir()
attendu("le depart se lit", g.depart.label:GetText(), "Eau")
-- La saisie en DERNIER, comme en jeu : rien d'autre ne redessine la forge
-- apres elle, c'est la fermeture du reglage qui doit le faire.
g.taille:Saisir("10")
g.retrait:Saisir("2")
g.ok:Click()
attendu("  le bouton resume", fe.contenant.label:GetText(), "Oui — 10, −2 par usage")
F.courant.nom = "Outre"
local cree, element = F.Creer()
attendu("l'outre est creee", cree, true)
attendu("  contenant de 10", element and element.contenant and element.contenant.taille, 10)
attendu("  qui retire 2", element and element.contenant.retrait, 2)
attendu("  que des boissons", element and table.concat(element.contenant.types or {}, ","), "t_boisson")
attendu("  livree avec de l'eau", element and element.contenant.depart, "consommables/eau")
attendu("  et rien que de l'eau", element and table.concat(element.contenant.entrees or {}, ","), "consommables/eau")
F.OuvrirEdition(C.Get("outils"), element)
attendu("reprise : le contenant revient", F.ContenantCourant().actif and F.ContenantCourant().taille, "10")
attendu("  avec son eau", F.ContenantCourant().entrees["consommables/eau"], true)
g = F.OuvrirContenant()
g.lignes[1].retirer:Click()
attendu("retirer la derniere eau retire le type", F.ContenantCourant().types["t_boisson"], nil)
attendu("  le tableau est vide", g.vide:IsShown(), true)
g:Hide()
fe:Hide()

dire("== Un type d'une autre liste")
-- La Gourde runique a garde « Boisson » en devenant un outil : la carte
-- affichait « ? lcm_... », la forge l'enregistrait sans rien dire.
local outil = LCM.Copie(element)
outil.type = "t_boisson"
local champType
for _, champ in ipairs(C.Champs(C.Get("outils"))) do if champ.cle == "type" then champType = champ end end
attendu("la carte le nomme et dit qu'il n'est pas a sa place",
    C.Texte(C.Get("outils"), champType, "t_boisson", "full"), "? Boisson témoin (pas dans cette liste)")
F.OuvrirEdition(C.Get("outils"), outil)
F.courant.jeuId, F.courant.rareteId = "jeu_outils_contenant", "commun"
fe:Rafraichir()
attendu("la forge le signale", (fe.type.label:GetText() or ""):find("pas un type d'ici") ~= nil, true)
local refuse, pourquoi = F.Creer()
attendu("  et refuse de l'enregistrer", refuse, false)
attendu("  en disant pourquoi", tostring(pourquoi):find("n'est pas un type de Outils") ~= nil, true)
fe:Hide()

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
