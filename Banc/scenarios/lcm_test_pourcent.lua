-- Un etat peut monter ou baisser une statistique en POURCENTAGE
-- (le MJ, 24 octobre 2026 : « baisse force de 40 % »).
--
-- La case « % » de la forge ne change pas le montant : elle change sa LECTURE.
-- Trois regles tiennent la mecanique, et ce scenario les tient toutes :
--
--   1. les points d'abord, le pourcentage ensuite, sur l'ensemble ;
--   2. les pourcentages s'ADDITIONNENT (deux fois -40 % font -80 %) ;
--   3. une statistique ne descend pas sous zero.
--
-- Au passage, le reenregistrement d'une entree : la forge repart de l'element
-- CONSTRUIT, dont les avantages sont des ensembles et non des listes. Relus a
-- l'`ipairs`, ils revenaient vides — un avantage disparaissait a chaque
-- passage par la forge, sans un mot.
--
-- Contenu TEMOIN : jeu, etats et trait d'essai, jamais ceux de la campagne.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

LCM.Brouillons.Set("etats", { id = "faiblesse_temoin", label = "Faiblesse témoin",
    categorie = "etat", bonus = { force = -40 }, pourcent = { "force" } })
LCM.Brouillons.Set("etats", { id = "vigueur_temoin", label = "Vigueur témoin",
    categorie = "etat", bonus = { force = 25 }, pourcent = { "force" } })
LCM.Brouillons.Set("etats", { id = "charge_temoin", label = "Charge témoin",
    categorie = "etat", bonus = { force = 2 } })
LCM.Brouillons.Set("etats", { id = "myopie_temoin", label = "Myopie témoin",
    categorie = "etat", bonus = { vue = -50 }, pourcent = { "vue" } })

__declencher("PLAYER_LOGIN")
__personnage()
local moi = LCM.Entities.Self()
local E, F, T = LCM.Effets, LCM.Formules, LCM.EtatsTemporaires

-- Aucun « tout retirer » dans l'API : on retire ce qu'on a pose, par son nom.
local function ViderEtats()
    local liste = T.Liste(moi)
    for i = #liste, 1, -1 do T.RetirerForce(moi, liste[i].nom) end
end

dire("== ce qu'une definition declare arrive jusqu'a l'element")
local faiblesse = LCM.Etats.Get("faiblesse_temoin")
attendu("l'état témoin existe", faiblesse ~= nil and faiblesse.label, "Faiblesse témoin")
attendu("  son montant reste dans bonus", faiblesse.bonus.force, -40)
attendu("  et le champ est marqué", (faiblesse.pourcent or {}).force, true)
attendu("  un état sans pourcentage n'en porte aucun",
    next(LCM.Etats.Get("charge_temoin").pourcent or {}), nil)

dire("== un pourcentage n'est pas des points")
LCM.Entities.Set_Value(moi, "force", 10)
T.Poser(moi, { nom = "Faiblesse témoin", bonus = faiblesse.bonus,
    pourcent = faiblesse.pourcent, id = "faiblesse_temoin" })
attendu("aucun point retiré", E.Bonus(moi, "force"), 0)
attendu("mais -40 % portés", E.Pourcent(moi, "force"), -40)
attendu("la Force tombe de 10 à 6", F.Primaire(moi, "force"), 6)
attendu("  et le détail le dit en pourcentage",
    E.Detail(moi, "force")[1].elements[1].pourcent, true)
attendu("  sans le compter comme des points", E.Detail(moi, "force")[1].total, 0)
attendu("  « Force -40 % » se lit pareil partout",
    LCM.UI.Fiche.Effets(faiblesse), "Force -40 %")

dire("== les points d'abord, le pourcentage ensuite, sur l'ensemble")
T.Poser(moi, { nom = "Charge témoin", bonus = { force = 2 }, id = "charge_temoin" })
attendu("les points portés", E.Bonus(moi, "force"), 2)
-- (10 + 2) x 0,6 = 7,2, arrondi a l'inferieur comme les apports.
attendu("(10 + 2) puis -40 % = 7", F.Primaire(moi, "force"), 7)
T.Retirer(moi, "Charge témoin")

