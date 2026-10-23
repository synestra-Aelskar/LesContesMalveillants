-- Le transfert d'une categorie a une autre (le MJ, 23 octobre 2026,
-- LesContesMalveillants_MJ/Transfert.lua).
--
-- Ce que ce scenario tient :
--   * glisser un TYPE de « Liste ressources » sur « Liste consommable » le
--     change de liste, et emmene les ressources de ce type dans Consommables,
--     avec leur identifiant ;
--   * memes champs et rien a reprendre : tout passe sans panneau ;
--   * un jeu d'equilibrage qui ne vise pas l'arrivee : le panneau de chaque
--     entree s'ouvre, UN A LA FOIS, et un panneau ferme sans enregistrer
--     laisse l'entree a sa place ;
--   * une entree seule passe aussi, par l'editeur quand son type n'existe pas
--     a l'arrivee ;
--   * rien ne se perd : un sac qui tenait « ressources/x » le retrouve, le
--     compte et l'empile avec « consommables/x ».
--
-- Tout se pose sur du contenu TEMOIN, et les jeux d'equilibrage de la
-- campagne qui visent ces categories sont ecartes : c'est du contenu qui vit.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = obtenu == voulu
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

local B = LCM.Brouillons
B.Set("listes", { id = "t_bandage", label = "Bandage témoin", liste = "ressources" })
B.Set("listes", { id = "t_baume", label = "Baume témoin", liste = "ressources" })
B.Set("listes", { id = "t_minerai", label = "Minerai témoin", liste = "ressources" })
B.Set("listes", { id = "t_vide", label = "Type sans entrée", liste = "ressources" })
B.Set("ressources", { id = "r_bandage", label = "Bandage de lin", type = "t_bandage", description = "Une bande." })
B.Set("ressources", { id = "r_bandage_bis", label = "Bandage de soie", type = "t_bandage" })
B.Set("ressources", { id = "r_baume", label = "Baume de souci", type = "t_baume" })
B.Set("ressources", { id = "r_baume_bis", label = "Baume de suie", type = "t_baume" })
B.Set("ressources", { id = "r_fer", label = "Fer", type = "t_minerai" })
B.Set("sacs", { id = "sac_transfert", label = "Sac d'essai", places = 8 })
-- Un coffre qui cite le bandage : le transfert doit le suivre.
B.Set("points", { id = "coffre_bandages", label = "Coffre à bandages", nature = "coffre",
    coffre = { places = 2, objets = { { entree = "ressources/r_bandage", quantite = 2 } } } })
-- Un coffre qui cite un consommable encore dans la file d'envoi : au
-- chargement, les points se lisent AVANT les consommables. Il doit attendre,
-- pas perdre sa ligne.
B.Set("consommables", { id = "c_tardif", label = "Consommable tardif" })
B.Set("points", { id = "coffre_tardif", label = "Coffre tardif", nature = "coffre",
    coffre = { places = 1, objets = { { entree = "consommables/c_tardif", quantite = 1 } } } })
__declencher("PLAYER_LOGIN")
__personnage()

local C, T = LCM.Compendium, LCM.Transfert
for rang = #LCM.Forge.list, 1, -1 do
    local jeu = LCM.Forge.list[rang]
    if jeu.categorie == "ressources" or jeu.categorie == "consommables" then LCM.Forge.Retirer(jeu.id) end
end
local function Objet(categorie, element) return { categorie = categorie, element = element } end

dire("== Un coffre attend ce que la file d'envoi rejoue")
local tardif = LCM.Points.Get("coffre_tardif")
attendu("le coffre est la", tardif ~= nil, true)
attendu("  sa ligne est retrouvee", tardif and tardif.coffre.objets[1] and tardif.coffre.objets[1].entree,
    "consommables/c_tardif")
attendu("  rien n'attend plus", tardif and tardif.coffre.laisses, nil)
-- Une ligne introuvable reste en attente, et revient avec l'entree. (Un coffre
-- dont TOUT manque, lui, tombe hors du chargement : regle du 20 octobre,
-- tenue par lcm_test_coffre_objet_supprime.)
local ok = B.Enregistrer("points", { id = "coffre_attente", label = "Coffre en attente", nature = "coffre",
    coffre = { places = 2, objets = { { entree = "consommables/c_tardif", quantite = 1 },
                                      { entree = "consommables/pas_encore", quantite = 1 } } } }, true)
