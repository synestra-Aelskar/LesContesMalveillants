-- Choisir plusieurs objets dans l'inventaire, comme dans l'explorateur de
-- Windows (20 octobre 2026) : clic, Ctrl + clic, Maj + clic. Puis les glisser,
-- les deplacer, les donner ou les detruire ensemble — tout ou rien.
--
-- Le cas du joueur : quatre sacs, une ressource dans chacun ; on achete un
-- cinquieme sac ; clic dans A, Ctrl + clic dans B, C, D ; on glisse celle de D
-- dans E, et les quatre y passent.
local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

-- Des sacs et des objets temoins : le contenu de la campagne bouge.
LCM.Brouillons.Set("sacs", { id = "sac_a", label = "Sac A", places = 4 })
LCM.Brouillons.Set("sacs", { id = "sac_b", label = "Sac B", places = 4 })
LCM.Brouillons.Set("sacs", { id = "sacoche_c", label = "Sacoche C", nature = "sacoche", places = 4 })
LCM.Brouillons.Set("sacs", { id = "sacoche_d", label = "Sacoche D", nature = "sacoche", places = 4 })
LCM.Brouillons.Set("sacs", { id = "sacoche_e", label = "Sacoche E", nature = "sacoche", places = 4 })
__declencher("PLAYER_LOGIN")
__personnage()
local moi = LCM.Entities.Self()
local I, O, Ecran = LCM.Inventaire, LCM.Objets, LCM.UI.Inventaires
local S = Ecran.Selection
for _, nom in ipairs({ "a", "b", "c", "d", "x" }) do
    O.Add({ id = "pierre_" .. nom, label = "Pierre " .. nom:upper(), categorie = "arme" })
end
local function P(nom) return "objets/pierre_" .. nom end

I.Poser(moi, "sacs", 1, "sac_a", true)
I.Poser(moi, "sacs", 2, "sac_b", true)
I.Poser(moi, "saccoches", 1, "sacoche_c", true)
I.Poser(moi, "saccoches", 2, "sacoche_d", true)
I.Ranger(moi, "sacs", 1, 1, P("a"), 1)
I.Ranger(moi, "sacs", 2, 1, P("b"), 1)
I.Ranger(moi, "saccoches", 1, 1, P("c"), 1)
I.Ranger(moi, "saccoches", 2, 1, P("d"), 1)
attendu("on achete un cinquieme sac", (I.Deposer(moi, "sacs/sacoche_e", 1)), true)
attendu("  il se porte en sacoche 3", I.Contenant(I.Emplacement(moi, "saccoches", 3)).id, "sacoche_e")

local A = Ecran.OuvrirSac("sacs", 1)
local B = Ecran.OuvrirSac("sacs", 2)
local C = Ecran.OuvrirSac("saccoches", 1)
local D = Ecran.OuvrirSac("saccoches", 2)
local E = Ecran.OuvrirSac("saccoches", 3)
local function Case(onglet, index, n)
    local c = I.Case(I.Emplacement(moi, onglet, index), n)
    return c and c.ref
end
local function Touches(t) __touches = t or {} end

dire("== clic, Ctrl + clic : d'un sac a l'autre")
A.cases[1]:Click("LeftButton")
attendu("un clic choisit la case", S.Nombre(), 1)
attendu("  et elle s'eclaire", A.cases[1].choisie:IsShown(), true)
Touches({ ctrl = true })
B.cases[1]:Click("LeftButton")
C.cases[1]:Click("LeftButton")
D.cases[1]:Click("LeftButton")
Touches()
attendu("Ctrl + clic en ajoute, dans d'autres sacs", S.Nombre(), 4)
attendu("  chacune s'eclaire", A.cases[1].choisie:IsShown() and B.cases[1].choisie:IsShown()
    and C.cases[1].choisie:IsShown() and D.cases[1].choisie:IsShown(), true)
attendu("  pas une case vide", A.cases[2].choisie:IsShown(), false)

