-- Consommer un consommable (le MJ, 23 octobre 2026, Core/Consommation.lua).
--
-- Ce que ce scenario tient :
--   * les criteres : chaque jauge du personnage se dose a la forge comme une
--     statistique (« rend:pv », « rend:fatigue »...) ;
--   * une jauge unique se remplit d'un coup ; les PV se repartissent par zone,
--     au choix de celui qui consomme, et rien ne se consomme tant que la
--     repartition n'est pas juste ;
--   * l'etat pose porte les statistiques, avec son type, sa description et sa
--     duree ; sans etat, une statistique est refusee a l'enregistrement ;
--   * la forge regle l'etat dans son panneau ;
--   * administrer a un allie : il accepte, l'effet s'applique chez lui, et
--     l'exemplaire ne quitte le sac de celui qui donne qu'a ce moment.
--
-- Tout se pose sur du contenu TEMOIN : une race sans bonus, des consommables
-- d'essai.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = obtenu == voulu
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

local B = LCM.Brouillons
B.Set("races", { id = "temoin", label = "Témoin", morphology = "humanoide" })
B.Set("sacs", { id = "sac_conso", label = "Sac d'essai", places = 8 })
B.Set("consommables", { id = "potion_soin", label = "Potion de soin", bonus = { ["rend:pv"] = 5 } })
B.Set("consommables", { id = "potion_vigueur", label = "Potion de vigueur", bonus = { ["rend:fatigue"] = 5 } })
B.Set("consommables", { id = "soupe", label = "Soupe de tomate",
    bonus = { resi_vent = 5, resi_eau = 5, ["rend:fatigue"] = 2 },
    etatApplique = { conteneur = "maladie", nom = "Ventre plein", description = "Une chaleur douce.", rounds = 3 } })
__declencher("PLAYER_LOGIN")
__personnage()

local C, K, I = LCM.Compendium, LCM.Consommation, LCM.Inventaire
local moi = LCM.Entities.Self()
LCM.Entities.Set_Value(moi, "race", "temoin")
LCM.Entities.Set_Value(moi, "niveau", 5)
LCM.Entities.Set_Value(moi, "constitution", 4)
I.Poser(moi, "sacs", 1, "sac_conso")
I.Ranger(moi, "sacs", 1, 1, "consommables/potion_soin", 3)
I.Ranger(moi, "sacs", 1, 2, "consommables/potion_vigueur", 1)
I.Ranger(moi, "sacs", 1, 3, "consommables/soupe", 1)
local function Combien(ref) return LCM.Prix.Avoir(moi, ref) end

dire("== Les criteres")
local cat = C.Get("consommables")
local cles = {}
for _, champ in ipairs(LCM.Forge.Statistiques(cat)) do cles[champ.cle] = champ end
for _, critere in ipairs(K.CRITERES) do
    attendu("la forge dose " .. critere.label, cles["rend:" .. critere.id] ~= nil, true)
end
attendu("  dans le dossier Critères", cles["rend:pv"].dossier, "Critères")
attendu("  et toujours les statistiques", cles.resi_vent ~= nil, true)
attendu("les criteres sont des champs connus (aucune alerte au demarrage)", (function()
    for _, l in ipairs(__sorties) do if l:find("champ inconnu %(rend:") then return false end end
    return true
end)(), true)

dire("== Une jauge unique se remplit d'un coup")
local avant = LCM.Entities.Gauge(moi, "fatigue")
LCM.Entities.SetGauge(moi, "fatigue", avant.max - 10)
local bilan = K.Consommer(moi, "consommables/potion_vigueur")
attendu("consommee", bilan ~= nil, true)
attendu("+5 en fatigue", LCM.Entities.Gauge(moi, "fatigue").current, avant.max - 5)
attendu("le message le dit", K.Texte(bilan), "« Potion de vigueur » : +5 Fatigue (PF).")
attendu("l'exemplaire est parti", Combien("consommables/potion_vigueur"), 0)
attendu("plus rien a consommer", select(2, K.Consommer(moi, "consommables/potion_vigueur")),
    "il n'est plus dans tes sacs.")

dire("== Les PV se repartissent")
LCM.Body.Damage(moi, "buste", 4)
LCM.Body.Damage(moi, "bras", 6)
local function Zone(id) for _, z in ipairs(LCM.Body.State(moi)) do if z.id == id then return z end end end
local bras, buste = Zone("bras"), Zone("buste")
attendu("sans repartition : refuse", select(2, K.Consommer(moi, "consommables/potion_soin")),
    "il reste 5 PV à répartir.")
