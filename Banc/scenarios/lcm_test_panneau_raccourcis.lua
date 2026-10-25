-- Les Raccourcis (le MJ, 25 octobre 2026) : Alt + clic sur le sceau
-- (UI/PanneauRaccourcis.lua, Core/Raccourcis.lua).
--
-- Ce que ce scenario tient :
--   * Alt + clic ouvre le panneau, centre sur le sceau, vers la droite ; un
--     clic simple le referme et ouvre les fenetres, comme avant ;
--   * vide, il ne montre que « + » ;
--   * le « + » propose les fenetres du menu, les outils et les sorts des
--     grimoires possedes, par groupes, et rien de ce qui y est deja ;
--   * une fenetre s'ouvre, un sort se lance, un outil equipe deplie ses
--     actions (celles de Mes Outils), un outil non equipe le dit ;
--   * clic droit : deplacer, retirer ; plein, le « + » le dit ;
--   * la sauvegarde ne retient que des references, et s'efface vide ;
--   * les raccourcis CLAVIER (UI/Raccourcis.lua, meme mot) sont intacts.
--
-- Tout se pose sur du contenu TEMOIN (CLAUDE.md).
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

local I, O, K, RC = LCM.Inventaire, LCM.Objets, LCM.Contenants, LCM.Raccourcis
local R, UI = LCM.UI.Radial, LCM.UI
local P = UI.PanneauRaccourcis
local moi = LCM.Entities.Self()
LCM.Entities.Set_Value(moi, "race", "temoin")
LCM.Sacs.Add({ id = "temoin_sac", label = "Sac témoin", places = 12, icone = "inv_misc_bag_30" })
attendu("le sac temoin est porte", I.Poser(moi, "sacs", 1, "temoin_sac", true), true)
attendu("une gourde au sac", I.Deposer(moi, "objets/gourde_temoin", 1), true)
LCM.Sorts.Ajouter(moi, { label = "Trait témoin", icone = "spell_frost_frostbolt", jet = { min = 1, max = 20 } })
local sort = LCM.Sorts.Liste(moi)[1]
local personnel = LCM.Grimoires.Personnel()

