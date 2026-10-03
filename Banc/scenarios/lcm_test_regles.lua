-- Les regles du template Necronicon, calculees a la main pour comparaison :
-- apports des primaires aux expertises, deplacement, PA, fatigue, initiative,
-- PV, et ce qu'un objet qui donne une primaire change a tout cela.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

LCM.Brouillons.Set("objets", { id = "gantelets", label = "Gantelets de force", categorie = "equipement",
    bonus = { force = 2, depl_terrestre = 1, pa = 1 } })
LCM.Brouillons.Set("traits", { id = "coureur", label = "Coureur", cout = 1, bonus = { course = 2 } })

__declencher("PLAYER_LOGIN")
__personnage()   -- ce scenario joue un personnage : il le dit
local F = LCM.Formules
local E = LCM.Entities
local moi = E.Self()
local function poser(t) for k, v in pairs(t) do E.Set_Value(moi, k, v) end end
poser({ niveau = 5, force = 4, mystique = 2, perception = 6, adresse = 3, esprit = 2, constitution = 5 })

dire("== apports des primaires aux expertises")
-- Course : 0,25 x Force + 0,25 x Adresse = 1 + 0,75 = 1,75 -> 1
attendu("course sans investir", F.Expertise(moi, "course"), 1)
E.Set_Value(moi, "course", 3)
attendu("course avec 3 investis", F.Expertise(moi, "course"), 4)
-- Vue : 0,33 x 6 = 1,98 -> 1
attendu("vue", F.Expertise(moi, "vue"), 1)
-- Projection : 1 x 4 + 0,25 x (3 + 6 + 5) = 7,5 -> 7
attendu("projection", F.Expertise(moi, "projection"), 7)
-- Crochetage lit Toucher (0,33 x 6 -> 1) et Ouie (-> 1) :
-- 0,35 x 3 + 0,25 x 6 + 0,25 x 1 + 0,25 x 1 = 1,05 + 1,5 + 0,5 = 3,05 -> 3
attendu("crochetage (via d'autres expertises)", F.Expertise(moi, "crochetage"), 3)
-- Elementaire : 0,25 x esprit 2 + 0,25 x mystique 2 + 0,16 x 6 + 0,15 x pen_feu 4
E.Set_Value(moi, "pen_feu", 4)
-- = 0,5 + 0,5 + 0,96 + 0,6 = 2,56 -> 2
attendu("elementaire (penetrations comprises)", F.Expertise(moi, "elementaire"), 2)
attendu("l'initiative n'a pas d'apport", F.Apport(moi, "initiative"), 0)

dire("== le jet additionne l'apport")
math.randomseed(2)
local r = LCM.Roll.Field(moi, "course")
attendu("valeur investie", r.valeur, 3)
attendu("apport", r.apport, 1)
attendu("total", r.total, r.garde + 3 + 1)
dire("   " .. LCM.Roll.Describe(r))

dire("== la fiche montre investi + apport, puis les bonus")
LCM.Traits.Grant(moi, "coureur")
local fe = LCM.UI.Vues.Fenetre("expertise")
fe:Montrer(moi)
fe:Afficher("athletisme")
local course
for _, l in ipairs(fe.pages.athletisme.lignes) do if l.label:GetText() == "Course" then course = l end end
attendu("Course : valeur 4", course.valeur:GetText(), "4")
attendu("Course : bonus +2", course.bonus:GetText(), "+2")
fe:Hide()

dire("== deplacement (template : base + investi + secondaires)")
-- Terrestre : 8 + 3 (Course investie, pas sa valeur totale) + 0 = 11
attendu("terrestre", E.Get_Value(moi, "depl_terrestre"), 11)
E.Set_Value(moi, "sec_deplacement", 2)
attendu("+ 2 points secondaires", E.Get_Value(moi, "depl_terrestre"), 13)
-- Nage : 5 + 0 + 2 = 7
attendu("nage", E.Get_Value(moi, "depl_nage"), 7)

dire("== points d'action (4 + secondaires)")
attendu("PA max", E.Gauge(moi, "pa").max, 4)
E.Set_Value(moi, "sec_pa", 1)
attendu("PA max + 1 secondaire", E.Gauge(moi, "pa").max, 5)

