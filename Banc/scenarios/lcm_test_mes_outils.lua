-- « Mes Outils » (le MJ, 25 octobre 2026, UI/MesOutils.lua).
--
-- Ce que ce scenario tient :
--   * le bouton est dans Objets, juste sous Inventaires, et son bandeau
--     s'ouvre a sa DROITE quand on le clique dans le menu radial ;
--   * rien d'equipe : un seul rond, « — », et rien d'autre ;
--   * un outil equipe dans Équipements > Outils y a son rond, et ses actions
--     sont celles de sa nature : la gourde Boire · Voir · Déséquiper, la
--     lanterne Allumer/Éteindre · Voir · Déséquiper, le scanner Voir ·
--     Déséquiper ;
--   * Boire se sert de la gourde SANS la reprendre de la ceinture ;
--   * Voir ouvre la vue propre a l'outil (breve pour un contenant) ;
--   * Déséquiper la rend au sac, et le bandeau suit.
--
-- Tout se pose sur du contenu TEMOIN (CLAUDE.md) ; le scanner vient de
-- Data/OutilsCeinture.lua, du code.
local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

local B = LCM.Brouillons
B.Set("races", { id = "temoin", label = "Témoin", morphology = "humanoide" })
B.Set("listes", { id = "t_boisson", label = "Boisson témoin", liste = "consommables" })
B.Set("consommables", { id = "eau", label = "Eau", type = "t_boisson", bonus = { ["rend:fatigue"] = 4 } })
B.Set("objets", { id = "gourde_temoin", label = "Gourde témoin", categorie = "outil",
    contenant = { taille = 100, retrait = 25, types = { "t_boisson" }, depart = "consommables/eau" } })
__declencher("PLAYER_LOGIN")
__personnage()

local I, O, L, K = LCM.Inventaire, LCM.Objets, LCM.Lanterne, LCM.Contenants
local M, R, UI = LCM.UI.Menu, LCM.UI.Radial, LCM.UI
local moi = LCM.Entities.Self()
LCM.Entities.Set_Value(moi, "race", "temoin")
L.Reinitialiser()
LCM.Lanternes.Add({ id = "temoin_outils", label = "Lanterne témoin", multiplicateur = 1 })
LCM.Cristaux.Add({ id = "temoin_outils", label = "Cristal témoin", duree = 100 })
LCM.Sacs.Add({ id = "temoin_sac", label = "Sac témoin", places = 12, icone = "inv_misc_bag_30" })
attendu("le sac temoin est porte", I.Poser(moi, "sacs", 1, "temoin_sac", true), true)
attendu("une gourde au sac", I.Deposer(moi, "objets/gourde_temoin", 1), true)
attendu("une lanterne au sac", I.Deposer(moi, "lanternes/temoin_outils", 1), true)
attendu("un cristal au sac", I.Deposer(moi, "cristaux/temoin_outils", 1), true)
attendu("le scanner au sac", I.Deposer(moi, "objets/outil_scanner_valrazkah", 1), true)

