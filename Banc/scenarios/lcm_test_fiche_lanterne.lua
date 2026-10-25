-- La lanterne dans l'onglet Outils de la fiche (24 octobre 2026).
--
-- Une lanterne est un outil : elle prend une place de la ceinture. Elle vit
-- pourtant dans sa propre famille du compendium (`lanternes`), pour son
-- editeur. La ceinture du bas le savait ; l'emplacement Outils de la fiche,
-- non — il ne proposait que la categorie « outil » et repondait « aucun
-- objet de type outil dans les sacs » avec une lanterne dans le sac.
--
-- Ce que ce scenario tient :
--   * l'emplacement propose les lanternes des sacs a cote des outils ;
--   * la lanterne equipee a sa ligne et compte dans « n / places » ;
--   * on la retire d'un clic, elle retourne au sac ;
--   * glissee depuis un sac, elle ne sort qu'UNE fois ;
--   * la fiche d'un autre ne propose pas de lanterne (elle s'equipe sur soi).
--
-- Contenu TEMOIN (CLAUDE.md, « un test ne se pose jamais sur du contenu qui
-- vit ») ; le scanner vient de Data/OutilsCeinture.lua, du code.

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

local I, O, L = LCM.Inventaire, LCM.Objets, LCM.Lanterne
local moi = LCM.Entities.Self()
L.Reinitialiser()
LCM.Lanternes.Add({ id = "temoin_fiche", label = "Lanterne témoin", multiplicateur = 1 })
LCM.Sacs.Add({ id = "temoin_sac", label = "Sac témoin", places = 12, icone = "inv_misc_bag_30" })
attendu("le sac temoin est porte", I.Poser(moi, "sacs", 1, "temoin_sac", true), true)
attendu("une lanterne au sac", I.Deposer(moi, "lanternes/temoin_fiche", 1), true)
attendu("un outil au sac", I.Deposer(moi, "objets/outil_scanner_valrazkah", 1), true)
local places = O.Capacite("outil")

local alertes = {}
local alerteAvant = LCM.Alerte
LCM.Alerte = function(texte) alertes[#alertes + 1] = tostring(texte) end

LCM.UI.Menu.Trouver("equipement").onClick()
local f = LCM.UI.Vues.frames.equipement
local bloc = f.pages.outil.blocs[1]
local conteneur = bloc.conteneur
conteneur:Actualiser(moi)

local function lignes()
    local out = {}
    for _, ligne in ipairs(conteneur.emplacements) do
        if ligne:IsShown() then out[#out + 1] = ligne end
    end
    return out
end
local function premiereLibre()
    for _, ligne in ipairs(lignes()) do if not ligne.elementId then return ligne end end
end
local function ligneLanterne()
    for _, ligne in ipairs(lignes()) do if ligne.lanterne then return ligne end end
end
local function proposes()
    local out = {}
    for _, b in ipairs(LCM.UI.Fiche.choixConteneur.lignes) do
        if b:IsShown() then out[#out + 1] = b.choix end
    end
    table.sort(out)
    return table.concat(out, ",")
end
local function choisir(id)
    for _, b in ipairs(LCM.UI.Fiche.choixConteneur.lignes) do
        if b:IsShown() and b.choix == id then b:Click() return true end
    end
    return false
end

dire("== l'emplacement propose la lanterne avec les outils")
attendu("rien de porte", bloc.occupation:GetText(), "0 / " .. places)
premiereLibre():Click("LeftButton")
attendu("propose", proposes(), "lanternes/temoin_fiche,outil_scanner_valrazkah")
attendu("aucune alerte", #alertes, 0)

dire("== equipee depuis la fiche")
attendu("on choisit la lanterne", choisir("lanternes/temoin_fiche"), true)
attendu("elle est equipee", L.IdEquipe(moi), "temoin_fiche")
attendu("elle a quitte le sac", I.Chercher(moi, "lanternes/temoin_fiche"), nil)
attendu("elle compte dans la ceinture", bloc.occupation:GetText(), "1 / " .. places)
local ligne = ligneLanterne()
attendu("elle a sa ligne", ligne ~= nil, true)
attendu("  a son nom", ligne and ligne.nom:GetText(), "Lanterne témoin")
attendu("  et se retire", ligne and ligne.action:IsShown(), true)

dire("== l'outil a cote")
premiereLibre():Click("LeftButton")
attendu("le scanner reste propose, la lanterne portee non", proposes(), "outil_scanner_valrazkah")
choisir("outil_scanner_valrazkah")
attendu("le scanner est equipe", O.Porte(moi, "outil_scanner_valrazkah"), true)
attendu("ceinture pleine", bloc.occupation:GetText(), places .. " / " .. places)
attendu("plus de place libre a offrir", premiereLibre(), nil)
attendu("l'outil d'abord", lignes()[1].elementId, "outil_scanner_valrazkah")
attendu("la lanterne ensuite", lignes()[2].lanterne, true)

dire("== retiree d'un clic")
ligneLanterne():Click("LeftButton")
attendu("elle n'est plus equipee", L.IdEquipe(moi), nil)
attendu("elle est au sac", I.Chercher(moi, "lanternes/temoin_fiche") ~= nil, true)
attendu("la place se libere", bloc.occupation:GetText(), "1 / " .. places)

dire("== glissee depuis un sac, elle ne sort qu'une fois")
attendu("une seconde lanterne pareille au sac", I.Deposer(moi, "lanternes/temoin_fiche", 1), true)
local cat, index, case = I.Chercher(moi, "lanternes/temoin_fiche")
local avant = I.Case(I.Emplacement(moi, cat, index), case).quantite
local vide = premiereLibre()
local paquet = { ref = "lanternes/temoin_fiche", quantite = 1, origine = { onglet = cat, index = index, case = case } }
attendu("la place l'accepte", vide.glisserAccepte(paquet), true)
vide.glisserDepose(paquet)
attendu("elle est equipee", L.IdEquipe(moi), "temoin_fiche")
local _, i2, c2 = I.Chercher(moi, "lanternes/temoin_fiche")
local apres = i2 and I.Case(I.Emplacement(moi, cat, i2), c2).quantite or 0
attendu("une seule est sortie du sac", avant - apres, 1)
L.RetirerLanterne()
conteneur:Actualiser(moi)

dire("== la fiche d'un autre ne propose pas de lanterne")
local autre = { id = "autre_temoin", nom = "Autre" }
attendu("ce n'est pas soi", conteneur:EstCeinture() and autre ~= moi, true)
conteneur.entity = autre
attendu("pas de lanterne ici", conteneur:LanterneIci(), false)
local refus = premiereLibre() and premiereLibre().glisserAccepte(paquet)
attendu("glisser une lanterne sur la fiche d'un autre est refuse", refus, false)
conteneur:Actualiser(moi)

dire("== sacs vides : le refus le dit")
O.Desequiper(moi, "outil_scanner_valrazkah")
for _, ref in ipairs({ "lanternes/temoin_fiche", "objets/outil_scanner_valrazkah" }) do
    while I.Chercher(moi, ref) do I.Prendre(moi, ref) end
end
conteneur:Actualiser(moi)
alertes = {}
premiereLibre():Click("LeftButton")
attendu("le refus nomme les deux", alertes[1], "aucun outil ni lanterne dans les sacs.")

LCM.Alerte = alerteAvant
print(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
