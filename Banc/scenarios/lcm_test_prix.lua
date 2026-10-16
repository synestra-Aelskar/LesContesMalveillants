-- Plusieurs prix pour un meme article (16 octobre 2026) : « ca te coutera
-- 600 essences. Ou 400 essences et 3 gaufres. » Des facons de payer AU CHOIX,
-- chacune faite de morceaux TOUS dus — devise et devise, devise et ressource,
-- ressource seule : c'est le MJ qui compose. Une devise se paie de la bourse,
-- une ressource ou un objet se prend dans les sacs.
--
-- Contenu TEMOIN : devises, ressources, sac et vendeur d'essai.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

local HERBE, GAUFRE, PAIN = "ressources/herbe_prix", "ressources/gaufre_prix", "ressources/pain_prix"
LCM.Brouillons.Set("ressources", { id = "herbe_prix", label = "Herbe", icone = "inv_misc_herb_01" })
LCM.Brouillons.Set("ressources", { id = "gaufre_prix", label = "Gaufre" })
LCM.Brouillons.Set("ressources", { id = "pain_prix", label = "Pain" })
LCM.Brouillons.Set("sacs", { id = "sac_prix", label = "Sac témoin", places = 12 })
LCM.Brouillons.Set("devises", { id = "essence_prix", label = "Essence" })
LCM.Brouillons.Set("devises", { id = "ecu_prix", label = "Écu" })
LCM.Brouillons.Set("points", {
    id = "etal_prix", label = "Étal des prix", nature = "vendeur", deviseDefaut = "essence_prix",
    onglets = { { id = "o1", label = "Articles", offres = {
        -- OU : deux facons ; la seconde est un ET devise + ressource.
        { id = "herbe", entree = HERBE, quantite = 1, prix = {
            { { ref = "devises/essence_prix", quantite = 600 } },
            { { ref = "devises/essence_prix", quantite = 400 }, { ref = GAUFRE, quantite = 3 } },
        } },
        -- ET : deux devises ; le premier morceau prend la monnaie par defaut.
        { id = "pain", entree = PAIN, quantite = 1, prix = {
            { { quantite = 2 }, { ref = "devises/ecu_prix", quantite = 1 } },
        } },
    } } },
    rachats = { { id = "r1", label = "Rachats", offres = {
        -- Le vendeur paie au choix : en ecus, ou en troc.
        { id = "rachat_herbe", entree = HERBE, prix = {
            { { ref = "devises/ecu_prix", quantite = 2 } },
            { { ref = GAUFRE, quantite = 1 } },
        } },
    } } },
})

__declencher("PLAYER_LOGIN")
__personnage()
local moi = LCM.Entities.Self()
LCM.Inventaire.Poser(moi, "sacs", 1, "sac_prix", true)
local MOI = LCM.PlayerId()
__groupe({ MOI, "Syn-Apertus" })
__declencher("GROUP_ROSTER_UPDATE")
local Prix, M = LCM.Prix, LCM.Marchands

local function Essence() return LCM.Bourse.Solde(moi, "essence_prix") end
local function Ecus() return LCM.Bourse.Solde(moi, "ecu_prix") end
local function Combien(ref) return Prix.Avoir(moi, ref) end