dire("== deux pourcentages s'ADDITIONNENT, ils ne se composent pas")
T.Poser(moi, { nom = "Faiblesse témoin bis", bonus = faiblesse.bonus,
    pourcent = faiblesse.pourcent, id = "faiblesse_temoin" })
attendu("-40 % et -40 % font -80 %", E.Pourcent(moi, "force"), -80)
attendu("  10 moins 80 % = 2 (et non 3,6)", F.Primaire(moi, "force"), 2)

dire("== un bonus en pourcentage monte aussi")
local vigueur = LCM.Etats.Get("vigueur_temoin")
T.Poser(moi, { nom = "Vigueur témoin", bonus = vigueur.bonus,
    pourcent = vigueur.pourcent, id = "vigueur_temoin" })
attendu("-80 % et +25 % font -55 %", E.Pourcent(moi, "force"), -55)
attendu("  10 moins 55 % = 4", F.Primaire(moi, "force"), 4)
T.Retirer(moi, "Vigueur témoin")

dire("== une statistique ne descend pas sous zero")
T.Poser(moi, { nom = "Faiblesse témoin ter", bonus = faiblesse.bonus,
    pourcent = faiblesse.pourcent, id = "faiblesse_temoin" })
attendu("trois fois -40 % font -120 %", E.Pourcent(moi, "force"), -120)
attendu("  la Force est vidée, pas inversée", F.Primaire(moi, "force"), 0)
ViderEtats()
attendu("plus rien n'est porté", E.Pourcent(moi, "force"), 0)
attendu("  la Force est revenue", F.Primaire(moi, "force"), 10)

dire("== un etat PORTE (et non pose) module de la meme facon")
-- Deux chemins arrivent chez Effets : la liste des etats temporaires, et les
-- etats que l'entite porte par son catalogue. Le second lit l'element du
-- registre, donc son pourcentage.
local place, pourquoi = LCM.Etats.Placer(moi, "faiblesse_temoin")
attendu("l'état est porté " .. tostring(pourquoi), place, true)
attendu("  -40 % portés", E.Pourcent(moi, "force"), -40)
attendu("  la Force tombe à 6", F.Primaire(moi, "force"), 6)
LCM.Etats.Enlever(moi, "faiblesse_temoin")
attendu("retiré, la Force revient", F.Primaire(moi, "force"), 10)

dire("== une expertise se module aussi, apport compris")
LCM.Entities.Set_Value(moi, "vue", 4)
local avant = F.Expertise(moi, "vue")
T.Poser(moi, { nom = "Myopie témoin", bonus = { vue = -50 },
    pourcent = LCM.Etats.Get("myopie_temoin").pourcent, id = "myopie_temoin" })
attendu("l'expertise perd la moitié", F.Expertise(moi, "vue"), math.floor(avant * 50 / 100))
attendu("  et pas un point de plus", E.Bonus(moi, "vue"), 0)
ViderEtats()

dire("== un pourcentage sans montant est refuse, pas ignore")
local ok, raison = pcall(function()
    LCM.Etats.Construire({ id = "vide_temoin", label = "Vide", categorie = "etat",
        pourcent = { "force" } })
end)
attendu("la construction échoue", ok, false)
attendu("  et elle dit pourquoi",
    tostring(raison):find("pourcentage sans montant") ~= nil, true)

dire("== la forge : une case par ligne, pour les etats seulement")
LCM.Forge.Add({ id = "jeu_pourcent_temoin", label = "Jeu pourcent témoin", categorie = "etats",
    raretes = { { id = "commun", label = "Commun", points = 200, couleur = "FF8CB8" } },
    champs = {} })
