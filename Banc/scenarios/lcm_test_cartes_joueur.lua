-- banc: --sans-mj
-- Une carte trouvee par un joueur, sans l'addon MJ (31 octobre 2026).
--
-- La famille des cartes est reservee au MJ : le joueur n'en a aucune dans ses
-- fichiers. Il en recoit une en la TROUVANT — ici en fouillant un filon —
-- et sa definition voyage avec. Il n'a pas non plus les regions de
-- Crossings (le MJ n'est pas la pour les lui envoyer) : la carte doit quand
-- meme se lire, avec les noms qu'elle porte.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()
attendu("sans compagnon MJ", LCM.IsMaster(), false)
attendu("aucune carte dans les fichiers du joueur", #LCM.Cartes.list, 0)

local definition = {
    id = "carte_temoin", label = "Carte volée", region = "z_temoin", regionNom = "Forêt Automnale",
    lieux = { { id = "pl_bois", nom = "Bois des Sorcières" } },
    reperes = { { genre = "ressource", label = "Champignons", x = 5, y = 5 } },
}
local paquet = { i = "point_carte", n = "Filon témoin", p = "", u = {
    { entree = "cartes/carte_temoin", min = 1, max = 1, definition = definition } } }
LCM.Recolte.Lire(LCM.Reseau.Decoder(LCM.Reseau.Encoder(paquet)))
attendu("la carte trouvee est importee", LCM.Cartes.Get("carte_temoin") ~= nil, true)
attendu("et gardee apres /reload", LCM.db.cartesRecues.carte_temoin ~= nil, true)

dire("== elle se lit sans les regions de Crossings")
attendu("la lecture reussit", LCM.UI.Cartes.Ouvrir("cartes/carte_temoin"), true)
local win = LCMCrossingsRegionMap
attendu("la carte s'ouvre", win:IsShown(), true)
local sous = win.fenetre.sousTitre:GetText() or ""
attendu("avec le nom de la region qu'elle porte", sous:find("Forêt Automnale", 1, true) ~= nil, true)
attendu("et ses lieux", sous:find("Bois des Sorcières", 1, true) ~= nil, true)
attendu("les noms sont appris pour plus tard", LCM.Crossings:HasLearnedSubZoneName("pl_bois"), true)

dire("== une carte arrachee a un panneau d'affichage")
-- Le panneau apporte la definition de sa carte : le joueur, qui n'a aucune
-- carte dans ses fichiers, l'importe en l'arrachant.
local carteMurale = { id = "carte_murale", label = "Carte murale", regions = { { id = "z_mur", nom = "Murailles" } } }
local paquetPanneau = { i = "panneau_temoin", n = "Panneau témoin", s = "provisoire",
    a = { { t = "Plan des murailles", x = "", c = carteMurale } }, p = "" }
local panneau = LCM.Affichages.Lire(LCM.Reseau.Decoder(LCM.Reseau.Encoder(paquetPanneau)))
attendu("le panneau arrive avec sa carte", panneau and panneau.affiches[1].carte, "carte_murale")
attendu("la carte n'est pas encore connue", LCM.Cartes.Get("carte_murale"), nil)
local ok = LCM.Affichages.Arracher("point_temoin", panneau, 1)
attendu("arracher reussit", ok, true)
attendu("la carte est importee", LCM.Cartes.Get("carte_murale") ~= nil, true)
attendu("et rangee dans l'inventaire", LCM.Inventaire.Chercher(LCM.Entities.Self(), "cartes/carte_murale") ~= nil, true)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