dire("== lire un prix")
local f1 = Prix.Lire(5, "ecus")
attendu("l'ancienne forme : une facon, un morceau", f1[1][1].ref .. " x" .. f1[1][1].quantite, "devises/ecus x5")
local f2 = Prix.Lire(7, nil, "essence")
attendu("  sans devise : la monnaie par defaut", f2[1][1].ref, "devises/essence")
attendu("  zero : gratuit", #Prix.Lire(0, "ecus")[1], 0)
local _, refus = Prix.Lire({ { { ref = "devises/ecus", quantite = "beaucoup" } } })
attendu("une quantite illisible est refusee, et dite", refus ~= nil and refus:find("quantité invalide") ~= nil, true)
local _, sansMonnaie = Prix.Lire({ { { quantite = 3 } } })
attendu("un morceau sans monnaie ni defaut aussi", sansMonnaie ~= nil, true)
local double = Prix.Lire({ { { ref = GAUFRE, quantite = 1 }, { ref = GAUFRE, quantite = 2 } } })
attendu("deux fois la meme chose s'additionne", #double[1] .. ":" .. double[1][1].quantite, "1:3")

dire("== l'icone d'un article : celle choisie au compendium")
-- Le point d'interrogation par defaut avait ete ENREGISTRE dans des vendeurs de
-- la base (16 octobre 2026) : il se lit comme « pas d'icone ».
local etalIcone = LCM.Points.Add({ id = "etal_icone", label = "Étal icône", nature = "vendeur",
    deviseDefaut = "essence_prix", offres = { { id = "a", entree = HERBE, prix = 1,
        icone = "Interface\\Icons\\INV_Misc_QuestionMark" } } })
attendu("l'icone de l'herbe, pas le point d'interrogation", LCM.Points.Icone(etalIcone.offres[1]),
    "Interface\\Icons\\inv_misc_herb_01")

dire("== le registre et le reseau")
local herbe = LCM.Points.Offre("etal_prix", "herbe")
attendu("deux facons de payer", #herbe.formules, 2)
attendu("le texte", Prix.Texte(herbe.formules), "600 Essence  ou  400 Essence + 3 Gaufre")
local pain = LCM.Points.Offre("etal_prix", "pain")
attendu("devise ET devise", Prix.Texte(pain.formules), "2 Essence + 1 Écu")
local plie = Prix.Plier(herbe.formules)
attendu("plie", plie, "600*devises/essence_prix;400*devises/essence_prix,3*ressources/gaufre_prix")
attendu("deplie a l'identique", Prix.Texte(Prix.Deplier(plie)), Prix.Texte(herbe.formules))
attendu("une facon gratuite voyage aussi", Prix.Texte(Prix.Deplier(Prix.Plier({ {} }))), "Gratuit")

dire("== poser l'etal et s'y tenir")
LCM.UI.Menu.Trouver("vendeur").onClick()
local fm = LCM.UI.MarchandsMJ.frame
fm:Choisir("etal_prix")
fm:Onglet("placement")
__position(10, 10, 0)
fm.placement.poser:Click()
__position(12, 11, 0)
__avancer(0.3)
LCM.UI.Marchand.bouton:Click()
local etal = LCM.UI.Marchand.frame
local l1 = LCM.UI.Marchand.lignes[1]
attendu("le prix sous le nom, en entier", l1.prix:GetText(), "600 Essence  ou  400 Essence + 3 Gaufre")

local function ChoisirFacon(rang)
    local popup = LCM.UI.Marchand.choix
    for _, ligne in ipairs(popup.lignes) do
        if ligne:IsShown() and ligne.choix == rang then ligne:Click() return true end
    end
    return false
end

dire("== acheter : le joueur choisit sa facon")
LCM.Bourse.Crediter(moi, "essence_prix", 1000)
LCM.Inventaire.Deposer(moi, GAUFRE, 3)
l1.action:Click()
attendu("on lui demande comment payer", LCM.UI.Marchand.choix:IsShown(), true)
attendu("rien n'est encore achete", Combien(HERBE), 0)
attendu("il prend la seconde facon", ChoisirFacon(2), true)
attendu("l'herbe est dans le sac", Combien(HERBE), 1)
attendu("400 essences prelevees", Essence(), 600)
attendu("et les 3 gaufres", Combien(GAUFRE), 0)
l1.action:Click()
ChoisirFacon(2)
attendu("plus de gaufres : refuse", Combien(HERBE), 1)
attendu("  rien preleve", Essence(), 600)
l1.action:Click()
ChoisirFacon(1)
attendu("la premiere facon passe", Combien(HERBE), 2)
attendu("600 essences", Essence(), 0)
local ok, raison = M.Acheter("etal_prix", "herbe", 1)
attendu("sans le sou : refuse", ok, false)
attendu("  et dit ce qui manque", raison, "il te faut 600 Essence.")
ok, raison = M.Acheter("etal_prix", "herbe")
attendu("plusieurs facons sans choix : on demande", raison, "choisis comment payer.")

dire("== devise ET devise : tout est du")
local l2 = LCM.UI.Marchand.lignes[2]
LCM.Bourse.Crediter(moi, "essence_prix", 2)
l2.action:Click()
attendu("il manque l'ecu : refuse", Combien(PAIN), 0)
attendu("  rien preleve", Essence(), 2)
LCM.Bourse.Crediter(moi, "ecu_prix", 1)
l2.action:Click()
attendu("une seule facon : pas de question", Combien(PAIN), 1)
attendu("les deux devises prelevees", Essence() .. "/" .. Ecus(), "0/0")

dire("== revendre : le vendeur paie au choix, meme en troc")
etal.revendre:Click()
LCM.UI.Marchand.lignes[1].action:Click()
ChoisirFacon(2)
attendu("l'herbe part", Combien(HERBE), 1)
attendu("payee d'une gaufre", Combien(GAUFRE), 1)
LCM.UI.Marchand.lignes[1].action:Click()
ChoisirFacon(1)
attendu("puis en ecus", Ecus(), 2)
attendu("  plus d'herbe", Combien(HERBE), 0)

dire("== le reglage d'article du MJ")
local ed = LCM.UI.Points.Editeur("vendeur")
ed:Ouvrir(LCM.Points.Get("etal_prix"))
local reglage = ed.reglageOffre
reglage:Ouvrir(ed.travail.onglets[1].offres[1], ed)
-- Un tableau par facon, une ligne par morceau.
local function Compter()
    local facons, morceaux = 0, 0
    for _, t in ipairs(reglage.tableaux) do
        if t:IsShown() then
            facons = facons + 1
            for _, l in ipairs(t.lignes) do if l:IsShown() then morceaux = morceaux + 1 end end
        end
    end
    return facons, morceaux
end
local facons, morceaux = Compter()
attendu("deux tableaux a l'ecran", facons, 2)
attendu("trois lignes de morceaux", morceaux, 3)
attendu("  le second dit « ou »", reglage.tableaux[2].nom:GetText(), "ou, façon 2")
attendu("  chacun a ses colonnes", reglage.tableaux[1].payeEn:GetText(), "Payé en")
reglage.ajouterFacon:Click()
facons = Compter()
attendu("+ un tableau", facons, 3)
reglage.tableaux[3].ajouter:Click()
reglage.tableaux[3].lignes[1].quantite:Saisir("12")
reglage.tableaux[3].lignes[2].quantite:Saisir("2")
attendu("enregistre", ed:Sauver(false), true)
local apres = LCM.Points.Offre("etal_prix", "herbe")
attendu("trois facons dans le registre", #apres.formules, 3)
attendu("la troisieme en monnaie par defaut", Prix.TexteFacon(apres.formules[3]), "14 Essence")
-- (12 + 2 dans la meme monnaie par defaut : les morceaux identiques s'additionnent.)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
