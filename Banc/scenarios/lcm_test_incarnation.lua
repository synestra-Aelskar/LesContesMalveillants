-- Incarner un PNJ : instances, bascule, fenetre.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
local I = LCM.Incarnation
local moi = LCM.Entities.Self()
local modele = LCM.PNJ.list[1]

dire("== au depart, on est soi")
attendu("personne d'incarne", I.Actuelle(), nil)
attendu("Self est mon personnage", LCM.Entities.Self().id, moi.id)
attendu("aucune instance", #I.Liste(), 0)

dire("== instancier un PNJ")
local garde = I.Instancier(modele.id)
attendu("cree", garde ~= nil, true)
attendu("identifiant lisible", garde.id, "pnj:" .. modele.id)
attendu("c'est un PNJ", garde.kind, "npc")
attendu("il porte le nom du modele", garde.name, modele.label)
attendu("et une copie de ses valeurs", garde.values ~= modele.valeurs, true)
local second = I.Instancier(modele.id, "Garde du fond")
attendu("deux instances du meme modele", second.id, "pnj:" .. modele.id .. "#2")
attendu("au nom qu'on veut", second.name, "Garde du fond")
attendu("inconnu : refuse", (I.Instancier("pnj_fantome")), nil)

dire("== les blessures de l'un ne sont pas celles de l'autre")
local avant = select(1, LCM.Body.Totals(garde))
LCM.Body.Damage(garde, LCM.Body.State(garde)[1].id, 3)
attendu("le premier est blesse", LCM.Body.Totals(garde) < avant, true)
attendu("le second est intact", LCM.Body.Totals(second), avant)
attendu("et le modele n'a pas bouge", modele.valeurs.corps, nil)

dire("== prendre la place")
attendu("pris", (I.Prendre(garde.id)), garde)
attendu("Self suit", LCM.Entities.Self().id, garde.id)
attendu("et le dit", I.ActuelleId(), garde.id)
I.Prendre(second.id)
attendu("on passe de l'un a l'autre", LCM.Entities.Self().id, second.id)
attendu("relache", I.Relacher(), true)
attendu("on redevient soi", LCM.Entities.Self().id, moi.id)
attendu("relacher deux fois ne fait rien", I.Relacher(), false)

dire("== reserve au maitre du jeu")
LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = false
local ok, raison = I.Prendre(garde.id)
attendu("un joueur ne peut pas", ok, nil)
attendu("et on lui dit", raison, "reserve au maitre du jeu.")
attendu("ni incarner directement", (I.Incarner(modele.id)), nil)
LCM._masterCompanion = true
__addonsCharges["LesContesMalveillants_MJ"] = true

dire("== la fenetre")
local f = LCM.UI.Incarner.Basculer()
attendu("ouverte", f:IsShown(), true)
attendu("le catalogue", #LCM.PNJ.list, 2)
attendu("deux en jeu", f.nombreEnJeu, 2)
attendu("le bandeau dit qu'on est soi", f.bandeau:GetText(), "Tu es toi-même.")
attendu("pas de bouton relacher", f.relacher:IsShown(), false)
f.modeles[1].prendre:Click()
attendu("une instance de plus", f.nombreEnJeu, 3)
attendu("et on l'incarne", LCM.Entities.Self().modele, modele.id)
attendu("le bandeau le dit", __sansCouleur(f.bandeau:GetText()):find("Tu incarnes") ~= nil, true)
attendu("le bouton relacher apparait", f.relacher:IsShown(), true)

dire("== la fiche suit l'incarnation")
local fiche = LCM.UI.Fiche.Fenetre()
fiche:Montrer(LCM.Entities.Self())
attendu("elle montre le PNJ", fiche.entity.kind, "npc")
f.relacher:Click()
attendu("et revient a moi quand on relache", fiche.entity.id, moi.id)
attendu("l'entree du menu est allumee", LCM.UI.Menu.EstLiee("incarner"), true)

dire("== oublier une instance")
attendu("oubliee", I.Oublier(second.id), true)
attendu("il en reste deux", #I.Liste(), 2)
-- Oublier celle qu'on incarne nous rend a nous-memes.
I.Prendre(garde.id)
I.Oublier(garde.id)
attendu("on redevient soi", LCM.Entities.Self().id, moi.id)
for _, instance in ipairs(I.Liste()) do I.Oublier(instance.id) end
attendu("plus rien en jeu", #I.Liste(), 0)
attendu("et la sauvegarde est nettoyee", LCM.charDb.incarnations, nil)

dire("== la commande")
SlashCmdList.LCM("incarner " .. modele.id)
attendu("elle incarne", LCM.Entities.Self().modele, modele.id)
SlashCmdList.LCM("incarner")
attendu("et relache", LCM.Entities.Self().id, moi.id)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