local alertes = {}
LCM.Alerte = function(texte) alertes[#alertes + 1] = tostring(texte) end

dire("== le bouton, sous Inventaires")
local ids = {}
for _, e in ipairs(M.Trouver("objets").enfants) do ids[#ids + 1] = e.id end
attendu("Objets", table.concat(ids, ","), "equipement,inventaires,mes_outils,metiers")
attendu("il s'appelle Mes Outils", M.Trouver("mes_outils").label, "Mes Outils")
attendu("il est branche", M.EstLiee("mes_outils"), true)

dire("== il s'ouvre a sa droite, depuis le radial")
R.Basculer("fenetres")
__avancer(1)
local c = R.frame.couronnes["fenetres"]
for i = 1, c.nombreCategories do
    if c.boutonsCategorie[i].cible.id == "objets" then c.boutonsCategorie[i]:Click() end
end
__avancer(1)
local bouton = R.BoutonEntree("mes_outils")
attendu("le bouton est a l'ecran", bouton ~= nil, true)
bouton:Click()
local f = UI.MesOutils.frame
attendu("le bandeau s'ouvre", f and f:IsShown(), true)
-- Le retour prend la PLACE du bouton (le MJ, 25 octobre 2026) : le bandeau
-- est centre sur lui, et ce qu'il ouvre part vers la droite.
local point, ancre, relatif = f:GetPoint(1)
attendu("centre sur le bouton", point .. ">" .. relatif, "CENTER>CENTER")
attendu("  sur CE bouton", ancre == bouton, true)
local _, _, _, tx, ty = f.tete:GetPoint(1)
attendu("le retour est a sa place exacte", tx .. "," .. ty, "0,0")
attendu("  et dit <", f.tete.glyphe:GetText(), "<")
attendu("  avec les vignettes du radial", f.tete.magie ~= nil, true)
local _, _, _, ox = f.outils[1]:GetPoint(1)
attendu("les outils s'ouvrent a droite", ox > 0, true)

dire("== rien d'equipe : un seul rond, vide")
local function ronds()
    local n = 0
    for _, b in ipairs(f.outils) do if b:IsShown() then n = n + 1 end end
    return n
end
attendu("un seul rond", ronds(), 1)
attendu("il dit —", f.outils[1].glyphe:GetText(), "—")
f.outils[1]:Click()
attendu("aucune action", f.nombreActions, 0)
attendu("on dit ou equiper", alertes[#alertes] and alertes[#alertes]:find("Équipements › Outils") ~= nil, true)

dire("== la gourde")
attendu("equipee", (O.Equiper(moi, "gourde_temoin")), true)
f:Afficher()
attendu("un rond", ronds(), 1)
attendu("c'est la gourde", f.outils[1].porte.id, "gourde_temoin")
attendu("avec son icone", f.outils[1].icone:GetTexture() ~= nil and f.outils[1].glyphe:GetText() == "", true)
local function actions()
    local out = {}
    for i = 1, f.nombreActions do out[#out + 1] = f.actions[i].action.label end
    return table.concat(out, ",")
end
local function Clic(label)
    for i = 1, f.nombreActions do
        if f.actions[i].action.label == label then f.actions[i]:Click() return true end
    end
    return false
end
f.outils[1]:Click()
attendu("ses actions", actions(), "Boire,Voir,Déséquiper")
attendu("le rond choisi s'allume", f.outils[1].choisi, true)
attendu("elle est pleine d'eau", K.Pourcent(K.Porte(moi, 1)), 100)
LCM.Entities.SetGauge(moi, "fatigue", 0)
Clic("Boire")
attendu("la gorgee rend +4 en fatigue", LCM.Entities.Gauge(moi, "fatigue").current, 4)
attendu("il reste 75 %", K.Pourcent(K.Porte(moi, 1)), 75)
attendu("la gourde reste equipee", O.Porte(moi, "gourde_temoin"), true)
attendu("et ne revient pas au sac", O.Possede(moi, "gourde_temoin"), false)
Clic("Voir")
local v = UI.MesOutils.contenant
attendu("la vue du contenant s'ouvre", v and v:IsShown(), true)
-- L'habillage ecrit les titres de fenetre en capitales (UI.Majuscules).
attendu("  son titre", v.titre and v.titre:GetText() or v:GetName(), "GOURDE TÉMOIN")
attendu("  ce qu'elle contient", v.texte:GetText(), "Contient : Eau")
attendu("  a combien", v.barre.label:GetText(), "75 %")
attendu("  combien d'usages", v.usages:GetText(), "3 usages restants")
for _ = 1, 3 do Clic("Boire") end
attendu("bue jusqu'au bout", K.Pourcent(K.Porte(moi, 1)), 0)
attendu("la vue le dit", v.texte:GetText(), "Vide.")
Clic("Boire")
attendu("vide, elle refuse", alertes[#alertes], "il est vide.")

dire("== la lanterne")
attendu("equipee", (L.EquiperLanterne("temoin_outils")), true)
f:Afficher()
attendu("deux ronds", ronds(), 2)
attendu("la lanterne est la seconde", f.outils[2].porte.genre, "lanterne")
attendu("la gourde garde son choix", actions(), "Boire,Voir,Déséquiper")
f.outils[2]:Click()
attendu("un seul outil choisi a la fois", f.outils[1].choisi, false)
attendu("ses actions, eteinte", actions(), "Allumer,Voir,Déséquiper")
Clic("Allumer")
attendu("sans cristal, elle refuse", L.Allumee(), false)
attendu("  et dit pourquoi", alertes[#alertes] ~= nil, true)
attendu("un cristal se pose", (L.ChoisirCristal(L.CristauxPortes()[1].id)), true)
Clic("Allumer")
attendu("elle s'allume", L.Allumee(), true)
attendu("le bouton dit maintenant Éteindre", actions(), "Éteindre,Voir,Déséquiper")
Clic("Voir")
local vl = UI.Lanterne.frame
attendu("la vue de la lanterne s'ouvre", vl and vl:IsShown(), true)
attendu("  son cristal", vl.cristal.label:GetText(), L.LibelleCristal(L.CristalPose()))
attendu("  le bouton propose d'eteindre", vl.allumer.label:GetText(), "Éteindre")
vl.allumer:Click()
attendu("  et eteint", L.Allumee(), false)
attendu("le bandeau suit", actions(), "Allumer,Voir,Déséquiper")
Clic("Déséquiper")
attendu("la lanterne est retiree", L.IdEquipe(moi), nil)
attendu("  au sac", I.Chercher(moi, "lanternes/temoin_outils") ~= nil, true)
attendu("plus qu'un rond", ronds(), 1)
attendu("et plus d'actions (son choix est parti)", f.nombreActions, 0)
__avancer(1)
attendu("sa vue s'est refermee", vl:IsShown(), false)

dire("== la gourde rendue, le scanner a sa place")
f.outils[1]:Click()
Clic("Déséquiper")
attendu("la gourde est au sac", O.Possede(moi, "gourde_temoin"), true)
attendu("  avec son contenu (vide)", O.Porte(moi, "gourde_temoin"), false)
attendu("de nouveau le rond vide", f.outils[1].glyphe:GetText(), "—")
attendu("sa vue se referme", v:IsShown(), false)
attendu("le scanner s'equipe", (O.Equiper(moi, "outil_scanner_valrazkah")), true)
__avancer(1)
attendu("le bandeau l'a vu de lui-meme", f.outils[1].porte and f.outils[1].porte.id, "outil_scanner_valrazkah")
f.outils[1]:Click()
attendu("ses actions", actions(), "Voir,Déséquiper")
Clic("Voir")
attendu("le scanner s'ouvre", UI.Scanner.frame and UI.Scanner.frame:IsShown(), true)

dire("== il se referme")
f.tete:Click()
attendu("par son bouton de tete", f:IsShown(), false)
bouton:Click()
attendu("rouvert", f:IsShown(), true)
bouton:Click()
attendu("le bouton du menu le referme aussi", f:IsShown(), false)
bouton:Click()
R.Fermer()
__avancer(1)
attendu("et il part avec le radial", f:IsShown(), false)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
