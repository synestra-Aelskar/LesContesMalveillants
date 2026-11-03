-- Les TAGS (le MJ, 3 novembre 2026) : retrouver vite une entree parmi des
-- milliers. Un tag est range sous une origine, en arbre (Valienne › Raptor ›
-- Foudre › Sans les dents) ; une entree en porte plusieurs ; le compendium et
-- les listes de choix filtrent dessus. Un tag couvre ses sous-tags.
local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()
local E, B, C = LCM.Etiquettes, LCM.Brouillons, LCM.Compendium
-- Une origine temoin : le contenu de la campagne bouge.
LCM.Listes.Add({ id = "valienne_tag", liste = "origines", label = "Valienne témoin" })

dire("== créer des tags, en arbre")
local raptor = B.CreerTag("Raptor", "origine:valienne_tag")
attendu("une racine sous Valienne", raptor ~= nil and E.Origine(E.Get(raptor)), "valienne_tag")
local foudre = B.CreerTag("Foudre", "parent:" .. raptor)
local feu = B.CreerTag("Feu", "parent:" .. raptor)
local dents = B.CreerTag("Sans les dents", "parent:" .. foudre)
attendu("un sous-sous-tag hérite de l'origine", E.Origine(E.Get(dents)), "valienne_tag")
attendu("son chemin", E.Chemin(dents), "Raptor › Foudre › Sans les dents")
local general = B.CreerTag("Rare", "origine:")
attendu("un tag général (Aucun)", E.Origine(E.Get(general)), "")
attendu("le même nom au même endroit est refusé", (B.CreerTag("Foudre", "parent:" .. raptor)), nil)
attendu("  ailleurs, il passe", B.CreerTag("Foudre", "origine:") ~= nil, true)

dire("== ranger : origine, puis arbre")
local groupes = E.GroupesCoches(true)
attendu("« Aucun » d'abord", groupes[1].label, "Aucun")
local valienne
for _, g in ipairs(groupes) do if g.label == "Valienne témoin" then valienne = g end end
attendu("Valienne a son arbre", valienne and (valienne.options[1].label .. ">" .. valienne.options[2].label), "Raptor>Feu")
attendu("  les niveaux en retrait", valienne and valienne.options[4] and (valienne.options[4].label .. ":" .. valienne.options[4].niveau), "Sans les dents:2")

dire("== filtrer : un tag couvre ses sous-tags")
local a = LCM.Objets.Add({ id = "dent_foudre_t", label = "Dent de raptor foudre", categorie = "outil", etiquettes = { foudre } })
local b = LCM.Objets.Add({ id = "dent_sans_t", label = "Raptor édenté", categorie = "outil", etiquettes = { dents } })
local c = LCM.Objets.Add({ id = "braise_t", label = "Braise de raptor", categorie = "outil", etiquettes = { feu } })
local d = LCM.Objets.Add({ id = "pierre_t", label = "Pierre", categorie = "outil" })
attendu("l'objet garde ses tags", a.etiquettes and a.etiquettes[1], foudre)
local sel = E.Ensemble({ raptor })
attendu("Raptor : tout ce qui est raptor", tostring(E.Porte(a, sel)) .. tostring(E.Porte(b, sel)) .. tostring(E.Porte(c, sel))
    .. tostring(E.Porte(d, sel)), "truetruetruefalse")
sel = E.Ensemble({ foudre })
attendu("Foudre : foudre et ses sous-tags, pas le feu", tostring(E.Porte(a, sel)) .. tostring(E.Porte(b, sel))
    .. tostring(E.Porte(c, sel)), "truetruefalse")
attendu("deux tags : l'un OU l'autre", E.Porte(c, E.Ensemble({ dents, feu })), true)

