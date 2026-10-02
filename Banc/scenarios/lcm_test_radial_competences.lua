-- La categorie « Competences » du lanceur : les sorts du personnage joue.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
local R = LCM.UI.Radial
local moi = LCM.Entities.Self()

dire("== sans sort, la categorie est vide")
attendu("aucune entree", #R.Entrees("competences"), 0)

dire("== les sorts du personnage s'y rangent")
LCM.Sorts.Ajouter(moi, { label = "Trait de givre", icone = "Interface\ICONS\spell_frost_frostbolt",
    jet = { min = 1, max = 20 } })
LCM.Sorts.Ajouter(moi, { label = "Murmure", icone = "Interface\ICONS\spell_shadow_charm" })
local entrees = R.Entrees("competences")
attendu("deux entrees", #entrees, 2)
attendu("la premiere porte le nom du sort", entrees[1].label, "Trait de givre")
attendu("et son icone", entrees[1].icone, "Interface\ICONS\spell_frost_frostbolt")
attendu("elles sont toutes cliquables", type(entrees[1].onClick), "function")

dire("== un sort qui se lance se lance")
LCM.Canal.Choisir("local")
entrees[1].onClick()
attendu("le jet part dans le canal", __sansCouleur(__sorties[#__sorties]):find("Trait de givre") ~= nil, true)

dire("== un sort sans jet se cite")
-- Zone de saisie fermee : le lien s'affiche, ou il reste cliquable.
entrees[2].onClick()
attendu("il est montre", __sansCouleur(__sorties[#__sorties]):find("%[Murmure%]") ~= nil, true)
-- Zone ouverte : il s'y pose, comme un objet du jeu.
_G.__chatOuvert = true
entrees[2].onClick()
_G.__chatOuvert = nil
attendu("il se pose dans la saisie", tostring(__dernierLien()):find("Murmure") ~= nil, true)

dire("== huit au plus : un eventail n'a pas neuf branches")
for i = 3, 12 do LCM.Sorts.Ajouter(moi, { label = "Sort " .. i }) end
attendu("le personnage en a douze", LCM.Sorts.Compte(moi), 12)
attendu("le lanceur en montre huit", #R.Entrees("competences"), R.MAX_ENTREES)

dire("== Animation : « Resolution Test MJ » a laisse la place")
local animation = {}
for _, e in ipairs(R.Entrees("animation")) do animation[#animation + 1] = e.id end
attendu("les trois actions du MJ", table.concat(animation, ","), "degat_mj,buff_debuff_mj,attaque_mj")

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
