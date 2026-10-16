-- Scinder une pile (16 octobre 2026) : clic droit > « Scinder », ou Maj +
-- glisser vers une case. Un petit panneau demande « combien », et le nouveau
-- tas part dans une case vide — la premiere libre au clic droit, celle ou l'on
-- lache au Maj + glisser.
--
-- Contenu TEMOIN : un sac et une ressource d'essai.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

LCM.Brouillons.Set("sacs", { id = "sac_scinder", label = "Sac témoin", places = 6 })
LCM.Brouillons.Set("ressources", { id = "herbe_scinder", label = "Herbe" })
LCM.Brouillons.Set("ressources", { id = "pierre_scinder", label = "Pierre", pileMax = 20 })
local HERBE, PIERRE = "ressources/herbe_scinder", "ressources/pierre_scinder"
__declencher("PLAYER_LOGIN")
local I = LCM.Inventaire
__personnage()
local moi = LCM.Entities.Self()
I.Poser(moi, "sacs", 1, "sac_scinder", true)
I.Ranger(moi, "sacs", 1, 1, HERBE, 10)
local function Q(case)
    local c = I.Case(I.Emplacement(moi, "sacs", 1), case)
    return c and c.quantite or 0
end

-- En JOUEUR : scinder n'est pas un geste du MJ.
LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = false

dire("== le coeur")
local ok, raison = I.Scinder(moi, "sacs", 1, 1, 10)
attendu("tout sortir : refuse", ok, false)
attendu("  et dit pourquoi", raison, "entre 1 et 9 : il doit en rester au moins un dans la pile.")
attendu("  rien n'a bouge", Q(1), 10)
attendu("zero : refuse", (I.Scinder(moi, "sacs", 1, 1, 0)), false)
attendu("illisible : refuse", (I.Scinder(moi, "sacs", 1, 1, "trois")), false)

dire("== clic droit > Scinder")
local s = LCM.UI.Inventaires.OuvrirSac("sacs", 1)
local function Case(n)
    for _, b in ipairs(s.cases) do if b:IsShown() and b.index == n then return b end end
end
local menu = LCM.UI.MenuContexte()
local function cliquer(libelle)
    for _, l in ipairs(menu.lignes) do
        if l:IsShown() and l.texte:GetText() == libelle then l:Click() return true end
    end
    return false
end
Case(1):Click("RightButton")
attendu("le menu propose Scinder", cliquer("Scinder"), true)
local d = LCM.UI.Inventaires.demandeScinder
attendu("un petit panneau s'ouvre", d and d:IsShown(), true)
attendu("  il demande combien", d.titre:GetText(), "Scinder en combien ? « Herbe » x10")
attendu("  la moitie par defaut", d.saisie:GetText(), "5")
attendu("  son bouton dit le geste", d.valider.label:GetText(), "Scinder")
d.saisie:Saisir("12")
d.valider:Click()
attendu("trop : le panneau reste et dit pourquoi", d.message:GetText(), "entre 1 et 9 : il doit en rester au moins un dans la pile.")
d.saisie:Saisir("3")
d.valider:Click()
attendu("le panneau se ferme", d:IsShown(), false)
attendu("il en reste 7", Q(1), 7)
attendu("3 dans la premiere case libre", Q(2), 3)
attendu("la case le montre", Case(2).nombre:GetText(), "x3")

dire("== une pile d'un seul ne propose pas Scinder")
I.Ranger(moi, "sacs", 1, 6, HERBE, 1)
s:Rafraichir()
Case(6):Click("RightButton")
attendu("pas de Scinder", cliquer("Scinder"), false)
menu:Hide()

dire("== Maj + glisser vers une case")
local function GlisserVers(depart, arrivee)
    __touches.shift = true
    __souris.LeftButton = true
    depart:GetScript("OnDragStart")(depart)
    __touches.shift = false
    arrivee.__survol = true
    __avancer(0.02, 0.02)
    __souris.LeftButton = false
    __avancer(0.02, 0.02)
    arrivee.__survol = nil
