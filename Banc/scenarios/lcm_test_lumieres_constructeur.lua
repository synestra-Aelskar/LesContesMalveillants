-- Le constructeur des lanternes et des cristaux (23 octobre 2026), repris du
-- panneau d'edition d'OmegaSurvive.
--
-- Ce que ce scenario tient :
--   * « Nouvelle entree » et « Forger » ouvrent le constructeur, pas le
--     panneau a champs ;
--   * les refus de Survive, avec ses phrases ;
--   * ce qu'il enregistre se relit en regles (Core/Lanternes.lua) ;
--   * une entree rouverte retrouve ses rangees ;
--   * ce qui a ete retire le meme jour, a la demande du MJ : la
--     « Vérification inventaire » (l'inventaire LCM verifie toujours), et
--     « Désactivable » / « Aura ? » sur un cristal (on allume la lanterne, pas
--     son combustible).

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end
local function contient(libelle, texte, morceau)
    local ok = tostring(texte or ""):find(morceau, 1, true) ~= nil
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(texte), ok and "" or ("(attendu « " .. morceau .. " »)"))
end

__declencher("PLAYER_LOGIN")
__personnage()
LCM.db.settings.modeJoueur = nil
LCM._masterCompanion = true

local L, Ls, Cs = LCM.Lanterne, LCM.Lanternes, LCM.Cristaux
local function Trouver(registre, label)
    for _, e in ipairs(registre.list) do if e.label == label then return e end end
end

dire("== le compendium ouvre le constructeur")
local cf = LCM.UI.Compendium.Ouvrir("cristaux")
attendu("Forger visible sur Cristaux", cf.forger:IsShown(), true)
cf.nouvelle:Click()
local f = LCM.LumieresUI.frame
attendu("« Nouvelle entree » l'ouvre", f and f:IsShown(), true)
attendu("titre de creation", f.titre:GetText(), LCM.UI.Majuscules("Nouveau cristal"))
attendu("le panneau a champs reste ferme", LCM.CompendiumEditeur.frame == nil or not LCM.CompendiumEditeur.frame:IsShown(), true)
attendu("valeur : la duree", f.lblValeur:GetText(), "Durée d'activation (minutes)")
attendu("duree par defaut", f.valeur:GetText(), "60")
attendu("plus de verification d'inventaire", f.verif, nil)
-- « Consommable ? » est retire (le MJ, 23 octobre 2026) : changer de cristal
-- en prend toujours un neuf, et un cristal se detruit tout seul a 0 %.
attendu("plus de « Consommable »", f.consommable, nil)
attendu("pas de « Désactivable » sur un cristal", f.desactivable:IsShown(), false)
attendu("ni d'« Aura ? »", f.aura:IsShown(), false)
attendu("ni de volets", f.voletDesactivation:IsShown() or f.voletAura:IsShown(), false)

