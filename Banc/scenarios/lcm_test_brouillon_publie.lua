-- Modifier une entree venue d'un fichier, et la retrouver apres un /reload.
--
-- Le bug du 9 octobre 2026 : l'enregistrement changeait bien l'entree en
-- memoire, mais au chargement suivant la file de la sauvegarde n'etait pas
-- appliquee sur une entree deja presente : le fichier reprenait le dessus, sans
-- un mot.
--
-- Depuis le 15 octobre 2026, il n'y a plus de brouillon : une entree
-- enregistree EXISTE. Ce scenario verifiait qu'elle etait « marquee brouillon »
-- et que la supprimer « rendait le publie » ; ces deux attentes sont devenues
-- fausses, et c'est voulu. Supprimer une entree la supprime, d'ou qu'elle
-- vienne, et la base suit au /reload.
--
-- On simule le rechargement : on pose l'entree dans LCM_MJ_DB AVANT la
-- connexion, comme la sauvegarde le ferait.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

-- Deux traits venus des fichiers.
local premier, second
for _, t in ipairs(LCM.Traits.list) do
    if not premier then premier = t elseif not second then second = t end
end
if not second then
    dire("  !!  pas deux traits dans les fichiers : rien a verifier")
    dire("TOUT PASSE")
    return
end
local id, labelOrigine = premier.id, premier.label
dire("trait d'essai :", id, "«" .. tostring(labelOrigine) .. "»")

-- La sauvegarde du compagnon porte une version modifiee du premier, comme
-- apres une seance ou le MJ l'a corrige, et une copie EXACTE du second, que
-- la base a deja suivie.
_G.LCM_MJ_DB = type(_G.LCM_MJ_DB) == "table" and _G.LCM_MJ_DB or {}
_G.LCM_MJ_DB.brouillons = _G.LCM_MJ_DB.brouillons or {}
_G.LCM_MJ_DB.brouillons.traits = _G.LCM_MJ_DB.brouillons.traits or {}
local modifie = LCM.Copie(premier)
modifie.label = "Version corrigée en séance"
-- Restes de l'ancien modele : la migration les efface.
modifie.remplacePublie = true
modifie.brouillon = true
_G.LCM_MJ_DB.brouillons.traits[id] = modifie
_G.LCM_MJ_DB.brouillons.traits[second.id] = LCM.Copie(second)
-- Un ancien masque, de l'epoque ou il cachait sans effacer : le MJ a choisi de
-- garder ces entrees, la migration l'oublie.
_G.LCM_MJ_DB.masques = { traits = { [second.id] = true } }

__declencher("PLAYER_LOGIN")
__personnage()
LCM.db.settings.modeJoueur = nil
LCM._masterCompanion = true

dire("== apres le rechargement, la correction est la")
local B = LCM.Brouillons
local apres = LCM.Traits.Get(id)
attendu("le trait existe toujours", apres ~= nil, true)
attendu("il porte la version corrigee", apres.label, "Version corrigée en séance")
attendu("aucune marque de brouillon", apres.brouillon, nil)
attendu("ni dans la file", B.Get("traits", id).remplacePublie, nil)
attendu("la file la garde jusqu'a ce que la base suive", B.Get("traits", id) ~= nil, true)

dire("== une copie identique au fichier quitte la file")
attendu("la base a suivi : rien a envoyer", B.Get("traits", second.id), nil)

dire("== la migration oublie les anciens masques")
attendu("l'entree masquee est revenue", LCM.Traits.Get(second.id) ~= nil, true)
attendu("plus de masque", B.EstMasquee("traits", second.id), false)
attendu("modele a jour", _G.LCM_MJ_DB.version, 2)

dire("== supprimer, c'est supprimer")
attendu("supprime", B.Supprimer("traits", id), true)
attendu("retire du jeu", LCM.Traits.Get(id), nil)
attendu("retire de la file", B.Get("traits", id), nil)
attendu("note pour la base", B.EstMasquee("traits", id), true)

dire("== reecrire l'entree la fait revenir")
-- Le bareme de la forge bloque un trait sans jeu : un jeu TEMOIN, large.
B.Enregistrer("jeux", { id = "essai_traits", label = "Essai (traits)", categorie = "traits",
    raretes = { { id = "libre", label = "Libre", points = 999, couleur = "FFFFFF" } } }, true)
modifie.forge = "essai_traits/libre"
local ecrite, raison = B.Enregistrer("traits", modifie, false)
attendu("enregistree", ecrite, true)
if not ecrite then dire("   raison :", tostring(raison)) end
attendu("de nouveau en jeu", LCM.Traits.Get(id) ~= nil, true)
attendu("la suppression est oubliee", B.EstMasquee("traits", id), false)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