attendu("  rien n'est consomme", Combien("consommables/potion_soin"), 3)
attendu("trop sur une zone : refuse", (K.Consommer(moi, "consommables/potion_soin", { buste = 5 })), nil)
attendu("plus que la potion : refuse", (K.Consommer(moi, "consommables/potion_soin", { buste = 4, bras = 2 })), nil)
bilan = K.Consommer(moi, "consommables/potion_soin", { buste = 2, bras = 3 })
attendu("2 au torse, 3 au bras : accepte", bilan ~= nil, true)
attendu("  le torse", Zone("buste").current, buste.current + 2)
attendu("  le bras", Zone("bras").current, bras.current + 3)
attendu("  une potion en moins", Combien("consommables/potion_soin"), 2)

dire("== La fenetre de repartition")
local Rp = LCM.UI.Repartition
attendu("le sac propose « Consommer »", LCM.UI.Consommation ~= nil, true)
LCM.UI.Consommation.Consommer(moi, "consommables/potion_soin")
local f = LCM.UI.repartition
attendu("elle s'ouvre", f and f:IsShown(), true)
attendu("  et dit combien", f.phrase:GetText(), "Vous disposez de 5 PV à répartir.")
local rangBras
for i, ligne in ipairs(f.demande.lignes) do if ligne.id == "bras" then rangBras = i end end
attendu("valider est grise tant qu'il reste", f.valider:IsEnabled(), false)
-- Le bras n'a plus que 3 de place : le reste va au torse.
for _ = 1, 5 do f.lignes[rangBras].plus:Click() end
attendu("le bras s'arrete a sa place", f.parts.bras, 3)
attendu("  il reste 2", f:Reste(), 2)
local rangBuste
for i, ligne in ipairs(f.demande.lignes) do if ligne.id == "buste" then rangBuste = i end end
f.lignes[rangBuste].plus:Click()
f.lignes[rangBuste].plus:Click()
attendu("tout est place : valider s'allume", f.valider:IsEnabled(), true)
f.valider:Click()
attendu("la fenetre se ferme", f:IsShown(), false)
attendu("le bras est plein", Zone("bras").current, Zone("bras").max)
attendu("une potion en moins", Combien("consommables/potion_soin"), 1)
-- Une zone blessee, sinon il n'y a rien a repartir et la potion se boit
-- sans fenetre.
LCM.Body.Damage(moi, "tete", 2)
LCM.UI.Consommation.Consommer(moi, "consommables/potion_soin")
attendu("la fenetre se rouvre", f:IsShown(), true)
f:Hide()   -- annule
attendu("annuler ne consomme rien", Combien("consommables/potion_soin"), 1)

