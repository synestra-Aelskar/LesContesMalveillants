-- Vendeurs et points de recolte : offres, stock, prise, fenetre.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end
local function dernierMessage() return __sansCouleur(__sorties[#__sorties] or "") end

__declencher("PLAYER_LOGIN")
local P = LCM.Points
local moi = LCM.Entities.Self()
__temps(50000)

dire("== aucun point livre pour l'instant")
attendu("le registre est vide", #P.list, 0)

dire("== declarer un point de recolte")
local filon = P.Add({
    id = "filon_cuivre", label = "Filon de cuivre", nature = "ressource",
    description = "Une veine affleurante.",
    offres = {
        { id = "minerai", entree = "objets/dague_d_assassin_du_culte", label = "Minerai de cuivre", quantite = 2,
          stock = { limite = 3, unites = 1, minutes = 10 } },
        { id = "poussiere", entree = "objets/dague_d_assassin_du_culte", label = "Poussière de cuivre" },
    },
})
attendu("ajoute", filon.nature, "ressource")
attendu("deux offres", #filon.offres, 2)
attendu("la cle du stock porte le point et l'offre", filon.offres[1].cle, "filon_cuivre/minerai")
attendu("une offre sans stock n'a pas de limite", filon.offres[2].stock.limite, 0)

dire("== un vendeur sans prix est refuse")
local ok = pcall(P.Add, { id = "casse", label = "Casse", nature = "vendeur",
    offres = { { id = "a", label = "Objet" } } })
attendu("refus", ok, false)
attendu("une nature inconnue aussi",
    (pcall(P.Add, { id = "casse2", label = "x", nature = "banque" })), false)

local marchand = P.Add({
    id = "herboriste", label = "Herboriste", nature = "vendeur",
    offres = { { id = "herbe", label = "Herbe de lune", prix = 5, devise = "ecus",
                 stock = { limite = 2, unites = 0, minutes = 0 } } },
})
attendu("le vendeur passe", marchand.offres[1].prix, 5)
attendu("par nature", #P.Nature("vendeur"), 1)
attendu("et l'autre aussi", #P.Nature("ressource"), 1)

-- Les regles de stock sont posees a la connexion ; ici on les pose a la main.
LCM.Stock.Declarer("filon_cuivre/minerai", filon.offres[1].stock)
LCM.Stock.Declarer("herboriste/herbe", marchand.offres[1].stock)

dire("== recolter")
-- Il faut un sac pour recevoir : sans place, la recolte doit refuser.
local sansPlace, raison = P.Prendre(moi, "filon_cuivre", "minerai")
attendu("sans place : refus", sansPlace, false)
attendu("et on dit pourquoi", raison, "aucune place libre.")
attendu("le stock n'a pas ete entame", LCM.Stock.Restant("filon_cuivre/minerai"), 3)

dire("== avec un sac")
local categorie = LCM.Inventaire.categories[1]
-- Le plus grand sac du compendium : ce test recolte une dizaine de fois, il
-- lui faut de la place. Prendre `list[1]` le rendait dependant de l'ordre du
-- catalogue — et la sacoche de depart, cinq places, s'y est glissee en tete.
local sac
for _, s in ipairs(LCM.Sacs.list) do
    if not sac or (s.places or 0) > (sac.places or 0) then sac = s end
end
attendu("un onglet d'inventaire existe", categorie ~= nil, true)
attendu("un sac au compendium", sac ~= nil, true)
attendu("sac pose", (LCM.Inventaire.Poser(moi, categorie.id, 1, sac.id)), true)
local pris, offre = P.Prendre(moi, "filon_cuivre", "minerai")
attendu("recolte", pris, true)
attendu("le stock baisse", LCM.Stock.Restant("filon_cuivre/minerai"), 2)
local emplacement = LCM.Inventaire.Emplacement(moi, categorie.id, 1)
local case1 = LCM.Inventaire.Case(emplacement, 1)
attendu("l'objet est range", case1 ~= nil, true)
attendu("avec sa quantite", case1 and case1.quantite, 2)

dire("== le filon s'epuise, puis repousse")
P.Prendre(moi, "filon_cuivre", "minerai")
P.Prendre(moi, "filon_cuivre", "minerai")
attendu("vide", LCM.Stock.Restant("filon_cuivre/minerai"), 0)
local vide, pourquoi = P.Prendre(moi, "filon_cuivre", "minerai")
attendu("on ne prend pas sur un filon vide", vide, false)
attendu("et on le dit", pourquoi, "il n'y en a plus.")
__avancerTemps(10 * 60)
attendu("dix minutes plus tard : une unite", LCM.Stock.Restant("filon_cuivre/minerai"), 1)

dire("== une offre sans stock ne s'epuise pas")
for _ = 1, 5 do P.Prendre(moi, "filon_cuivre", "poussiere") end
attendu("toujours disponible", (P.Prendre(moi, "filon_cuivre", "poussiere")), true)

dire("== acheter preleve dans la bourse")
-- Le vendeur demande 5 ecus ; le personnage n'en a pas encore.
local sansSou, pourquoiPas = P.Prendre(moi, "herboriste", "herbe")
attendu("sans argent : refus", sansSou, false)
attendu("et on dit le prix", pourquoiPas:find("5") ~= nil, true)
attendu("le stock n'a pas ete entame", LCM.Stock.Restant("herboriste/herbe"), 2)

LCM.Bourse.Crediter(moi, "ecus", 12)
local achat = P.Prendre(moi, "herboriste", "herbe")
attendu("avec de quoi payer : achete", achat, true)
attendu("preleve", LCM.Bourse.Solde(moi, "ecus"), 7)
attendu("et le stock baisse", LCM.Stock.Restant("herboriste/herbe"), 1)
P.Prendre(moi, "herboriste", "herbe")
attendu("un second achat", LCM.Bourse.Solde(moi, "ecus"), 2)
local trop = P.Prendre(moi, "herboriste", "herbe")
attendu("plus de stock : refus", trop, false)
attendu("et rien n'a ete preleve", LCM.Bourse.Solde(moi, "ecus"), 2)
LCM.Stock.Rendre("herboriste/herbe", 2, true)

dire("== recolter ne coute rien")
local avantSolde = LCM.Bourse.Solde(moi, "ecus")
P.Prendre(moi, "filon_cuivre", "poussiere")
attendu("la bourse n'a pas bouge", LCM.Bourse.Solde(moi, "ecus"), avantSolde)

dire("== la fenetre des ressources")
local f = LCM.UI.Points.Basculer("ressource")
attendu("ouverte", f:IsShown(), true)
attendu("le point est choisi", f.pointId, "filon_cuivre")
attendu("ses deux offres", f.nombreAffiche, 2)
attendu("le stock s'affiche", f.offres[1].stock:GetText(), "1 / 3")
attendu("le bouton dit Récolter", f.offres[1].prendre.label:GetText(), "Récolter")
f.offres[1].prendre:Click()
attendu("la recolte passe par la fenetre", LCM.Stock.Restant("filon_cuivre/minerai"), 0)
attendu("et le bouton s'eteint", f.offres[1].prendre:IsEnabled(), false)

dire("== la fenetre du vendeur")
local v = LCM.UI.Points.Basculer("vendeur")
attendu("ouverte", v:IsShown(), true)
attendu("le bouton dit Acheter", v.offres[1].prendre.label:GetText(), "Acheter")
attendu("le prix est affiche avec le nom de la devise",
    __sansCouleur(v.offres[1].nom:GetText()):find("5 Écus") ~= nil, true)

dire("== un stock qui bouge ailleurs se voit ici")
LCM.Reseau.Recevoir("Autre-Royaume", "88:1:1:stock|cle=herboriste/herbe;r=0;t=50000;u=99999")
attendu("le stock recu", LCM.Stock.Restant("herboriste/herbe"), 0)
attendu("la fenetre a suivi", v.offres[1].stock:GetText(), "0 / 2")

dire("== les entrees du menu")
attendu("vendeur", LCM.UI.Menu.EstLiee("vendeur"), true)
attendu("ressources", LCM.UI.Menu.EstLiee("ressources"), true)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
