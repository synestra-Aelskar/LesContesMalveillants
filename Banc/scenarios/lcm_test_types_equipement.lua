-- Les TYPES d'équipement, et ce qu'ils autorisent (10 octobre 2026).
--
-- Deux règles neuves :
--   * porter deux fois la même dague est normal — ce sont les types qui
--     bornent, pas l'identifiant ;
--   * chaque type dit combien on peut en porter (« une seule cape »), et il le
--     dit dans le COMPENDIUM, sur l'entrée de type elle-même. C'est une
--     décision de jeu : elle doit se régler en séance, pas dans le code.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()
LCM.db.settings.modeJoueur = nil
LCM._masterCompanion = true

local moi = LCM.Entities.Self()
local O, L = LCM.Objets, LCM.Listes

dire("== la liste des types d'accessoires existe")
-- Les accessoires empruntaient la « Liste Armes » faute d'en avoir une : un
-- anneau se choisissait parmi des types d'armes.
local accessoires = {}
for _, e in ipairs(L.list) do
    if e.liste == "type_accessoires" then accessoires[e.id] = e end
end
attendu("elle est peuplée", accessoires.anneau ~= nil, true)
for _, id in ipairs({ "anneau", "pendentif", "bracelet", "bijou", "cape" }) do
    attendu("  " .. id, accessoires[id] ~= nil, true)
end
attendu("une cape, une seule", accessoires.cape and accessoires.cape.maxEquipe, 1)
-- Combien d'anneaux ou de bijoux, c'est le MJ qui le regle dans le
-- compendium : du CONTENU, qui a deja bouge (anneau 2 -> 4, bijou illimite
-- -> 4). On verifie que la limite existe et qu'on la respecte, pas sa valeur
-- (21 octobre 2026).
local maxAnneaux = accessoires.anneau and tonumber(accessoires.anneau.maxEquipe)
attendu("les anneaux ont une limite", maxAnneaux ~= nil and maxAnneaux >= 1, true)

-- Et la catégorie Accessoires du compendium pointe bien dessus.
local categorie
for _, c in ipairs(LCM.Compendium.categories) do
    if c.id == "accessoires" then categorie = c end
end
attendu("la catégorie existe", categorie ~= nil, true)
local champType
for _, champ in ipairs(LCM.Compendium.Champs(categorie)) do
    if champ.cle == "type" then champType = champ end
end
attendu("son Type puise dans la bonne liste", champType and champType.source,
    "listes:type_accessoires")

dire("== deux fois le même objet, c'est permis")
O.Add({ id = "dague_jumelle", label = "Dague jumelle", categorie = "arme" })
attendu("la première", O.Placer(moi, "dague_jumelle"), true)
attendu("la seconde aussi", O.Placer(moi, "dague_jumelle"), true)
attendu("on en porte deux", #O.Ids(moi, "arme"), 2)
O.Enlever(moi, "dague_jumelle")
O.Enlever(moi, "dague_jumelle")
attendu("et on les retire une par une", #O.Ids(moi, "arme"), 0)

dire("== mais le type borne")
O.Add({ id = "cape_grise", label = "Cape grise", categorie = "accessoire", type = "cape" })
O.Add({ id = "cape_rouge", label = "Cape rouge", categorie = "accessoire", type = "cape" })
attendu("une cape passe", O.Placer(moi, "cape_grise"), true)
local ok, raison = O.Placer(moi, "cape_rouge")
attendu("la seconde est refusée", ok, false)
attendu("et on dit pourquoi", tostring(raison):find("Cape") ~= nil, true)
-- Le MEME objet deux fois bute sur la meme limite : c'est le type qui compte.
attendu("deux fois la même cape non plus", (O.Placer(moi, "cape_grise")), false)

-- Autant d'anneaux que la limite, pas un de plus.
O.Add({ id = "anneau_simple", label = "Anneau simple", categorie = "accessoire", type = "anneau" })
local acceptes = 0
for _ = 1, maxAnneaux or 0 do if O.Placer(moi, "anneau_simple") then acceptes = acceptes + 1 end end
attendu("autant d'anneaux que la limite", acceptes, maxAnneaux)
attendu("un de plus est refusé", (O.Placer(moi, "anneau_simple")), false)

-- Un type sans limite ne borne rien. On libere d'abord : un personnage n'a que
-- cinq emplacements d'accessoire, et c'est la LIMITE DE TYPE qu'on teste ici,
-- pas celle du conteneur.
local function ViderLesAccessoires()
    for _, id in ipairs(O.Ids(moi, "accessoire")) do O.Enlever(moi, id) end
    while #O.Ids(moi, "accessoire") > 0 do
        O.Enlever(moi, O.Ids(moi, "accessoire")[1])
    end
end
ViderLesAccessoires()
O.Add({ id = "bijou_terne", label = "Bijou terne", categorie = "accessoire", type = "bijou" })
local tous = true
for _ = 1, 3 do if not O.Placer(moi, "bijou_terne") then tous = false end end
attendu("un type sans limite laisse passer", tous, true)

dire("== la limite se règle en séance")
-- C'est tout l'interet de la porter sur l'entree de type : on la change sans
-- publier une version de l'addon.
ViderLesAccessoires()
accessoires.cape.maxEquipe = 2
attendu("une première cape", O.Placer(moi, "cape_grise"), true)
attendu("la cape passe à deux", O.Placer(moi, "cape_rouge"), true)
attendu("mais pas à trois", (O.Placer(moi, "cape_grise")), false)
accessoires.cape.maxEquipe = 1

dire("== modifier le max d'un type publié depuis l'éditeur")
local ed = LCM.CompendiumEditeur
local categorie = LCM.Compendium.Get("type_accessoires")
ed.Ouvrir(categorie, accessoires.cape)
local fenetre = ed.frame
attendu("type publié modifiable", fenetre.lecture, false)
local champMax
for _, champ in ipairs(LCM.Compendium.Champs(categorie)) do
    if champ.cle == "maxEquipe" then champMax = champ break end
end
attendu("champ max présent", champMax ~= nil, true)
fenetre.editeurs[champMax].saisie:Saisir("2")
fenetre:Valider()
attendu("nouveau max appliqué", accessoires.cape.maxEquipe, 2)
attendu("dans la file d'envoi", LCM.Brouillons.Get("listes", "cape") ~= nil, true)
-- 15 octobre 2026 : supprimer ne « rend » plus une version d'origine, il
-- supprime le type. On remet donc la valeur comme le MJ le ferait : en
-- reenregistrant l'entree.
local remise = LCM.Copie(LCM.Brouillons.Get("listes", "cape"))
remise.maxEquipe = 1
LCM.Brouillons.Enregistrer("listes", remise, false)
attendu("original restauré", accessoires.cape.maxEquipe, 1)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