local FU = LCM.UI.Forge
FU.Ouvrir("etats")
local f = FU.Fenetre()
FU.courant.jeuId, FU.courant.rareteId = "jeu_pourcent_temoin", "commun"
FU.courant.nom = "Forge témoin"
f.vue = "tableau"   -- tous les dossiers ouverts : la ligne cherchee est posee
f:Rafraichir()
local ligne
for _, l in ipairs(f.lignes) do if l.cle == "force" and l:IsShown() then ligne = l end end
attendu("la ligne Force est à l'écran", ligne ~= nil, true)
attendu("  elle porte une case %", ligne ~= nil and ligne.pourcent:IsShown(), true)
attendu("  décochée au départ", ligne ~= nil and ligne.pourcent:EstCochee(), false)
attendu("  et le chiffre est nu", ligne ~= nil and ligne.unite:GetText(), "")
f:Fixer("force", "-40")
ligne.pourcent:Click()
attendu("un clic la coche", FU.courant.pourcent.force, true)
-- Le retour visuel (le MJ, 24 octobre 2026) : la case cochee doit se voir
-- depuis le chiffre, sinon « -40 » et « -40 % » s'ecrivent pareil a l'ecran.
attendu("  le chiffre porte le signe", ligne.unite:GetText(), "%")
attendu("  et le survol de la case s'explique",
    type(ligne.pourcent.explication) == "string"
    and ligne.pourcent.explication:find("POURCENTAGE") ~= nil, true)
local definition, pourquoi = FU.Definition()
attendu("la forge produit une définition " .. tostring(pourquoi), definition ~= nil, true)
attendu("  avec le montant dans bonus", definition and definition.bonus.force, -40)
attendu("  et le champ en pourcentage", definition and definition.pourcent
    and definition.pourcent[1], "force")
