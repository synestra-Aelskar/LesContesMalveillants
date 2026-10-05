-- L'onglet Traits de la fiche : liste des traits portes, ajout et retrait par
-- le MJ, trait disparu, lecture seule pour le joueur.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

-- Un brouillon, pour avoir deux traits a proposer.
LCM.Brouillons.Set("traits", {
    id = "oeil_du_faucon", label = "Oeil du faucon", cout = 2,
    description = "Repere ce que les autres manquent.",
    bonus = { vue = 2, investigation = 1 }, avantage = { "vue" },
})

__declencher("PLAYER_LOGIN")
__personnage()   -- ce scenario joue un personnage : il le dit

local moi = LCM.Entities.Self()

dire("== le champ est dans le schema, pas dans les valeurs")
local field = LCM.Schema.Field("traits_portes")
attendu("champ declare", field ~= nil, true)
attendu("de type traits", field.kind, "traits")
attendu("dans l'onglet Traits", field.tab, "traits")
attendu("on ne l'ecrit pas comme une valeur", LCM.Entities.Set_Value(moi, "traits_portes", { "x" }), false)
attendu("rien dans values", moi.values.traits_portes, nil)

dire("== une fiche sans trait")
SlashCmdList.LCM("fiche")
local f = LCM.UI.Fiche.frame
f.barre.boutons[#f.barre.boutons]:Click()
for _, b in ipairs(f.barre.boutons) do
    if b.ongletId == "traits" then b:Click() end
end
attendu("onglet Traits actif", f.onglet, "traits")
local ligne
for _, l in ipairs(f.pages.traits.lignes) do if l.cartes then ligne = l end end
attendu("la ligne des traits existe", ligne ~= nil, true)
attendu("elle est la premiere de l'onglet", f.pages.traits.lignes[1], ligne)
attendu("message vide", ligne.vide:IsShown(), true)
attendu("aucune carte", #ligne.cartes, 0)
attendu("pas de resume", ligne.resume:GetText(), "")

dire("== le MJ ajoute un trait")
attendu("bouton d'ajout (MJ)", ligne.ajouter:IsShown(), true)
ligne.ajouter:Click()
attendu("liste de choix ouverte", ligne.choix:IsShown(), true)
local proposes, cible = 0, nil
for _, b in ipairs(ligne.choix.lignes) do
    if b:IsShown() then
        proposes = proposes + 1
        if b.choix == "oeil_du_faucon" then cible = b end
    end
end
attendu("tous les traits connus proposes", proposes, #LCM.Traits.list)
cible:Click()
attendu("porte", LCM.Traits.Has(moi, "oeil_du_faucon"), true)
attendu("une carte", ligne.cartes[1] and ligne.cartes[1]:IsShown(), true)
attendu("message vide cache", ligne.vide:IsShown(), false)
local c = ligne.cartes[1]
dire("   nom : " .. __sansCouleur(c.nom:GetText()))
attendu("nom affiche", __sansCouleur(c.nom:GetText()):find("^Oeil du faucon") ~= nil, true)
attendu("le nom seul, sans marque brouillon", c.nom:GetText(), "Oeil du faucon")
attendu("cout", c.cout:GetText(), "2 pts")
attendu("description", c.description:GetText(), "Repere ce que les autres manquent.")
attendu("effets", c.effets:GetText(), "Investigation +1  ·  Vue +2  ·  Avantage : Vue")
attendu("resume", ligne.resume:GetText(), "1 trait  ·  2 pts")

ligne.ajouter:Click()
local encore = 0
for _, b in ipairs(ligne.choix.lignes) do
    if b:IsShown() and b.choix == "oeil_du_faucon" then encore = encore + 1 end
end
attendu("un trait porte n'est plus propose", encore, 0)
for _, b in ipairs(ligne.choix.lignes) do
    if b:IsShown() and b.choix == "escalade_jungle" then b:Click() end
end
attendu("deux cartes", ligne.cartes[2] and ligne.cartes[2]:IsShown(), true)
attendu("resume a deux", ligne.resume:GetText(), "2 traits  ·  4 pts")
attendu("la 2e carte est sous la 1re",
    select(5, ligne.cartes[2]:GetPoint(1)) < select(5, ligne.cartes[1]:GetPoint(1)), true)
attendu("la carte grandit avec sa description", ligne.cartes[1]:GetHeight() > 24, true)

dire("== le bonus se voit dans la fenetre Expertises")
local fe = LCM.UI.Vues.Fenetre("expertise")
fe:Montrer(moi)
fe:Afficher("observations")
local ligneVue
for _, l in ipairs(fe.pages.observations.lignes) do
    if l.label and l.label:GetText() == "Vue" then ligneVue = l end
end
attendu("vue : valeur", ligneVue.valeur:GetText(), "0")
attendu("vue : bonus dans sa colonne", ligneVue.bonus:GetText(), "+2")
attendu("vue : case d'avantage", ligneVue.avantage:IsShown(), true)
fe:Hide()

dire("== retirer")
local premier = ligne.cartes[1].elementId
ligne.cartes[1].retirer:Click()
attendu("le bon trait retire", LCM.Traits.Has(moi, premier), false)
attendu("l'autre reste", #LCM.Traits.Ids(moi), 1)
attendu("une seule carte visible", ligne.cartes[2]:IsShown(), false)

dire("== un trait disparu reste visible")
LCM.Traits.Grant(moi, "oeil_du_faucon")
LCM.Brouillons.Supprimer("traits", "oeil_du_faucon")
f:Actualiser()
local fantome
for _, carte in ipairs(ligne.cartes) do
    if carte:IsShown() and carte.elementId == "oeil_du_faucon" then fantome = carte end
end
attendu("toujours liste", fantome ~= nil, true)
attendu("marque inconnu", __sansCouleur(fantome.nom:GetText()), "? oeil_du_faucon")
attendu("pas d'effet annonce", fantome.effets:IsShown(), false)
attendu("ne compte pas dans le cout", LCM.Traits.CoutTotal(moi), 2)
-- 3 octobre 2026 : on ne retire plus SES PROPRES traits — ils se choisissent a
-- la creation et font le personnage. Un trait FANTOME fait exception : sans
-- cette porte il resterait colle a la fiche sans rien donner.
attendu("le fantome reste retirable", fantome.retirer:IsShown(), true)
local vrai
for _, carte in ipairs(ligne.cartes) do
    if carte:IsShown() and carte.elementId ~= "oeil_du_faucon" then vrai = carte break end
end
attendu("mais pas un vrai trait a soi", vrai and vrai.retirer:IsShown(), false)
fantome.retirer:Click()
attendu("retire", LCM.Traits.Has(moi, "oeil_du_faucon"), false)

dire("== le joueur lit, il ne touche pas")
LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = false
f:Actualiser()
attendu("pas de bouton d'ajout", ligne.ajouter:IsShown(), false)
attendu("pas de retrait", ligne.cartes[1].retirer:IsShown(), false)
ligne:Retirer("escalade_jungle")
attendu("un appel direct ne retire rien", LCM.Traits.Has(moi, "escalade_jungle"), true)
LCM._masterCompanion = true
__addonsCharges["LesContesMalveillants_MJ"] = true

dire("== tout est porte : on le dit au lieu d'ouvrir une liste vide")
-- Le compendium importe apporte d'autres traits : on les porte tous.
for _, trait in ipairs(LCM.Traits.list) do LCM.Traits.Grant(moi, trait.id) end
f:Actualiser()
local avant = #__sorties
ligne.ajouter:Click()
attendu("pas de liste", ligne.choix:IsShown(), false)
attendu("un message", __sorties[avant + 1] and __sorties[avant + 1]:find("deja portes") ~= nil, true)

dire("== la liste de choix se ferme avec la fiche")
LCM.Traits.Revoke(moi, "escalade_jungle")
f:Actualiser()
ligne.ajouter:Click()
attendu("ouverte", ligne.choix:IsShown(), true)
for _, b in ipairs(f.barre.boutons) do
    if b.ongletId == "statistiques" then b:Click() end
end
attendu("fermee en changeant d'onglet", ligne.choix:IsShown(), false)
for _, b in ipairs(f.barre.boutons) do
    if b.ongletId == "traits" then b:Click() end
end
ligne.ajouter:Click()
attendu("rouverte", ligne.choix:IsShown(), true)
SlashCmdList.LCM("fiche")
attendu("fiche fermee", f:IsShown(), false)
attendu("la liste aussi", ligne.choix:IsShown(), false)

dire("== avantage et desavantage (regles du 5 octobre 2026)")
-- L'exemple donne : +1 escalade, +2 acrobaties, -1 vol a la tire.
-- Attendu : desavantage DE FACTO sur vol a la tire, et un avantage a choisir
-- parmi escalade / acrobaties seulement.
local B3 = LCM.Brouillons
B3.Enregistrer("traits", {
    id = "grimpeur_malhabile", label = "Grimpeur malhabile", cout = 1,
    bonus = { escalade = 1, acrobaties = 2, vol_a_la_tire = -1 },
    avantage = { "escalade" },
}, true)
local tr = LCM.Traits.Get("grimpeur_malhabile")
attendu("le trait existe", tr ~= nil, true)
LCM.Traits.Grant(moi, "grimpeur_malhabile")

-- Le desavantage ne se declare pas : il se deduit du bonus negatif.
attendu("desavantage sur ce qu'on penalise",
    select(1, LCM.Effets.Desavantage(moi, "vol_a_la_tire")) ~= nil, true)
attendu("rien sur ce qu'on ameliore",
    LCM.Effets.Desavantage(moi, "escalade"), nil)

local r = LCM.Roll.Field(moi, "vol_a_la_tire")
attendu("deux des sont lances", #r.jets, 2)
attendu("et on garde le PIRE", r.garde, math.min(r.jets[1], r.jets[2]))
attendu("le texte le dit",
    LCM.Roll.Describe(r):find("désavantage") ~= nil, true)

-- L'avantage, lui, se choisit — et seulement parmi les bonus positifs.
local ra = LCM.Roll.Field(moi, "escalade", { avantage = true })
attendu("avantage accorde", ra.avantage, true)
attendu("on garde le MEILLEUR", ra.garde, math.max(ra.jets[1], ra.jets[2]))

-- Les refus.
attendu("avantage sur un jet penalise : refuse",
    select(1, B3.Enregistrer("traits", { id = "faux_a", label = "Faux", cout = 2,
        bonus = { escalade = 1, vol_a_la_tire = -1 }, avantage = { "vol_a_la_tire" } }, true)), false)
attendu("avantage sur un jet qu'on ne touche pas : refuse",
    select(1, B3.Enregistrer("traits", { id = "faux_b", label = "Faux", cout = 2,
        bonus = { escalade = 1 }, avantage = { "nage" } }, true)), false)
attendu("deux avantages pour un trait de niveau 1 : refuse",
    select(1, B3.Enregistrer("traits", { id = "faux_c", label = "Faux", cout = 1,
        bonus = { escalade = 1, acrobaties = 1 }, avantage = { "escalade", "acrobaties" } }, true)), false)
attendu("deux avantages pour un niveau 2 : accepte",
    select(1, B3.Enregistrer("traits", { id = "vrai_c", label = "Vrai", cout = 2,
        bonus = { escalade = 1, acrobaties = 1 }, avantage = { "escalade", "acrobaties" } }, true)), true)

LCM.Traits.Revoke(moi, "grimpeur_malhabile")
B3.Supprimer("traits", "grimpeur_malhabile")
B3.Supprimer("traits", "vrai_c")

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