dire("== L'etat pose porte les statistiques")
bilan = K.Consommer(moi, "consommables/soupe")
attendu("consommee", bilan ~= nil, true)
local etats = LCM.EtatsTemporaires.Liste(moi, "maladie")
attendu("un etat dans les maladies", #etats, 1)
attendu("  son nom", etats[1] and etats[1].nom, "Ventre plein")
attendu("  sa description", etats[1] and etats[1].description, "Une chaleur douce.")
attendu("  sa duree", etats[1] and etats[1].restant, 3)
attendu("  il ne porte que les statistiques", etats[1] and etats[1].bonus["rend:fatigue"], nil)
attendu("+5 resistance au vent", LCM.Effets.Bonus(moi, "resi_vent"), 5)
attendu("+5 resistance a l'eau", LCM.Effets.Bonus(moi, "resi_eau"), 5)
attendu("le message dit l'etat", K.Texte(bilan):find("état « Ventre plein »") ~= nil, true)

dire("== Les regles de l'enregistrement")
-- Hors des jeux de la seance : depuis qu'un jeu vise les consommables, tout
-- enregistrement sans rarete est d'abord refuse POUR CELA, et ce n'est pas la
-- regle qu'on verifie ici (24 octobre 2026).
__sansJeux("consommables", function()
    local refus, raison = B.Enregistrer("consommables",
        { id = "soupe_sans_etat", label = "Soupe sans état", bonus = { resi_vent = 5 } }, true)
    attendu("une statistique sans etat : refusee", refus, false)
    attendu("  et on dit pourquoi", tostring(raison):find("passent par l'état") ~= nil, true)
    attendu("un critere sans etat : accepte",
        (B.Enregistrer("consommables", { id = "eau", label = "Eau", bonus = { ["rend:fatigue"] = 1 } }, true)), true)
    attendu("un type d'etat inconnu : refuse", (B.Enregistrer("consommables",
        { id = "x", label = "X", etatApplique = { conteneur = "bizarre" } }, true)), false)
    attendu("une duree illisible : refusee", (B.Enregistrer("consommables",
        { id = "y", label = "Y", etatApplique = { conteneur = "etat", rounds = "deux" } }, true)), false)
end)

dire("== La forge regle l'etat")
-- Les jeux d'equilibrage de la seance restent dehors (__sansJeux) : depuis que
-- le MJ en a forge pour les consommables, deux jeux etaient en vue et la forge
-- n'en choisissait aucun (24 octobre 2026). Un scenario ne se tient pas sur le
-- contenu de la seance.
local F = LCM.UI.Forge
__sansJeux("consommables", function()
    LCM.Forge.Add({
        id = "jeu_conso_temoin", label = "Consommables témoin", categorie = "consommables",
        raretes = { { id = "commun", label = "Commun", points = 20, couleur = "FFFFFF" } },
        champs = { ["rend:pv"] = { cout = "1", base = "0", max = "10" },
                   resi_vent = { cout = "1", base = "0", max = "10" } },
    })
    attendu("la forge s'ouvre", F.Ouvrir("consommables"), true)
    local fe = F.Fenetre()
    attendu("le panneau « État posé » est la", fe.panelEtat:IsShown(), true)
    attendu("  case decochee au depart", fe.panelEtat.pose:EstCochee(), false)
    F.courant.nom = "Infusion"
    F.courant.valeurs.resi_vent = 3
    local cree, motif = F.Creer()
    attendu("une statistique sans etat : la forge refuse", cree, false)
    attendu("  avec la raison", tostring(motif):find("passent par l'état") ~= nil, true)
    fe.panelEtat.pose:Click()
    attendu("cocher la case", F.courant.etat.pose, true)
    F.courant.etat.conteneur, F.courant.etat.nom = "intangible", "Esprit clair"
    F.courant.etat.description, F.courant.etat.rounds = "Les idées se posent.", "2"
    local element
    cree, element = F.Creer()
    attendu("avec l'etat : cree", cree, true)
    attendu("  l'etat est enregistre", element and element.etatApplique and element.etatApplique.conteneur, "intangible")
    attendu("  sa duree", element and element.etatApplique.rounds, 2)
    attendu("  la carte le resume", C.Get("consommables").lire.etatPose(element), "Intangible « Esprit clair », 2 round(s)")
    F.OuvrirEdition(C.Get("consommables"), LCM.Consommables.Get("soupe"))
    attendu("reprise : la case est cochee", F.courant.etat.pose, true)
    attendu("  le nom revient", F.courant.etat.nom, "Ventre plein")
    attendu("  la duree aussi", F.courant.etat.rounds, "3")
    fe:Hide()
end)

dire("== Administrer a un allie")
__groupe({ "Nytherah-Apertus" })
__reseauBoucle(true, "Nytherah-Apertus")
I.Ranger(moi, "sacs", 1, 4, "consommables/potion_vigueur", 2)
LCM.Entities.SetGauge(moi, "fatigue", 0)
attendu("la demande part", LCM.UI.Consommation.Administrer(moi, "Nytherah-Apertus", "consommables/potion_vigueur"), true)
local accord = LCM.UI.Consommation.accord
attendu("l'allie doit accepter", accord and accord:IsShown(), true)
attendu("  il lit ce qu'il recoit", (accord.texte:GetText() or ""):find("%+5 Fatigue") ~= nil, true)
attendu("rien n'a quitte le sac", Combien("consommables/potion_vigueur"), 2)
accord.oui:Click()
attendu("l'effet est applique chez l'allie", LCM.Entities.Gauge(moi, "fatigue").current, 5)
attendu("l'exemplaire part a sa reponse", Combien("consommables/potion_vigueur"), 1)
LCM.UI.Consommation.Administrer(moi, "Nytherah-Apertus", "consommables/potion_vigueur")
accord.non:Click()
attendu("refuse : l'exemplaire reste", Combien("consommables/potion_vigueur"), 1)
attendu("  et l'effet ne s'applique pas", LCM.Entities.Gauge(moi, "fatigue").current, 5)
__reseauBoucle(false)
attendu("hors du groupe : refuse",
    select(2, K.Administrer(moi, "Inconnu-Apertus", "consommables/potion_vigueur")), "ce joueur n'est pas dans le groupe.")

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