dire("== initiative (secondaires + niveau/2 + esprit/2 + perception/2)")
-- 0 + 2,5 + 1 + 3 = 6,5 -> 6
attendu("initiative", E.Get_Value(moi, "initiative"), 6)

dire("== fatigue et PV")
-- Fatigue : 15 + 2x5 + 2 + 2x5 + Endurance (0 + 0,35x5 -> 1) + 0 = 38
attendu("fatigue max", E.Gauge(moi, "fatigue").max, 38)
-- PV : 2 + 7,5 + 0 + 5 x (2 + 5 x 0,25) = 9,5 + 16,25 = 25,75 -> 25
attendu("PV max", E.Get_Value(moi, "pv_max"), 25)

dire("== un objet qui donne de la Force change tout ce qui en depend")
attendu("equipe (geste brut : les regles, pas les sacs)", LCM.Objets.Placer(moi, "gantelets"), true)
attendu("force totale", F.Primaire(moi, "force"), 6)
attendu("force saisie inchangee", E.Get_Value(moi, "force"), 4)
-- Course : 3 + (0,25 x 6 + 0,25 x 3 = 2,25 -> 2) + 2 (trait) = 7
attendu("course monte", F.Expertise(moi, "course"), 7)
attendu("terrestre + 1 (objet)", E.Get_Value(moi, "depl_terrestre"), 14)
attendu("PA + 1 (objet)", E.Gauge(moi, "pa").max, 6)

dire("== un trait ne donne toujours pas de primaire")
local ok = pcall(LCM.Traits.Add, { id = "triche", label = "Triche", bonus = { force = 1 } })
attendu("refuse", ok, false)

dire("== l'atelier propose les primaires aux objets seulement")
LCM.UI.Atelier.Basculer()
local f = LCM.UI.Atelier.Fenetre()
local function proposeForce(famille, bouton)
    f:ChoisirFamille(famille)
    f.panneaux[famille].ajoutBonus:Click()
    local vu, deplacement, fatigue = false, false, false
    for _, b in ipairs(f.choix.lignes) do
        if b:IsShown() and b.choix == "force" then vu = true end
        if b:IsShown() and b.choix == "depl_terrestre" then deplacement = true end
        if b:IsShown() and b.choix == "fatigue" then fatigue = true end
    end
    f.choix:Hide()
    return vu, deplacement, fatigue
end
local vu, depl, fat = proposeForce("traits")
attendu("trait : pas de Force", vu, false)
attendu("trait : Deplacement propose", depl, true)
attendu("trait : Fatigue proposee", fat, true)
vu = proposeForce("objets")
attendu("objet : Force proposee", vu, true)

dire("== la fenetre Deplacement")
-- Depuis le 3 octobre 2026, l'entree du menu ouvre la JAUGE : elle montre
-- l'allocation de la fiche et la decompte pendant qu'on marche, au lieu de
-- lire deux nombres qu'on ne pouvait pas utiliser.
LCM.UI.Menu.Trouver("deplacement").onClick()
local fd = LCM.UI.DeplacementForce.frame
attendu("ouverte", fd:IsShown(), true)
attendu("trois modes", #fd.modes, 3)
attendu("terrestre par defaut", fd.mode, "terrestre")
attendu("elle montre l'allocation de la fiche",
    fd.anneau.sur:GetText(), string.format("/ %s m", tostring(LCM.DeplacementForce.Allocation(nil, "terrestre"))))
fd.partir:Click()
attendu("on part", LCM.DeplacementForce.EnCours() ~= nil, true)
attendu("et les modes se verrouillent", fd.modes[2]:IsEnabled(), false)
__position(3, 0, 0)
LCM.DeplacementForce.Mesurer()
__position(0, 0, 0)
LCM.DeplacementForce.Mesurer()
attendu("le chemin parcouru compte, aller ET retour",
    select(1, LCM.DeplacementForce.Etat()), 6)
LCM.DeplacementForce.Arreter("interrompu")

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