dire("== glisser celle de D dans E : les quatre suivent")
local function GlisserCase(source, cible)
    __souris.LeftButton = true
    source:GetScript("OnDragStart")(source)
    cible.__survol = true
    __avancer(0.02, 0.02)
    __souris.LeftButton = false
    __avancer(0.02, 0.02)
    cible.__survol = nil
end
GlisserCase(D.cases[1], E.cases[2])
attendu("celle qu'on a lachee est dans la case visee", Case("saccoches", 3, 2), P("d"))
local dansE = {}
for n = 1, 4 do dansE[#dansE + 1] = tostring(Case("saccoches", 3, n)):match("pierre_(%w)") or "-" end
attendu("les quatre sont dans E", table.concat(dansE, ","), "a,d,b,c")
attendu("A, B, C et D sont vides", tostring(Case("sacs", 1, 1)) .. tostring(Case("sacs", 2, 1))
    .. tostring(Case("saccoches", 1, 1)) .. tostring(Case("saccoches", 2, 1)), "nilnilnilnil")
attendu("la selection s'est videe", S.Nombre(), 0)

dire("== Maj + clic : de la case en surbrillance jusqu'a celle-ci")
E.cases[1]:Click("LeftButton")
Touches({ shift = true })
E.cases[3]:Click("LeftButton")
Touches()
attendu("trois cases, de 1 a 3", S.Nombre(), 3)
attendu("  la 4 n'en est pas", E.cases[4].choisie:IsShown(), false)
-- Un second Maj + clic refait la plage depuis la MEME ancre.
Touches({ shift = true })
E.cases[2]:Click("LeftButton")
Touches()
attendu("la plage se refait depuis l'ancre", S.Nombre(), 2)
-- D'un sac a l'autre, dans l'ordre de l'inventaire : A vient avant E.
I.Ranger(moi, "sacs", 1, 2, P("x"), 1)
A:Rafraichir()
A.cases[2]:Click("LeftButton")
Touches({ shift = true })
E.cases[1]:Click("LeftButton")
Touches()
attendu("Maj + clic traverse les sacs", S.Nombre(), 2)
E.cases[4]:Click("LeftButton")
attendu("un clic simple ne garde que lui", S.Nombre(), 1)
Touches({ ctrl = true })
E.cases[4]:Click("LeftButton")
Touches()
attendu("Ctrl + clic sur une case choisie la retire", S.Nombre(), 0)
A.cases[2]:Click("LeftButton")
A.cases[3]:Click("LeftButton")
attendu("un clic dans le vide deselectionne", S.Nombre(), 0)

dire("== le double-clic ouvre l'objet")
local vu
local voir = LCM.UI.Compendium.Voir
LCM.UI.Compendium.Voir = function(_, element) vu = element and element.id end
A.cases[2]:DoubleClick("LeftButton")
LCM.UI.Compendium.Voir = voir
attendu("double-clic : la carte de l'objet", vu, "pierre_x")
attendu("  et la case est choisie", S.Nombre(), 1)

dire("== tout ou rien : E est plein")
Touches({ ctrl = true })
E.cases[1]:Click("LeftButton")
Touches()
-- A2 et E1 choisies ; on les glisse sur la sacoche E pleine : A2 n'y tient pas.
local refus
local alerte = LCM.Alerte
LCM.Alerte = function(t) refus = t end
GlisserCase(A.cases[2], E.cases[3])
LCM.Alerte = alerte
attendu("rien n'a bouge", Case("sacs", 1, 2), P("x"))
attendu("  E est intact", Case("saccoches", 3, 1), P("a"))
local ok, raison = I.DeplacerGroupe(moi, S.Liste(), { onglet = "saccoches", index = 3 })
attendu("le refus le dit", ok, false)
attendu("  et dit pourquoi", tostring(raison):find("rien n'a bougé", 1, true) ~= nil, true)

dire("== le clic droit : les gestes de la selection")
local menu = LCM.UI.MenuContexte()
local function libelles()
    local t = {}
    for _, l in ipairs(menu.lignes) do if l:IsShown() then t[#t + 1] = l.texte:GetText() end end
    return table.concat(t, ",")
end
-- Le menu, puis son sous-menu (« Déplacer > ») : chacun ses lignes.
local function cliquer(libelle)
    for _, vivier in ipairs({ menu.lignes, menu.sousLignes }) do
        for _, l in ipairs(vivier) do
            if l:IsShown() and l.texte:GetText() == libelle then l:Click() return true end
        end
    end
    return false
end
A.cases[2]:Click("RightButton")
attendu("Déplacer, Échanger, Détruire", libelles(), "Déplacer >,Échanger,Détruire (2)")
menu:Hide()
-- Une case hors de la selection : son propre menu, et elle devient la
-- selection.
E.cases[4]:Click("RightButton")
attendu("hors selection : le menu de l'objet", libelles():match("^Voir") ~= nil, true)
attendu("  et elle seule est choisie", S.Nombre(), 1)
menu:Hide()

dire("== Déplacer > : la selection change de sac")
E.cases[2]:Click("LeftButton")
Touches({ ctrl = true })
E.cases[3]:Click("LeftButton")
Touches()
E.cases[2]:Click("RightButton")
cliquer("Déplacer >")
cliquer("Sac B")
attendu("les deux sont dans B", tostring(Case("sacs", 2, 1)):match("pierre_(%w)") .. ","
    .. tostring(Case("sacs", 2, 2)):match("pierre_(%w)"), "d,b")

dire("== Détruire (n) : une question, puis tout")
B.cases[1]:Click("LeftButton")
Touches({ shift = true })
B.cases[2]:Click("LeftButton")
Touches()
B.cases[1]:Click("RightButton")
cliquer("Détruire (2)")
local d = Ecran.confirmationGroupe
attendu("une confirmation", d ~= nil and d:IsShown(), true)
attendu("  qui nomme les objets", d.texte:GetText():find("Pierre D, Pierre B", 1, true) ~= nil, true)
d.non:Click()
attendu("annule : rien n'est detruit", Case("sacs", 2, 1), P("d"))
B.cases[1]:Click("RightButton")
cliquer("Détruire (2)")
-- Entre la question et la reponse, l'une a change : on ne detruit rien.
I.Vider(moi, "sacs", 2, 2)
I.Ranger(moi, "sacs", 2, 2, P("x"), 1)
d.oui:Click()
attendu("une case a change : rien n'est detruit", Case("sacs", 2, 1), P("d"))
B:Rafraichir()
B.cases[1]:Click("LeftButton")
Touches({ shift = true })
B.cases[2]:Click("LeftButton")
Touches()
B.cases[1]:Click("RightButton")
cliquer("Détruire (2)")
d.oui:Click()
attendu("detruites toutes les deux", tostring(Case("sacs", 2, 1)) .. tostring(Case("sacs", 2, 2)), "nilnil")

dire("== l'etat de chaque objet voyage avec lui")
O.Add({ id = "kit_sel", label = "Kit", categorie = "outil", etat = { max = 4 } })
I.Ranger(moi, "sacs", 2, 1, "objets/kit_sel", 1)
O.UserInventaire(moi, "kit_sel", 3)
I.Ranger(moi, "sacs", 2, 2, "objets/kit_sel", 1)
B:Rafraichir()
B.cases[1]:Click("LeftButton")
Touches({ ctrl = true })
B.cases[2]:Click("LeftButton")
Touches()
attendu("deux kits deplaces", (I.DeplacerGroupe(moi, S.Liste(), { onglet = "sacs", index = 1 })), true)
local etats = {}
for _, p in ipairs(I.Piles(moi, "objets/kit_sel")) do
    for _, e in ipairs(p.pile.exemplaires) do etats[#etats + 1] = tonumber(e.usure) or 0 end
end
table.sort(etats)
attendu("l'entame reste entame, le neuf reste neuf", table.concat(etats, ","), "0,3")

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