attendu("un coffre a qui il manque une ligne reste pose", ok, true)
local attente = LCM.Points.Get("coffre_attente")
attendu("  sa ligne est gardee", attente.coffre.laisses and attente.coffre.laisses[1].entree, "consommables/pas_encore")
attendu("  et survit a un enregistrement", (B.Enregistrer("points", LCM.Copie(attente), false)), true)
attendu("  toujours la", LCM.Points.Get("coffre_attente").coffre.laisses[1].entree, "consommables/pas_encore")
B.Enregistrer("consommables", { id = "pas_encore", label = "Enfin là" }, true)
LCM.Points.Relire()
attendu("l'entree creee, la ligne revient", LCM.Points.Get("coffre_attente").coffre.objets[2]
    and LCM.Points.Get("coffre_attente").coffre.objets[2].entree, "consommables/pas_encore")

dire("== Ce qui se lache, et ou")
local bandage = LCM.Listes.Get("t_bandage")
attendu("un type sur une autre liste", T.Accepte(Objet("liste_ressources", bandage), C.Get("liste_consommables")), true)
attendu("pas sur sa propre liste", (T.Accepte(Objet("liste_ressources", bandage), C.Get("liste_ressources"))), false)
attendu("pas sur une categorie d'entrees", (T.Accepte(Objet("liste_ressources", bandage), C.Get("consommables"))), false)
attendu("une ressource sur les consommables",
    T.Accepte(Objet("ressources", LCM.Ressources.Get("r_fer")), C.Get("consommables")), true)
attendu("pas sur les traits", (T.Accepte(Objet("ressources", LCM.Ressources.Get("r_fer")), C.Get("traits"))), false)
attendu("pas les metiers (figes dans le code)",
    (T.Accepte(Objet("liste_metiers", LCM.Metiers.list[1]), C.Get("liste_ressources"))), false)

dire("== Un sac tient deja un bandage")
local I, moi = LCM.Inventaire, LCM.Entities.Self()
attendu("le sac se pose", I.Poser(moi, "sacs", 1, "sac_transfert"), true)
attendu("deux bandages ranges", I.Ranger(moi, "sacs", 1, 1, "ressources/r_bandage", 2), true)

