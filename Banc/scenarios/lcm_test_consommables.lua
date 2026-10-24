-- Les consommables (23 octobre 2026, le MJ) : bandages, baumes et boissons
-- quittent les ressources pour leur propre famille.
--
-- Ce que ce scenario tient :
--   * la « Liste consommable » et la categorie « Consommables » existent, et le
--     Type de l'une puise dans l'autre — pas dans la liste des ressources ;
--   * la forge cree un consommable avec son type, sous un jeu d'equilibrage
--     qui vise la categorie ;
--   * une fois cree, il se resout, se range dans un sac et dans un coffre, et
--     voyage par la base commune comme les autres familles.
--
-- Tout se pose sur des entrees TEMOINS : les types et consommables de la
-- campagne sont du contenu qui vit.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = obtenu == voulu
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

-- Les types temoins se posent avant la connexion, qui les charge.
LCM.Brouillons.Set("listes", { id = "temoin_bandage", label = "Bandage témoin", liste = "consommables" })
LCM.Brouillons.Set("listes", { id = "temoin_minerai", label = "Minerai témoin", liste = "ressources" })
__declencher("PLAYER_LOGIN")
local C = LCM.Compendium

local function Option(champ, id)
    for _, o in ipairs(C.Options(champ)) do if o.id == id then return true end end
    return false
end
local function ChampType(categorie)
    for _, champ in ipairs(C.Champs(categorie)) do
        if champ.cle == "type" then return champ end
    end
end

dire("== Les deux categories")
local liste = C.Get("liste_consommables")
attendu("« Liste consommable » existe", liste and liste.label, "Liste consommable")
attendu("  c'est une liste", liste and liste.type, "list")
local cat = C.Get("consommables")
attendu("« Consommables » existe", cat and cat.label, "Consommables")
attendu("  sa famille", cat and cat.famille, "consommables")
attendu("  son Type puise dans la liste consommable", ChampType(cat).source, "listes:consommables")
attendu("  elle a un champ Forge", (function()
    for _, champ in ipairs(C.Champs(cat)) do if champ.cle == "forge" then return true end end
    return false
end)(), true)

dire("== Un type de consommable n'est pas un type de ressource")
attendu("le bandage est dans la liste consommable",
    C.Entrees(liste)[1] ~= nil and Option(ChampType(cat), "temoin_bandage"), true)
attendu("  et pas parmi les types de ressources",
    Option(ChampType(C.Get("ressources")), "temoin_bandage"), false)
attendu("le minerai reste aux ressources", Option(ChampType(C.Get("ressources")), "temoin_minerai"), true)
attendu("  et n'est pas un consommable", Option(ChampType(cat), "temoin_minerai"), false)

dire("== La forge des consommables")
local F = LCM.UI.Forge
attendu("la forge sait creer un consommable", F.EstCategorie(cat), true)
attendu("son Type vient de la liste consommable", F.ListeDuType(cat), "consommables")
-- La seance a desormais ses propres jeux d'equilibrage pour les consommables
-- (le MJ en a cree, base regeneree le 24 octobre 2026). Un scenario ne se tient
-- pas sur le contenu de la seance : on les met de cote (__sansJeux), et la
-- forge ne voit que le jeu temoin. Sans cela, « sans jeu : refus » ne se
-- verifiait plus et, deux jeux etant en vue, la forge n'en choisissait aucun.
local element
__sansJeux("consommables", function()
    -- Sans jeu, la forge refuse et dit pourquoi : le bareme bloque.
    local ok, raison = F.Ouvrir("consommables")
    attendu("sans jeu d'equilibrage : refus", ok, false)
    attendu("  qui dit quoi faire", tostring(raison):find("Jeux d'équilibrage") ~= nil, true)

    LCM.Forge.Add({
        id = "jeu_consommables_temoin", label = "Consommables témoin", categorie = "consommables",
        raretes = { { id = "commun", label = "Commun", points = 10, couleur = "FFFFFF" } },
        champs = { ["rend:pv"] = { cout = "1", base = "0", max = "5" } },
    })
    attendu("avec un jeu : la forge s'ouvre", F.Ouvrir("consommables"), true)
    F.courant.nom = "Bandage de lin"
    F.courant.type = "temoin_bandage"
    -- Un critere, pas une statistique : depuis le 23 octobre 2026, une
    -- statistique ne passe que par l'etat que le consommable pose, et ce
    -- consommable n'en pose pas (Core/Consommation.lua).
    F.courant.valeurs["rend:pv"] = 2
    local cree
    cree, element = F.Creer()
    attendu("le consommable est cree", cree, true)
    attendu("  dans son registre", element and LCM.Consommables.Get(element.id) ~= nil, true)
    attendu("  pas parmi les ressources", element and LCM.Ressources.Get(element.id), nil)
    attendu("  avec son type", element and element.type, "temoin_bandage")
    attendu("  et sa forge", element and element.forge, "jeu_consommables_temoin/commun")
    attendu("  et son critere", element and element.bonus["rend:pv"], 2)
    F.Fenetre():Hide()
end)

dire("== Il vit comme les autres familles")
local ref = "consommables/" .. element.id
attendu("il se resout", C.Resoudre(ref) ~= nil, true)
attendu("il se range dans un sac", LCM.Inventaire.Accepte({}, 1, ref), true)
attendu("il se pose dans un coffre", LCM.Coffres.Accepte(ref), true)
attendu("il voyage par la base commune", LCM.BasePublique.REGISTRES.consommables, "Consommables")

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