attendu("  une LISTE, comme une définition s'écrit",
    definition and definition.pourcent and #definition.pourcent, 1)
ligne.pourcent:Click()
attendu("un second clic la décoche", FU.courant.pourcent.force, nil)
attendu("  et la définition n'en parle plus", select(1, FU.Definition()).pourcent, nil)
attendu("  le signe quitte le chiffre", ligne.unite:GetText(), "")

dire("== une case cochee sur une ligne a zero ne veut rien dire")
ligne.pourcent:Click()
f:Fixer("force", "0")
attendu("rien n'est écrit", select(1, FU.Definition()).pourcent, nil)
f:Fixer("force", "-40")

dire("== les autres categories n'offrent pas la case")
LCM.Forge.Add({ id = "jeu_traits_temoin", label = "Jeu traits témoin", categorie = "traits",
    raretes = { { id = "commun", label = "Commun", points = 20, couleur = "FF8CB8" } },
    champs = {} })
FU.Ouvrir("traits")
FU.courant.jeuId, FU.courant.rareteId = "jeu_traits_temoin", "commun"
f.vue = "tableau"
f:Rafraichir()
local ligneTrait
for _, l in ipairs(f.lignes) do if l:IsShown() and not ligneTrait then ligneTrait = l end end
attendu("une ligne de trait est à l'écran", ligneTrait ~= nil, true)
attendu("  sans case %", ligneTrait ~= nil and ligneTrait.pourcent:IsShown(), false)
attendu("  ni signe dans le champ",
    ligneTrait ~= nil and ligneTrait.unite:IsShown(), false)

dire("== reenregistrer une entree ne lui fait rien perdre")
-- Elle repart de l'element construit : avantage et desavantage y sont des
-- ensembles. Relus en liste, ils revenaient vides.
-- Avec son jeu : sans `forge`, la modification repart a zero (JeuCourant vide
-- les valeurs quand il doit choisir un jeu lui-meme), et ce n'est pas ce qu'on
-- teste ici.
LCM.Etats.Add({ id = "garde_temoin", label = "Garde témoin",
    categorie = "etat", forge = "jeu_pourcent_temoin/commun",
    bonus = { force = -40, vue = 1 },
    pourcent = { "force" }, avantage = { "vue" }, desavantage = { "escalade" } })
local garde = LCM.Etats.Get("garde_temoin")
attendu("l'entrée porte son avantage", (garde.avantage or {}).vue, true)
attendu("  son désavantage", (garde.desavantage or {}).escalade, true)
attendu("  et son pourcentage", (garde.pourcent or {}).force, true)
FU.OuvrirEdition(LCM.Compendium.Get("etats"), garde)
local reenregistree = select(1, FU.Definition())
attendu("la case % est reprise", FU.courant.pourcent.force, true)
f.vue = "tableau"
f:Rafraichir()
local reprise
for _, l in ipairs(f.lignes) do if l.cle == "force" and l:IsShown() then reprise = l end end
attendu("  cochée à l'écran", reprise ~= nil and reprise.pourcent:EstCochee(), true)
attendu("  et le chiffre repris porte le signe",
    reprise ~= nil and reprise.unite:GetText(), "%")
attendu("l'avantage survit", reenregistree and reenregistree.avantage
    and reenregistree.avantage[1], "vue")
attendu("  le désavantage aussi", reenregistree and reenregistree.desavantage
    and reenregistree.desavantage[1], "escalade")
attendu("  et le pourcentage", reenregistree and reenregistree.pourcent
    and reenregistree.pourcent[1], "force")
local relu = LCM.Etats.Construire(reenregistree)
attendu("relue, elle garde son avantage", (relu.avantage or {}).vue, true)
attendu("  son désavantage", (relu.desavantage or {}).escalade, true)
attendu("  et son pourcentage", (relu.pourcent or {}).force, true)

dire("== la carte du compendium lit le bon champ")
-- Deux champs partagent le type « avantage » depuis le desavantage : la carte
-- montrait l'avantage dans les deux lignes.
local categorie = LCM.Compendium.Get("etats")
local vus = {}
for _, champ in ipairs(LCM.Compendium.Champs(categorie)) do
    if champ.type == "avantage" then
        vus[champ.cle] = table.concat(LCM.Compendium.Brut(categorie, champ, garde), ",")
    end
end
attendu("ligne Avantage", vus.avantage, "vue")
attendu("ligne Désavantage", vus.desavantage, "escalade")

dire("== la case des jets : vide, vert, rouge")
-- Une seule case a trois etats par ligne (le MJ, 24 octobre 2026), et
-- seulement sur un JET : un avantage sur une primaire ne serait demande par
-- personne.
FU.Ouvrir("etats")
FU.courant.jeuId, FU.courant.rareteId = "jeu_pourcent_temoin", "commun"
FU.courant.nom = "Jets témoin"
f.vue = "tableau"
f:Rafraichir()
local ligneJet, lignePrimaire
for _, l in ipairs(f.lignes) do
    if l:IsShown() then
        if l.cle == "vue" then ligneJet = l end
        if l.cle == "force" then lignePrimaire = l end
    end
end
attendu("la ligne Vue porte la case", ligneJet ~= nil and ligneJet.jet:IsShown(), true)
attendu("  Force n'est pas un jet", lignePrimaire ~= nil and lignePrimaire.jet:IsShown(), false)
attendu("  vide au départ", ligneJet.jet:EstCochee(), false)
-- Le vert pour ce qui aide, le rouge pour ce qui nuit (le MJ, 24 octobre
-- 2026), comme les chiffres de la ligne. Le banc ne lit pas la couleur d'une
-- texture : c'est le SURVOL qu'on tient ici, puisque c'est lui qui induirait
-- en erreur s'il annoncait l'inverse de ce que la case montre.
ligneJet.jet:Click()
attendu("un clic : avantage", FU.courant.avantage.vue, true)
attendu("  la case est allumée", ligneJet.jet:EstCochee(), true)
attendu("  le survol donne le vert à l'avantage",
    ligneJet.jet.explication:find("Vert : AVANTAGE", 1, true) ~= nil, true)
attendu("  et le rouge au désavantage",
    ligneJet.jet.explication:find("Rouge : DÉSAVANTAGE", 1, true) ~= nil, true)
attendu("  et la définition le dit", select(1, FU.Definition()).avantage[1], "vue")
ligneJet.jet:Click()
attendu("deux clics : désavantage", FU.courant.desavantage.vue, true)
attendu("  l'avantage est tombé", FU.courant.avantage.vue, nil)
attendu("  la définition suit", select(1, FU.Definition()).desavantage[1], "vue")
attendu("  et ne garde pas l'avantage", select(1, FU.Definition()).avantage, nil)
ligneJet.jet:Click()
attendu("trois clics : la case est vide", ligneJet.jet:EstCochee(), false)
attendu("  ni avantage", FU.courant.avantage.vue, nil)
attendu("  ni désavantage", FU.courant.desavantage.vue, nil)
attendu("  et la définition n'en parle plus", select(1, FU.Definition()).desavantage, nil)

print(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