dire("== le compendium : bouton « Tags »")
local fen = LCM.UI.Compendium.Ouvrir and LCM.UI.Compendium.Ouvrir("outils")
local f = LCM.UI.Compendium.frame or fen
attendu("le bouton est là", f.tagsBouton ~= nil, true)
f.tagsChoisis = E.Ensemble({ foudre })
local noms = {}
for _, e in ipairs(f:Filtrer()) do noms[#noms + 1] = e.id end
table.sort(noms)
attendu("seulement le contenu Foudre", table.concat(noms, ","), "dent_foudre_t,dent_sans_t")
attendu("  le bouton le dit", f.tagsBouton.label:GetText(), "Tags (1)")
f.effacer:Click()
attendu("X efface le filtre", f.tagsChoisis, nil)

dire("== la forge : bouton « Tags »")
local FU = LCM.UI.Forge
LCM.Forge.Add({ id = "jeu_outils_tags", label = "Jeu outils tags", categorie = "outils",
    raretes = { { id = "commun", label = "Commun", points = 10, couleur = "FF8CB8" } }, champs = {} })
FU.Ouvrir("outils")
local forge = FU.Fenetre()
FU.courant.jeuId, FU.courant.rareteId = "jeu_outils_tags", "commun"
forge:Rafraichir()
attendu("le bouton Tags se montre", forge.etiquettes:IsShown(), true)
forge.etiquettes:Click()
local popup = FU.choixTags.coches
attendu("la fenêtre des tags s'ouvre, avec « Créer »", popup:IsShown() and popup.action:IsShown(), true)
-- En accordeon depuis le 3 novembre 2026 (le MJ : « imbuvable avec 500
-- tags ») : la fenetre s'ouvre repliee, sans rien de coche. « Feu » est sous
-- une origine, sous « Raptor » : on deplie avant de cocher, comme le MJ.
local function toutDeplier()
    for _ = 1, 6 do
        for _, t in ipairs(popup.entetes) do
            if t:IsShown() and t.ouvert == false then t:Click() end
        end
        for _, cse in ipairs(popup.cases) do
            if cse:IsShown() and cse.pli:IsShown() and not cse.pli.ouvert then cse.pli:Click() end
        end
    end
end
local visibleAvant = false
for _, cse in ipairs(popup.cases) do if cse:IsShown() and cse.id == feu then visibleAvant = true end end
attendu("  repliée : « Feu » ne se voit pas d'emblée", visibleAvant, false)
toutDeplier()
for _, cse in ipairs(popup.cases) do if cse:IsShown() and cse.id == feu then cse:Click() end end
-- Créer à la volée : un nom, puis où le ranger ; il se coche aussitôt.
popup.action:Click()
local demande = LCM.UI.Demande()
demande.saisie:Saisir("Électrique")
demande.valider:Click()
local emplacement = FU.choixTags.emplacement
attendu("on choisit où le ranger", emplacement and emplacement:IsShown(), true)
for _, l in ipairs(emplacement.lignes) do
    if l:IsShown() and l.choix == "parent:" .. raptor then l:Click() break end
end
local electrique
for _, t in ipairs(E.Liste()) do if t.label == "Électrique" then electrique = t end end
attendu("le tag est créé sous Raptor", electrique and E.Chemin(electrique.id), "Raptor › Électrique")
attendu("  et déjà coché, avec le Feu", popup.selection[electrique and electrique.id or ""] == true
    and popup.selection[feu] == true, true)
popup.selection[electrique.id] = nil
popup.valider:Click()
attendu("le bouton résume", forge.etiquettes.label:GetText(), "Tags : Raptor › Feu")
FU.courant.nom = "Griffe"
local def = FU.Definition()
attendu("la définition porte les tags", def and def.etiquettes and def.etiquettes[1], feu)
attendu("  le libellé de rareté reste dans `tags`", def and def.tags, "Commun")
forge:Hide()

dire("== les listes de choix : recherche et tags")
local choix = LCM.UI.Choix("test_tags", "Objet")
choix:Proposer(nil, { { id = "objets/dent_foudre_t", label = "Dent de raptor foudre" },
    { id = "objets/braise_t", label = "Braise de raptor" }, { id = "objets/pierre_t", label = "Pierre" } }, function() end)
attendu("une liste d'entrées a la recherche et les tags", choix.recherche:IsShown() and choix.tagsBouton:IsShown(), true)
choix.tags = E.Ensemble({ raptor })
choix:Rendre()
local montres = 0
for _, l in ipairs(choix.lignes) do if l:IsShown() then montres = montres + 1 end end
attendu("le tag Raptor ne garde que les raptors", montres, 2)
choix.tags = nil
choix.recherche:Saisir("pier")
montres = 0
for _, l in ipairs(choix.lignes) do if l:IsShown() then montres = montres + 1 end end
attendu("la recherche trouve la pierre", montres, 1)
choix:Hide()

for _, id in ipairs({ "dent_foudre_t", "dent_sans_t", "braise_t", "pierre_t" }) do LCM.Objets.Retirer(id) end
print(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
