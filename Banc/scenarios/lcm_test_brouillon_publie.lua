-- Modifier une entree PUBLIEE, et la retrouver apres un /reload.
--
-- Le bug du 9 octobre 2026 : l'enregistrement changeait bien l'entree en
-- memoire, mais au chargement suivant la boucle des brouillons n'avait que deux
-- cas — entree absente (on l'ajoute) ou brouillon identique au publie (on le
-- jette). Un brouillon qui RECOUVRAIT une entree publiee en la modifiant
-- n'etait jamais applique : le fichier reprenait le dessus, sans un mot, et la
-- correction semblait perdue alors qu'elle etait toujours en sauvegarde.
--
-- On simule le rechargement : on pose le brouillon dans LCM_MJ_DB AVANT la
-- connexion, comme la sauvegarde le ferait.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ko and not ok then ko = 1 end
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

-- Une entree PUBLIEE : elle vient d'un fichier, elle n'est pas un brouillon.
local publie
for _, t in ipairs(LCM.Traits.list) do
    if t.brouillon ~= true and not publie then publie = t end
end
if not publie then
    dire("  !!  aucun trait publie : rien a verifier")
    dire("TOUT PASSE")
    return
end
local id, labelOrigine = publie.id, publie.label
dire("trait publie d'essai :", id, "«" .. tostring(labelOrigine) .. "»")

-- La sauvegarde du compagnon porte DEJA une version modifiee, comme apres une
-- seance ou le MJ a corrige l'entree.
_G.LCM_MJ_DB = type(_G.LCM_MJ_DB) == "table" and _G.LCM_MJ_DB or {}
_G.LCM_MJ_DB.brouillons = _G.LCM_MJ_DB.brouillons or {}
_G.LCM_MJ_DB.brouillons.traits = _G.LCM_MJ_DB.brouillons.traits or {}
local modifie = {}
for cle, valeur in pairs(publie) do modifie[cle] = valeur end
modifie.label = "Version corrigée en séance"
modifie.remplacePublie = true
modifie.brouillon = nil
_G.LCM_MJ_DB.brouillons.traits[id] = modifie

__declencher("PLAYER_LOGIN")
__personnage()
LCM.db.settings.modeJoueur = nil
LCM._masterCompanion = true

dire("== apres le rechargement, la correction est la")
local B = LCM.Brouillons
attendu("le compagnon est charge", B ~= nil, true)
local apres = LCM.Traits.Get(id)
attendu("le trait existe toujours", apres ~= nil, true)
attendu("il porte la version corrigee", apres.label, "Version corrigée en séance")
attendu("et il est marque brouillon", apres.brouillon, true)
attendu("le brouillon reste en attente d'export", B.Get("traits", id) ~= nil, true)

dire("== supprimer le brouillon REND l'entree publiee")
-- C'est l'autre moitie du piege : si l'application au chargement ne gardait pas
-- de copie de l'original, supprimer le brouillon effacerait le contenu publie.
attendu("supprime", B.Supprimer("traits", id), true)
local rendu = LCM.Traits.Get(id)
attendu("l'entree publiee est rendue", rendu ~= nil, true)
attendu("avec son libelle d'origine", rendu and rendu.label, labelOrigine)
attendu("et elle n'est plus un brouillon", rendu and rendu.brouillon, nil)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