dire("== Un type sans entree : rien a reprendre")
local plan = T.Plan(Objet("liste_ressources", LCM.Listes.Get("t_vide")), C.Get("liste_consommables"))
attendu("une seule etape", plan and #plan.etapes, 1)
attendu("  sans panneau", plan and plan.question:find("Rien à modifier") ~= nil, true)
T.Lancer(plan)
attendu("  il a change de liste", LCM.Listes.Get("t_vide").liste, "consommables")

dire("== Glisser « Bandage » sur « Liste consommable » : la forge pour chacun")
-- Depuis les criteres (23 octobre 2026), Ressources et Consommables n'ont
-- plus les memes champs : chaque ressource qui passe demande son panneau,
-- c'est la regle « builders differents ». Il faut donc un jeu a l'arrivee.
LCM.Forge.Add({
    id = "jeu_conso_transfert", label = "Consommables témoin", categorie = "consommables",
    raretes = { { id = "commun", label = "Commun", points = 10, couleur = "FFFFFF" } },
    champs = { ["rend:pv"] = { cout = "1", base = "0", max = "5" } },
})
local F = LCM.UI.Forge
local function ValiderForge()
    F.courant.jeuId, F.courant.rareteId = "jeu_conso_transfert", "commun"
    local ok, raison = F.Creer()
    if not ok then dire("     forge : " .. tostring(raison)) end
    __avancer(0.1)
    return ok
end
LCM.UI.Menu.Trouver("systeme_aelskar").onClick()
local f = LCM.UI.Compendium.frame
local bouton
for _, b in ipairs(f.boutonsCategories) do if b.categorieId == "liste_consommables" then bouton = b end end
attendu("le bouton est une cible", bouton.glisserAccepte ~= nil, true)
attendu("il accepte le type", bouton.glisserAccepte(Objet("liste_ressources", bandage)), true)
bouton.glisserDepose(Objet("liste_ressources", bandage))
attendu("rien ne bouge avant d'accepter", LCM.Listes.Get("t_bandage").liste, "ressources")
attendu("la confirmation est demandee", f.confirmationTransfert:IsShown(), true)
local question = f.confirmationTransfert.texte:GetText() or ""
attendu("  elle dit que deux entrees suivent", question:find("2 entrée%(s%) de ce type suivent") ~= nil, true)
attendu("  et que les deux demandent la forge", question:find("2 demande%(nt%) une modification") ~= nil, true)
f.confirmationTransfert.oui:Click()
attendu("le type passe tout de suite", LCM.Listes.Get("t_bandage").liste, "consommables")
attendu("la forge s'ouvre sur le premier", F.Fenetre():IsShown() and F.courant.editionId, "r_bandage")
attendu("  il est valide", ValiderForge(), true)
attendu("puis sur le second", F.Fenetre():IsShown() and F.courant.editionId, "r_bandage_bis")
attendu("  il est valide", ValiderForge(), true)
attendu("le type a change de liste", LCM.Listes.Get("t_bandage").liste, "consommables")
attendu("le bandage est un consommable", LCM.Consommables.Get("r_bandage") ~= nil, true)
attendu("  le meme identifiant, la meme description", LCM.Consommables.Get("r_bandage").description, "Une bande.")
attendu("  il n'est plus une ressource", LCM.Ressources.Get("r_bandage"), nil)
attendu("  il se souvient d'ou il vient", LCM.Consommables.Get("r_bandage").transfertDe[1], "ressources/r_bandage")
attendu("l'autre bandage aussi", LCM.Consommables.Get("r_bandage_bis") ~= nil, true)
attendu("le baume n'a pas bouge", LCM.Ressources.Get("r_baume") ~= nil, true)
attendu("aucun transfert ne reste en cours", T.EnCours(), false)
attendu("la suppression part vers la base", B.EstMasquee("ressources", "r_bandage"), true)
attendu("le coffre qui le citait suit", LCM.Points.Get("coffre_bandages").coffre.objets[1].entree,
    "consommables/r_bandage")
attendu("  sans rien laisser de cote", LCM.Points.Get("coffre_bandages").coffre.laisses, nil)

dire("== Rien ne s'est perdu dans le sac")
attendu("l'ancienne reference se resout", (C.Resoudre("ressources/r_bandage")), LCM.Consommables.Get("r_bandage"))
attendu("  sous son nom d'aujourd'hui", C.Canonique("ressources/r_bandage"), "consommables/r_bandage")
attendu("une reference ordinaire ne change pas", C.Canonique("ressources/r_fer"), "ressources/r_fer")
attendu("le sac en compte deux", LCM.Prix.Avoir(moi, "consommables/r_bandage"), 2)
attendu("un troisieme s'empile sur eux", I.Deposer(moi, "consommables/r_bandage", 1), true)
attendu("  dans la meme case", I.Case(I.Emplacement(moi, "sacs", 1), 1).quantite, 3)
attendu("  rien dans la case voisine", I.Case(I.Emplacement(moi, "sacs", 1), 2), nil)
attendu("on peut en prendre un", I.Prendre(moi, "consommables/r_bandage"), true)

dire("== « Baume » : un panneau a la fois, et un panneau ferme")
local baume = LCM.Listes.Get("t_baume")
plan = T.Plan(Objet("liste_ressources", baume), C.Get("liste_consommables"))
attendu("trois etapes : le type et ses deux baumes", plan and #plan.etapes, 3)
attendu("le type passe tel quel", plan and plan.etapes[1].raisons[1], nil)
attendu("le baume demande une modification",
    plan and table.concat(plan.etapes[2].raisons, " ; "):find("jeu d'équilibrage") ~= nil, true)
local ok = T.Lancer(plan)
attendu("lance", ok, true)
attendu("le type est deja passe", LCM.Listes.Get("t_baume").liste, "consommables")
attendu("la forge s'ouvre", F.Fenetre():IsShown(), true)
attendu("  sur le premier baume", F.courant.editionId, "r_baume")
attendu("  avec son type", F.courant.type, "t_baume")
attendu("le transfert attend", T.EnCours(), true)
F.courant.jeuId, F.courant.rareteId = "jeu_conso_transfert", "commun"
attendu("le MJ enregistre", (F.Creer()), true)
attendu("le premier baume est passe", LCM.Consommables.Get("r_baume") ~= nil, true)
attendu("  avec son nouveau jeu", LCM.Consommables.Get("r_baume").forge, "jeu_conso_transfert/commun")
attendu("  et plus parmi les ressources", LCM.Ressources.Get("r_baume"), nil)
attendu("la forge se referme", F.Fenetre():IsShown(), false)
attendu("le second n'est pas encore ouvert", T.EnCours(), true)
__avancer(0.1)
attendu("le second s'ouvre ensuite", F.Fenetre():IsShown() and F.courant.editionId, "r_baume_bis")
F.Fenetre():Hide()   -- ferme sans enregistrer
__avancer(0.1)
attendu("le transfert est fini", T.EnCours(), false)
attendu("le second reste une ressource", LCM.Ressources.Get("r_baume_bis") ~= nil, true)
attendu("  et n'est pas un consommable", LCM.Consommables.Get("r_baume_bis"), nil)

dire("== Une entree seule, par l'editeur")
-- Le bandage de soie revient aux ressources : son type est reste dans la
-- liste consommable, l'editeur s'ouvre pour en choisir un.
local soie = LCM.Consommables.Get("r_bandage_bis")
plan = T.Plan(Objet("consommables", soie), C.Get("ressources"))
attendu("une etape", plan and #plan.etapes, 1)
attendu("  qui demande un type", plan and table.concat(plan.etapes[1].raisons, " ; "):find("type") ~= nil, true)
attendu("lance", (T.Lancer(plan)), true)
local ed = LCM.CompendiumEditeur.frame
attendu("l'editeur s'ouvre", ed and ed:IsShown(), true)
attendu("  sur le bandage", ed and ed.travail.e.id, "r_bandage_bis")
attendu("  dans les ressources", ed and ed.travail.categorie.id, "ressources")
ed.travail.e.type = "t_minerai"
ed:Valider()
__avancer(0.1)
attendu("il est revenu aux ressources", LCM.Ressources.Get("r_bandage_bis") and LCM.Ressources.Get("r_bandage_bis").type,
    "t_minerai")
attendu("  et a quitte les consommables", LCM.Consommables.Get("r_bandage_bis"), nil)
attendu("  sans se citer lui-meme", table.concat(LCM.Ressources.Get("r_bandage_bis").transfertDe, ","),
    "consommables/r_bandage_bis")
attendu("le transfert est fini", T.EnCours(), false)

dire("== Ce qui ne se fait pas a moitie")
-- Sans jeu d'equilibrage a l'arrivee, la forge ne sait rien enregistrer : on
-- le dit avant de commencer, rien ne bouge.
dire("== La carte nomme le jeu, meme venu d'une autre categorie")
local function ChampForge(categorie)
    for _, champ in ipairs(C.Champs(categorie)) do if champ.cle == "forge" then return champ end end
end
attendu("un jeu des consommables, lu depuis les ressources",
    C.Texte(C.Get("ressources"), ChampForge(C.Get("ressources")), "jeu_conso_transfert/commun", "full"),
    "Consommables témoin · Commun")
attendu("un jeu disparu ne s'affiche pas",
    C.Texte(C.Get("ressources"), ChampForge(C.Get("ressources")), "lcm_inconnu/commun", "full"), "")

LCM.Forge.Retirer("jeu_conso_transfert")
B.Enregistrer("ressources", { id = "r_bizarre", label = "Bizarre", type = "t_inconnu_ici" }, true)
local refus, raison = T.Plan(Objet("ressources", LCM.Ressources.Get("r_bizarre")), C.Get("consommables"))
attendu("refuse avant de commencer", refus, nil)
attendu("  et dit pourquoi", tostring(raison):find("aucun jeu d'équilibrage") ~= nil, true)
attendu("  rien n'a bouge", LCM.Ressources.Get("r_bizarre") ~= nil, true)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
