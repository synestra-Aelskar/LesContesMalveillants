-- Grimoires : hub, possession, sous-grimoires, sorts.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end
local function dernierMessage() return __sansCouleur(__sorties[#__sorties] or "") end

__declencher("PLAYER_LOGIN")
__personnage()   -- ce scenario joue un personnage : il le dit
local G = LCM.Grimoires
local moi = LCM.Entities.Self()

dire("== le catalogue")
attendu("quatre grimoires importes, plus le personnel", #G.list, 5)
local importe = G.Get("grimoire_sans_fenetre_window_custom_17")
attendu("un grimoire importe", importe ~= nil, true)
attendu("un sous-grimoire", #G.SousGrimoires(importe), 1)
attendu("deux sorts", #G.Sorts(importe, 1), 2)
attendu("compte total", G.CompteSorts(importe), 2)

dire("== ton grimoire, celui qu'on a d'office")
local personnel = G.Personnel()
attendu("il existe", personnel.id, "grimoire_personnel")
attendu("possede sans qu'on le donne", G.Has(moi, personnel.id), true)
attendu("il ouvre la liste", G.Possedes(moi)[1].id, personnel.id)
attendu("et il est seul au depart", #G.Possedes(moi), 1)
attendu("rien n'est ecrit en sauvegarde", moi.grimoires, nil)
attendu("on ne peut pas le donner", (G.Donner(moi, personnel.id)), false)
attendu("ni le reprendre", G.Retirer(moi, personnel.id), false)

dire("== recevoir un grimoire")
attendu("donne", (G.Donner(moi, importe.id)), true)
attendu("possede", G.Has(moi, importe.id), true)
attendu("deux grimoires", #G.Possedes(moi), 2)
attendu("deux fois le meme : refuse", (G.Donner(moi, importe.id)), false)
attendu("un inconnu : refuse", (G.Donner(moi, "grimoire_fantome")), false)
attendu("l'identifiant est retenu", G.Ids(moi)[1], importe.id)

dire("== le hub")
local hub = LCM.UI.Grimoires.Basculer()
attendu("ouvert", hub:IsShown(), true)
attendu("deux tuiles", hub.nombreAffiche, 2)
local sienne, recue = hub.tuiles[1], hub.tuiles[2]
attendu("la sienne d'abord", sienne.grimoire.id, personnel.id)
attendu("son nom", recue.nom:GetText(), importe.label)
attendu("le compte de sorts", recue.compte:GetText():find("2 sorts") ~= nil, true)
attendu("l'apercu nomme les sorts", recue.apercu:GetText():find("Coupe tranchante") ~= nil, true)
attendu("on ne reprend pas le sien", sienne.reprendre:IsShown(), false)
attendu("mais on reprend ce qu'on a donne", recue.reprendre:IsShown(), true)

dire("== ouvrir un grimoire depuis le hub")
recue:Click()
local livre = LCM.UI.Grimoire.frame
attendu("la fenetre du grimoire s'ouvre", livre:IsShown(), true)
attendu("elle porte son nom", livre.grimoire.id, importe.id)
attendu("ses deux sorts", livre.nombreAffiche, 2)
attendu("le premier", livre.cartes[1].nom:GetText(), "Coupe tranchante")
attendu("son raccourci", livre.cartes[1].raccourci:GetText(), "raccourci : Coupe tranchante")
attendu("il a un jet", livre.cartes[1].jet:IsShown(), true)
attendu("le second n'en a pas", livre.cartes[2].jet:IsShown(), false)
attendu("et montre ses champs libres", livre.cartes[2].champs:GetText(), "NC   ·   NC")

dire("== lancer un sort")
livre.cartes[1].jet:Click()
attendu("le resultat est annonce", dernierMessage():find("Coupe tranchante") ~= nil, true)
attendu("avec sa plage", dernierMessage():find("%(1%-100%)") ~= nil, true)

dire("== plusieurs sous-grimoires")
-- Un grimoire fabrique pour le test : deux sous-grimoires, des sorts differents.
G.Add({ id = "grimoire_double", label = "Double", onglets = {
    { nom = "Premier",  sorts = { { id = "a", label = "Sort A" } } },
    { nom = "Deuxieme", sorts = { { id = "b", label = "Sort B" }, { id = "c", label = "Sort C" } } },
} })
G.Donner(moi, "grimoire_double")
hub:Afficher()
attendu("trois tuiles", hub.nombreAffiche, 3)
attendu("la tuile compte les deux sous-grimoires", hub.tuiles[3].compte:GetText():find("· 2") ~= nil, true)
hub.tuiles[3]:Click()
attendu("une bande de sous-grimoires", livre.barre ~= nil, true)
attendu("le premier est affiche", livre.nombreAffiche, 1)
attendu("son sort", livre.cartes[1].nom:GetText(), "Sort A")
livre.barre.boutons[2]:Click()
attendu("on passe au second", livre.sousRang, 2)
attendu("ses deux sorts", livre.nombreAffiche, 2)
attendu("le premier du second", livre.cartes[1].nom:GetText(), "Sort B")

dire("== l'apercu du hub s'arrete a ce qu'on lui demande")
attendu("deux noms par defaut", #G.Apercu(G.Get("grimoire_double")), 2)
attendu("un seul si on en demande un", #G.Apercu(G.Get("grimoire_double"), 1), 1)

dire("== reprendre un grimoire")
hub:Afficher()
hub.tuiles[3].reprendre:Click()
attendu("rendu", G.Has(moi, "grimoire_double"), false)
attendu("deux tuiles a nouveau", hub.nombreAffiche, 2)
G.Retirer(moi, importe.id)
attendu("plus rien de donne", #G.Possedes(moi), 1)
attendu("et la sauvegarde est nettoyee", moi.grimoires, nil)

dire("== l'entree du menu")
attendu("liee", LCM.UI.Menu.EstLiee("grimoires"), true)
hub:Hide()
SlashCmdList.LCM("grimoires")
attendu("la commande ouvre le hub", LCM.UI.Grimoires.frame:IsShown(), true)

dire("== donner son nom a son grimoire")
-- Un grimoire vient du compendium : le renommer LA changerait celui de tout le
-- monde. La personnalisation vit donc sur le personnage, et ne vaut que pour le
-- grimoire personnel (5 octobre 2026).
local G = LCM.Grimoires
local perso = G.Personnel()
attendu("il y a un grimoire personnel", perso ~= nil, true)
local avant = perso.label

attendu("rien de personnalise au depart", G.Personnalisation(moi), nil)
attendu("affiche donc le compendium", G.Affichage(perso, moi).label, avant)

attendu("on le renomme", select(1, G.Personnaliser(moi, {
    label = "Carnet de Reika", description = "Ce qu'elle a compris toute seule." })), true)
attendu("l'affichage suit", G.Affichage(perso, moi).label, "Carnet de Reika")
attendu("et la description aussi",
    G.Affichage(perso, moi).description, "Ce qu'elle a compris toute seule.")
attendu("le compendium n'a pas bouge", perso.label, avant)

-- Un champ vide reprend le defaut, sans effacer le reste.
G.Personnaliser(moi, { description = "Ce qu'elle a compris toute seule." })
attendu("nom vide : le defaut revient", G.Affichage(perso, moi).label, avant)
attendu("la description reste", G.Affichage(perso, moi).description ~= nil, true)

-- Tout vide : plus rien dans la sauvegarde.
G.Personnaliser(moi, {})
attendu("plus de personnalisation", G.Personnalisation(moi), nil)

-- Un grimoire RECU n'est pas concerne.
local recu
for _, g in ipairs(G.list) do if not g.personnel then recu = g break end end
if recu then
    G.Personnaliser(moi, { label = "Pirate" })
    attendu("un grimoire recu garde son nom", G.Affichage(recu, moi).label, recu.label)
    G.Personnaliser(moi, {})
end

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