dire("== un cristal")
f:Valider()
contient("sans nom", f.erreur:GetText(), "nom de l'objet est obligatoire")
f.nom:Saisir("Cristal d'essai")
f.valeur:Saisir("0")
f:Valider()
contient("duree nulle", f.erreur:GetText(), "supérieure à zéro")
f.valeur:Saisir("30")
-- « Max stack » (le MJ, 23 octobre 2026) : combien en tient une poignee.
attendu("« Max stack » sur un cristal", f.pile:IsShown(), true)
f.pile:Saisir("0")
f:Valider()
contient("un max stack nul est refuse", f.erreur:GetText(), "max stack")
f.pile:Saisir("10")
attendu("valider", f:Valider(), true)
local cristal = Trouver(Cs, "Cristal d'essai")
attendu("le cristal existe", cristal ~= nil, true)
attendu("sa duree", cristal and cristal.duree, 30)
attendu("aucune verification d'inventaire", cristal and cristal.verifInventaire, nil)
attendu("son max stack", cristal and cristal.pileMax, 10)
local moi, I = LCM.Entities.Self(), LCM.Inventaire
LCM.Sacs.Add({ id = "temoin_sac", label = "Sac témoin", places = 12, icone = "inv_misc_bag_30" })
I.Poser(moi, "sacs", 1, "temoin_sac", true)
I.Deposer(moi, "cristaux/" .. cristal.id, 12)
local piles = {}
for _, p in ipairs(I.Piles(moi, "cristaux/" .. cristal.id)) do piles[#piles + 1] = p.pile.quantite end
attendu("douze cristaux font une poignee de dix et une de deux", table.concat(piles, ","), "10,2")

dire("== une lanterne")
cf:ChoisirCategorie("lanternes")
attendu("Forger visible sur Lanternes", cf.forger:IsShown(), true)
cf.forger:Click()
attendu("« Forger » l'ouvre", f:IsShown(), true)
attendu("titre de creation", f.titre:GetText(), LCM.UI.Majuscules("Nouvelle lanterne"))
attendu("valeur : le multiplicateur", f.lblValeur:GetText(), "Multiplicateur de temps")
attendu("ni de « Max stack »", f.pile:IsShown(), false)
attendu("« Désactivable » sur une lanterne", f.desactivable:IsShown(), true)
attendu("et « Aura ? »", f.aura:IsShown(), true)
f.nom:Saisir("Lanterne d'essai")

f.desactivable:Click()
attendu("le volet Desactivation s'ouvre", f.voletDesactivation:IsShown(), true)
local vd, va = f.voletDesactivation, f.voletAura
f:Valider()
contient("sans canal", f.erreur:GetText(), "au moins un canal")
vd.canaux[3]:Click()   -- Raid Warning
f:Valider()
contient("sans phrase de desactivation", f.erreur:GetText(), "phrase de désactivation")
vd.pauses[1].texte:Saisir("Le temps s'arrête")
vd.plusPause:Click()
attendu("une seconde phrase", vd.pauses[2].texte:IsShown(), true)
vd.pauses[2].texte:Saisir("Tout s'éteint")
vd.pauses[2].effet = "eteindre"
f:Valider()
contient("sans phrase d'activation", f.erreur:GetText(), "phrase d'activation")
vd.reprises[1].texte:Saisir("Le temps reprend")

f.aura:Click()
attendu("le volet Aura s'ouvre", va:IsShown(), true)
f:Valider()
contient("aura sans regle", f.erreur:GetText(), "condition d'application")
va.poser[1].commande:Saisir("1234")
va.plusPoser:Click()
va.poser[2].condition = "pause"
f:Disposer()
attendu("une regle de phrase montre ses phrases", va.poser[2].phraseListe:IsShown(), true)
attendu("la premiere phrase par defaut", va.poser[2].phrase, "Le temps s'arrête")
va.poser[2].commande:Saisir(".cast 55")
va.retirer[1].commande:Saisir("12:34")
f:Valider()
contient("un deux-points est refuse", f.erreur:GetText(), "« : »")
va.retirer[1].commande:Saisir("1234")

dire("== enregistre, puis relu par le Core")
attendu("valider", f:Valider(), true)
attendu("le constructeur se ferme", f:IsShown(), false)
local lanterne = Trouver(Ls, "Lanterne d'essai")
attendu("la lanterne existe", lanterne ~= nil, true)
attendu("son multiplicateur", lanterne and lanterne.multiplicateur, 1)
local r = L.Regles(lanterne)
attendu("canal lu", r.canaux.RAID_WARNING, true)
attendu("deux phrases de pause", #r.pause, 2)
attendu("la seconde eteint", r.pause[2].eteindre, true)
attendu("une phrase de reprise", #r.reprise, 1)
attendu("deux regles posees", #r.poser, 2)
attendu("la premiere a l'allumage", r.poser[1].condition, "allumer")
attendu("la seconde sur la phrase", r.poser[2].phrase, "Le temps s'arrête")
attendu("une regle retiree, a l'extinction", r.retirer[1] and r.retirer[1].condition, "eteindre")

dire("== rouvert, il retrouve tout")
LCM.LumieresUI.Editer(lanterne, LCM.Compendium.Get("lanternes"))
attendu("titre de modification", f.titre:GetText(), LCM.UI.Majuscules("Modifier la lanterne"))
attendu("le nom", f.nom:GetText(), "Lanterne d'essai")
attendu("Desactivable coche", f.desactivable:EstCochee(), true)
attendu("Aura coche", f.aura:EstCochee(), true)
attendu("Raid Warning coche", vd.canaux[3]:EstCochee(), true)
attendu("Raid pas coche", vd.canaux[1]:EstCochee(), false)
attendu("deux phrases de desactivation", f.nPauses, 2)
attendu("l'effet de la seconde", vd.pauses[2].effet, "eteindre")
attendu("deux regles posees", f.nPoser, 2)
f.aura:Click()
attendu("valider sans aura", f:Valider(), true)
attendu("decocher l'aura vide ses regles", Ls.Get(lanterne.id).aurasPosees, nil)

-- Le MJ, 23 octobre 2026 : consulter une lanterne ou un cristal ne montre
-- que son nom, son icone et sa description — et pour un cristal, son stack
-- max. Ses chiffres de regle seraient des spoils.
dire("== consulter ne spoile rien")
local C = LCM.Compendium
local carteCristal = C.Carte(C.Get("cristaux"), Cs.Get(cristal.id))
attendu("le cristal ne montre que son stack max", carteCristal.meta, "Stack max : 10")
attendu("ni duree ni consommable", carteCristal.entete .. carteCristal.pied, "")
local carteLanterne = C.Carte(C.Get("lanternes"), Ls.Get(lanterne.id))
attendu("la lanterne ne montre aucun chiffre", carteLanterne.meta, "")
local sections = {}
for _, s in ipairs(carteLanterne.corps) do sections[#sections + 1] = s.titre end
attendu("ni ses regles d'aura ni ses phrases", table.concat(sections, ","), "")

dire("== un cristal rouvert ne montre pas de volet")
LCM.LumieresUI.Editer(cristal, LCM.Compendium.Get("cristaux"))
attendu("titre", f.titre:GetText(), LCM.UI.Majuscules("Modifier le cristal"))
attendu("aucun volet", f.voletDesactivation:IsShown() or f.voletAura:IsShown(), false)
attendu("son max stack revient", f.pile:GetText(), "10")
f:Hide()

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