local alertes = {}
LCM.Alerte = function(texte) alertes[#alertes + 1] = tostring(texte) end

dire("== les raccourcis clavier n'ont pas bouge")
attendu("UI.Raccourcis est toujours le clavier", UI.Raccourcis ~= P and UI.Raccourcis ~= nil, true)

dire("== Alt + clic sur le sceau")
local sceau = R.frame.sceau
__touches = { alt = true }
sceau:Click("LeftButton")
__touches = {}
local f = P.frame
attendu("le panneau s'ouvre", f and f:IsShown(), true)
local point, ancre, relatif = f:GetPoint(1)
attendu("centre sur le sceau", (ancre == sceau) and (point .. ">" .. relatif) or "ailleurs", "CENTER>CENTER")
attendu("aucune couronne ouverte", R.frame.couronnes.fenetres.ouvert and true or false, false)
attendu("vide : le seul rond est +", f.boutons[1].plus and f.boutons[1].glyphe:GetText(), "+")
attendu("a droite du sceau", select(4, f.boutons[1]:GetPoint(1)) > 0, true)
attendu("aux vignettes du radial", f.boutons[1].magie ~= nil, true)
attendu("rien en sauvegarde", LCM.db.raccourcis, nil)

dire("== le + propose, par groupes")
f.boutons[1]:Click()
local choix = _G.LCM_Choix_raccourcis
attendu("la liste s'ouvre", choix and choix:IsShown(), true)
local groupes, refs = {}, {}
for _, o in ipairs(P.Candidats(moi)) do groupes[o.groupe] = true refs[o.id] = o end
attendu("les fenetres", refs["fenetre:fiche"] ~= nil, true)
attendu("pas Mes Outils (chaque outil se met lui-meme)", refs["fenetre:mes_outils"], nil)
attendu("les outils, meme au sac", refs["outil:gourde_temoin"] ~= nil, true)
attendu("les sorts", refs["sort:" .. personnel.id .. ":" .. sort.id] ~= nil, true)
attendu("  dans le groupe de leur grimoire", refs["sort:" .. personnel.id .. ":" .. sort.id].groupe:find("^Sorts · ") ~= nil, true)
local ligneFiche
for _, l in ipairs(choix.lignes) do if l:IsShown() and l.choix == "fenetre:fiche" then ligneFiche = l end end
attendu("la fiche est dans la liste", ligneFiche ~= nil, true)
ligneFiche:Click()
attendu("elle est ajoutee", RC.Liste(moi)[1], "fenetre:fiche")
attendu("le + passe apres elle", f.boutons[2].plus, true)
attendu("elle n'est plus proposee", (function()
    for _, o in ipairs(P.Candidats(moi)) do if o.id == "fenetre:fiche" then return true end end
    return false
end)(), false)
attendu("la sauvegarde ne garde que la reference", table.concat(LCM.db.raccourcis[moi.id], ","), "fenetre:fiche")

dire("== une fenetre s'ouvre")
f.boutons[1]:Click()
attendu("la fiche est ouverte", UI.Fiche.Fenetre():IsShown(), true)
UI.Fiche.Fenetre():Hide()

dire("== un sort se lance")
attendu("ajoute", (RC.Ajouter(moi, "sort:" .. personnel.id .. ":" .. sort.id, 8)), true)
f:Afficher()
attendu("il a son nom", f.boutons[2].legende:GetText(), "Trait témoin")
local avant = #__sorties
f.boutons[2]:Click()
attendu("le jet part", #__sorties > avant and __sansCouleur(__sorties[#__sorties]):find("Trait témoin") ~= nil, true)

dire("== un outil : equipe, il se sert")
attendu("ajoute", (RC.Ajouter(moi, "outil:gourde_temoin", 8)), true)
f:Afficher()
local gourde = f.boutons[3]
attendu("au sac, il est eteint", gourde.disponible, false)
gourde:Click()
attendu("  et dit pourquoi", alertes[#alertes], "« Gourde témoin » n'est pas équipé : Équipements › Outils.")
attendu("equipee", (O.Equiper(moi, "gourde_temoin")), true)
f:Afficher()
attendu("il s'allume", gourde.disponible, true)
gourde:Click()
local actions = {}
for i = 1, f.nombreActions do actions[#actions + 1] = f.actions[i].action.label end
attendu("ses actions sont celles de Mes Outils", table.concat(actions, ","), "Boire,Voir,Déséquiper")
LCM.Entities.SetGauge(moi, "fatigue", 0)
f.actions[1]:Click()
attendu("Boire boit", LCM.Entities.Gauge(moi, "fatigue").current, 4)
attendu("  a la ceinture", K.Pourcent(K.Porte(moi, 1)), 75)
gourde:Click()
attendu("un second clic replie", f.nombreActions, 0)

dire("== clic droit : deplacer, retirer")
gourde:Click("RightButton")
local menu = UI.MenuContexte()
local function Option(texte)
    for _, l in ipairs(menu.lignes) do
        if l:IsShown() and l.texte:GetText() == texte then l:Click() return true end
    end
    return false
end
attendu("le dernier ne va pas plus a droite", (function()
    for _, l in ipairs(menu.lignes) do if l:IsShown() and l.texte:GetText() == "Vers la droite" then return true end end
    return false
end)(), false)
attendu("vers la gauche", Option("Vers la gauche"), true)
attendu("l'ordre suit", table.concat(RC.Liste(moi), ","),
    "fenetre:fiche,outil:gourde_temoin,sort:" .. personnel.id .. ":" .. sort.id)
f.boutons[1]:Click("RightButton")
attendu("retirer", Option("Retirer"), true)
attendu("la fiche est partie", RC.Liste(moi)[1], "outil:gourde_temoin")

dire("== plein")
for i = 1, 6 do RC.Ajouter(moi, "fenetre:x" .. i, 8) end
attendu("huit raccourcis", #RC.Liste(moi), 8)
local refus, raison = RC.Ajouter(moi, "fenetre:x7", 8)
attendu("le neuvieme est refuse", refus, false)
attendu("  et on dit pourquoi", raison, "tes raccourcis sont pleins (8) : retires-en un d'abord.")
f:Afficher()
attendu("le + reste, eteint", f.boutons[9].plus and f.boutons[9].disponible, false)
f.boutons[9]:Click()
attendu("  et le dit", alertes[#alertes], "tes raccourcis sont pleins (8) : retires-en un d'abord.")
attendu("une fenetre disparue reste, eteinte", f.boutons[3].disponible, false)
attendu("  et le dit", f.boutons[3].resolu.eteint, "cette fenêtre n'existe plus.")

dire("== tout retire, la sauvegarde s'efface")
while RC.Liste(moi)[1] do RC.Retirer(moi, 1) end
attendu("plus rien en sauvegarde", LCM.db.raccourcis, nil)

dire("== un clic simple referme et ouvre les fenetres")
sceau:Click("LeftButton")
attendu("le panneau se ferme", f:IsShown(), false)
attendu("les fenetres s'ouvrent", R.frame.couronnes.fenetres.ouvert and true or false, true)
__touches = { alt = true }
sceau:Click("LeftButton")
__touches = {}
attendu("Alt + clic : la couronne se ferme", R.frame.couronnes.fenetres.ouvert and true or false, false)
attendu("  et le panneau s'ouvre", f:IsShown(), true)
__touches = { alt = true }
sceau:Click("LeftButton")
__touches = {}
attendu("un second Alt + clic le referme", f:IsShown(), false)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