end
GlisserVers(Case(1), Case(5))
attendu("le panneau s'ouvre", d:IsShown(), true)
attendu("  rien n'a encore bouge", Q(1) .. "/" .. Q(5), "7/0")
d.saisie:Saisir("2")
d.valider:Click()
attendu("2 dans la case visee", Q(5), 2)
attendu("5 restent", Q(1), 5)
-- Vers une case d'un AUTRE objet : refuse. (Vers une pile du meme objet,
-- c'est permis depuis le reempilement, plus bas.)
I.Ranger(moi, "sacs", 1, 3, PIERRE, 1)
s:Rafraichir()
GlisserVers(Case(1), Case(3))
attendu("vers un autre objet : rien ne s'ouvre", d:IsShown(), false)
attendu("  rien n'a bouge", Q(1) .. "/" .. Q(3), "5/1")
I.Vider(moi, "sacs", 1, 3)
s:Rafraichir()

dire("== Maj + glisser lache hors d'une case : rien")
__position(5, 5, 0)
__touches.shift = true
__souris.LeftButton = true
Case(1):GetScript("OnDragStart")(Case(1))
__touches.shift = false
__avancer(0.02, 0.02)
__souris.LeftButton = false
__avancer(0.02, 0.02)
attendu("la pile n'est pas tombee au sol", Q(1), 5)
attendu("  et rien ne s'ouvre", d:IsShown(), false)

dire("== sans Maj, glisser deplace toujours la pile entiere")
__souris.LeftButton = true
Case(1):GetScript("OnDragStart")(Case(1))
Case(4).__survol = true
__avancer(0.02, 0.02)
__souris.LeftButton = false
__avancer(0.02, 0.02)
Case(4).__survol = nil
attendu("la pile a demenage, entiere", Q(1) .. "/" .. Q(4), "0/5")

dire("== reempiler : glisser une pile sur une pile du meme objet")
-- Elle disait « cette case est déjà occupée » (le MJ, 16 octobre 2026).
local function Glisser(depart, arrivee)
    __souris.LeftButton = true
    depart:GetScript("OnDragStart")(depart)
    arrivee.__survol = true
    __avancer(0.02, 0.02)
    __souris.LeftButton = false
    __avancer(0.02, 0.02)
    arrivee.__survol = nil
end
-- Etat : 3 en case 2, 2 en case 5, 5 en case 4, 1 en case 6 (herbe, sans max).
Glisser(Case(2), Case(4))
attendu("sans pile maximale : tout passe", Q(2) .. "/" .. Q(4), "0/8")
attendu("  la case de depart se vide", I.Case(I.Emplacement(moi, "sacs", 1), 2), nil)

dire("== pile maximale 20 : 10 sur 18")
for n = 1, 6 do I.Vider(moi, "sacs", 1, n) end
I.Ranger(moi, "sacs", 1, 1, PIERRE, 18)
I.Ranger(moi, "sacs", 1, 2, PIERRE, 10)
s:Rafraichir()
Glisser(Case(2), Case(1))
attendu("la cible se remplit a 20", Q(1), 20)
attendu("les 8 restants demeurent", Q(2), 8)
Glisser(Case(2), Case(1))
attendu("pleine : refuse", Q(1) .. "/" .. Q(2), "20/8")
local _, plein = I.Empiler(moi, "sacs", 1, 2, "sacs", 1, 1)
attendu("  et dit pourquoi", plein, "la pile est déjà pleine (20).")
Glisser(Case(1), Case(2))
attendu("dans l'autre sens : 12 passent, 8 restent", Q(2) .. "/" .. Q(1), "20/8")

dire("== Maj + glisser sur une pile du meme objet")
I.Vider(moi, "sacs", 1, 2)
I.Ranger(moi, "sacs", 1, 2, PIERRE, 15)
s:Rafraichir()
GlisserVers(Case(1), Case(2))
attendu("le panneau s'ouvre", d:IsShown(), true)
d.saisie:Saisir("6")
d.valider:Click()
attendu("trop pour la place : refuse, et dit", d.message:GetText(), "cette pile n'a de place que pour 5.")
d.saisie:Saisir("5")
d.valider:Click()
attendu("5 ajoutes", Q(1) .. "/" .. Q(2), "3/20")

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
