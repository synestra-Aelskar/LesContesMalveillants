-- Le DOT : un etat qui grignote une jauge a chaque round (9 octobre 2026).
--
-- Il se compose comme un debuff, avec un pool de points. Trois jauges se
-- grignotent toutes seules ; les PV et l'etat d'armure sont zones, donc le dot
-- n'y touche pas et pose une NOTE que la cible applique elle-meme.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()

local moi = LCM.Entities.Self()

-- Vider les etats SANS iterer sur la liste qu'on modifie : ipairs saute un
-- element sur deux quand on retire en chemin, et un vieux dot survivant mord
-- encore au round suivant.
local function ViderLesEtats()
    local liste = LCM.EtatsTemporaires.Liste(moi)
    while #liste > 0 do
        local e = liste[#liste]
        LCM.EtatsTemporaires.Retirer(moi, e.id or e.nom, true)
        liste = LCM.EtatsTemporaires.Liste(moi)
    end
end
local D, T = LCM.Dot, LCM.EtatsTemporaires
local E = LCM.Equilibrage

dire("== la mecanique existe")
local mecanique
for _, m in ipairs(E.mecaniques) do if m.id == "dot" then mecanique = m end end
attendu("« Dot » est une mecanique de competence", mecanique and mecanique.label, "Dot")
attendu("et elle a son champ de fiche", LCM.Schema.Field("meca_dot") ~= nil, true)

dire("== le bareme")
local prix = {}
for _, c in ipairs(D.Cibles()) do prix[c.id] = c.cout end
attendu("bouclier", prix.bouclier, 2)
attendu("PF", prix.pf, 3)
attendu("PV", prix.pv, 4)
attendu("état d'armure", prix.armure, 4)
attendu("PA", prix.pa, 15)
attendu("un round de plus", E.dot.coutRound, 4)
attendu("un stack de plus", E.dot.coutStack, 10)
-- Les PA se comptent en unites : un pourcentage n'y voudrait rien dire.
attendu("les PA grignotent a plat", D.Cible("pa").plat, 1)
attendu("et pas en pourcentage", D.Cible("pa").taux, nil)

dire("== ce que coute une composition")
-- Deux points de PV (8), deux rounds de plus (8), deux stacks de plus (20).
local choix = { pv = 2, rounds = 2, stacks = 2 }
attendu("total", (D.Cout(choix)), 36)
local compose = D.Composer(choix)
attendu("durée : la base plus deux", compose.rounds, E.dot.roundsBase + 2)
attendu("stacks : la base plus deux", compose.stacks, E.dot.stacksBase + 2)
attendu("une seule morsure", #compose.morsures, 1)
attendu("de 10 % par stack", compose.morsures[1].taux, 0.1)

dire("== une jauge unique se grignote toute seule")
-- La fatigue : on la remplit, on pose un dot d'un point, un stack.
local fatigue = LCM.Entities.Gauge(moi, "fatigue")
attendu("la fatigue a un maximum", fatigue and fatigue.max > 0, true)
LCM.Entities.SetGauge(moi, "fatigue", fatigue.max)
-- Trois rounds de duree : on veut voir DEUX morsures, et un dot de base ne
-- dure qu'un round.
local pose = D.Poser(moi, { nom = "Brûlure", choix = { pf = 1, rounds = 2 }, jet = 14, lanceur = "Syn" })
attendu("le dot est posé", pose ~= nil, true)
attendu("il est marqué débuff", pose.debuff, true)
attendu("il porte ses stacks", pose.dot.stacks, E.dot.stacksBase)

local attenduRetire = math.ceil(fatigue.max * 0.05)
T.Round(moi)
local apres = LCM.Entities.Gauge(moi, "fatigue")
attendu("la fatigue a été grignotée", fatigue.max - apres.current, attenduRetire)
-- 5 % du MAXIMUM, pas du courant : le grignotage ne faiblit pas.
T.Round(moi)
local encore = LCM.Entities.Gauge(moi, "fatigue")
attendu("et du même montant au round suivant", apres.current - encore.current, attenduRetire)

dire("== les PA se grignotent a plat")
local pa = LCM.Entities.Gauge(moi, "pa")
LCM.Entities.SetGauge(moi, "pa", pa.max)
D.Poser(moi, { nom = "Engourdissement", choix = { pa = 1 }, jet = 10 })
T.Round(moi)
attendu("un PA en moins", pa.max - LCM.Entities.Gauge(moi, "pa").current, 1)

dire("== une jauge ZONEE ne se touche pas : elle pose une note")
local avantPV = LCM.Entities.Get_Value(moi, "pv_max")
local faits
D.Poser(moi, { nom = "Hémorragie", choix = { pv = 2, stacks = 1 }, jet = 12 })
faits = D.Tic(moi)
local note
for _, f in ipairs(faits) do if f.cible == "pv" then note = f end end
attendu("une note est produite", note ~= nil, true)
attendu("elle est marquée zonée", note and note.zonee, true)
-- Deux points a 5 %, deux stacks : 20 % a repartir.
attendu("elle annonce le pourcentage", note and math.floor(note.pourcent + 0.5), 20)
attendu("et elle se lit", note and note.note:find("répartir") ~= nil, true)
attendu("les PV max n'ont pas bougé", LCM.Entities.Get_Value(moi, "pv_max"), avantPV)

dire("== dissiper : l'exemple du jour")
-- Joueur A pose trois stacks de dot PV, rand 14.
-- Trois rounds passent : le rand est tombe a 11.
-- Joueur C obtient 12 : il en dissipe DEUX (12 - 11 + 1).
ViderLesEtats()
local trois = D.Poser(moi, { nom = "Poison", id = "dot_poison",
    choix = { pv = 1, stacks = 2, rounds = 9 }, jet = 14 })
attendu("trois stacks", trois.dot.stacks, 3)
attendu("rand de départ", trois.dot.rand, 14)
for _ = 1, 3 do T.Round(moi) end
attendu("après trois rounds, le rand est tombé", trois.dot.rand, 11)

local partis, reste, rand = D.Dissiper(moi, "dot_poison", 12)
attendu("le rand battu était bien 11", rand, 11)
attendu("deux stacks partent", partis, 2)
attendu("il en reste un", reste, 1)

-- Un score qui ne bat pas le rand ne retire rien.
local rien = D.Dissiper(moi, "dot_poison", 11)
attendu("égaler le rand ne suffit pas", rien, 0)
-- Le dernier stack emporte l'etat.
local dernier, plus = D.Dissiper(moi, "dot_poison", 50)
attendu("le dernier stack part", dernier, 1)
attendu("et l'état avec", plus, 0)
attendu("il n'est plus porté", #D.Liste(moi), 0)

dire("== la dissipation par le reseau")
-- Le dissipateur ne connait pas l'etat exact des stacks de sa cible : il envoie
-- son SCORE, et c'est le porteur qui compte. On joue le role du porteur.
local recu = D.Poser(moi, { nom = "Gangrène", id = "dot_gangrene",
    choix = { pf = 1, stacks = 3, rounds = 9 }, jet = 16 })
attendu("quatre stacks", recu.dot.stacks, 4)

-- Ce que le porteur ANNONCE a qui veut dissiper : le rand courant, et ses
-- stacks. Un dot ancien se decroche plus facilement, l'annonce doit le dire.
T.Round(moi)
T.Round(moi)
local annonce
for _, e in ipairs(LCM.Actions.EtatsDe({ soi = true })) do
    if e.id == "dot_gangrene" then annonce = e end
end
attendu("il est annonce", annonce ~= nil, true)
attendu("avec son rand courant, pas le jet d'origine", annonce and annonce.seuil, 14)
attendu("et ses stacks", annonce and annonce.stacks, 4)

-- Le message de dissipation : score 16 contre rand 14 -> 3 stacks.
__groupe({ "Akriaxx" })
LCM.Reseau.Recevoir("Akriaxx", "91:1:1:dissipe|" .. LCM.Reseau.Encoder(
    { id = "dot_gangrene", nom = "Gangrène", sc = 16 }))
local reste
for _, e in ipairs(D.Liste(moi)) do if e.id == "dot_gangrene" then reste = e.dot.stacks end end
attendu("trois stacks partent, il en reste un", reste, 1)

-- Un etat ordinaire, lui, part d'un bloc : le chemin d'avant ne doit pas
-- avoir change.
T.Poser(moi, { nom = "Immobilisé", id = "imm_essai", rounds = 5, jet = { valeur = 10 } })
LCM.Reseau.Recevoir("Akriaxx", "92:1:1:dissipe|" .. LCM.Reseau.Encoder(
    { id = "imm_essai", nom = "Immobilisé" }))
local encore
for _, e in ipairs(T.Liste(moi)) do if e.id == "imm_essai" then encore = true end end
attendu("un état simple est retiré entièrement", encore, nil)
__groupe({})

dire("== ce qu'on en voit dans Sante")
-- Un dot n'est lisible que s'il dit TROIS choses : combien de stacks, ce qu'il
-- grignote, et le rand courant a battre. Sans le rand, impossible de juger si
-- une dissipation vaut le coup.
ViderLesEtats()
local fat = LCM.Entities.Gauge(moi, "fatigue")
LCM.Entities.SetGauge(moi, "fatigue", fat.max)
D.Poser(moi, { nom = "Fièvre", id = "dot_fievre",
    choix = { pf = 1, stacks = 1, rounds = 5 }, jet = 13 })

local resume, stacks, rand = D.Resume(moi, D.Liste(moi)[1])
attendu("le resume chiffre la morsure", resume, string.format("PF -%d", math.ceil(fat.max * 0.05 * 2)))
attendu("avec ses stacks", stacks, 2)
attendu("et son rand", rand, 13)

local V = LCM.UI.Vues.Basculer("sante")
V:Afficher("etats")
local bloc
for _, l in ipairs(V.pages.etats.lignes) do if l.vide then bloc = l end end
attendu("le bloc des etats", bloc ~= nil, true)
local ligne = bloc.lignes[1]
attendu("le dot y est, stacks devant le nom", ligne and ligne.nom:GetText(), "x2  Fièvre")
attendu("et sa morsure est annoncee",
    ligne and ligne.effets:GetText():find("PF %-%d+") ~= nil, true)

-- Une jauge ZONEE se dit en pourcentage : personne d'autre que le porteur ne
-- connait le maximum de la zone ou le coup tombera.
D.Poser(moi, { nom = "Saignement", id = "dot_saignement",
    choix = { pv = 2, rounds = 5 }, jet = 9 })
local resumePV = D.Resume(moi, D.Liste(moi)[2])
attendu("une zonee se dit en pourcentage", resumePV, "PV 10 %")

dire("== la note RP arrive a la cible")
-- Pour une jauge zonee, rien n'est applique : c'est une consigne a jouer, donc
-- elle doit se VOIR et pas se perdre dans le journal.
local avant = #__sorties
T.Round(moi)
local vuNote, vuMorsure = false, false
for i = avant + 1, #__sorties do
    local texte = tostring(__sorties[i] or "")
    if texte:find("répartir") then vuNote = true end
    if texte:find("grignote") then vuMorsure = true end
end
attendu("la note zonee est dite", vuNote, true)
attendu("et la morsure appliquee aussi", vuMorsure, true)
V:Hide()

dire("== un dot arrive par le reseau")
-- Un dot voyage par le MEME paquet « etat » que les buffs et debuffs : le champ
-- "dt" dit que c'en est un, et Core/Dot.lua le compose. Pas de second transport
-- a maintenir.
--
-- Comme tout debuff, il passe d'abord par la RESISTANCE de la cible : recevoir
-- le paquet ne pose rien, c'est le jet rate qui applique.
ViderLesEtats()
__groupe({ "Akriaxx" })

local function Recevoir(paquet)
    local avant = #LCM.Actions.effetsRecus
    LCM.Actions.RecevoirEtat(paquet, "Akriaxx")
    local recu = LCM.Actions.effetsRecus[avant + 1]
    return recu
end

local recu = Recevoir({
    t = "dot_recu", nom = "Venin", a = "Akriaxx", rp = "Akriaxx",
    deb = 1, js = "Esprit", jr = 99, ct = "etat",
    dt = { pf = 1, stacks = 1, rounds = 2 },
})
attendu("le paquet est reçu", recu ~= nil, true)
attendu("il attend une résistance", recu and recu.debuff, true)
-- Un jet du lanceur a 99 : la cible ne peut pas resister, le dot s'applique.
LCM.Actions.Resister(recu, recu.competences[1])

local pose
for _, e in ipairs(D.Liste(moi)) do if e.id == "dot_recu" then pose = e end end
attendu("le dot est posé", pose ~= nil, true)
attendu("avec ses stacks", pose and pose.dot.stacks, 2)
attendu("sa durée vient de ce qu'on a dépensé", pose and pose.restant, 3)
attendu("et son rand est celui du lanceur", pose and pose.dot.rand, 99)
attendu("il est marqué débuff", pose and pose.debuff, true)

-- Un paquet SANS dot reste un etat ordinaire : l'ancien chemin ne doit pas
-- avoir bouge.
local recu2 = Recevoir({
    t = "etat_recu", nom = "Ralenti", a = "Akriaxx", deb = 1, jr = 99, js = "Esprit",
    r = 2, ct = "etat",
})
LCM.Actions.Resister(recu2, recu2.competences[1])
local simple
for _, e in ipairs(T.Liste(moi)) do if e.id == "etat_recu" then simple = e end end
attendu("un état ordinaire passe toujours", simple ~= nil, true)
attendu("et ce n'est pas un dot", simple and simple.dot, nil)
__groupe({})

dire("== le pool : ce qu'on a a depenser")
-- Bati comme celui du buff : une statistique source, la moyenne des
-- penetrations choisies, le niveau du sort, le tout module par la puissance de
-- la mecanique « Dot ».
LCM.Entities.Set_Value(moi, "force", 6)
LCM.Entities.Set_Value(moi, "meca_dot", 0)
local p = E.dot.pool
local force = LCM.Formules.Primaire(moi, "force")
local brutAttendu = force * p.parSource + 4 * p.parPen + 3 * p.parNiveau
local pool, brut, mult = D.Pool(moi, { source = "force", penMoyenne = 4, niveau = 3 })
attendu("le brut suit la formule", brut, brutAttendu)
-- Sans point investi, la mecanique vaut sa base : 70 %.
attendu("le multiplicateur est celui de la mécanique", mult,
    E.puissanceMecanique.base / 100)
attendu("le pool est le produit, arrondi", pool, math.floor(brutAttendu * mult))

-- Investir dans la mecanique agrandit le pool.
LCM.Entities.Set_Value(moi, "meca_dot", 4)
local poolMieux = D.Pool(moi, { source = "force", penMoyenne = 4, niveau = 3 })
attendu("investir dans la mécanique agrandit le pool", poolMieux > pool, true)

-- Et le reglage d'equilibrage le gouverne : « le dot est trop fort, on le passe
-- a 50 % ». C'est le panneau MJ qui ecrira ce chemin.
LCM.Reglages.Definir(LCM.Reglages.CheminMecanique("dot", "base"), 35)
local poolFaible = D.Pool(moi, { source = "force", penMoyenne = 4, niveau = 3 })
attendu("le réglage d'équilibrage le gouverne", poolFaible < poolMieux, true)
LCM.Reglages.Retirer(LCM.Reglages.CheminMecanique("dot", "base"))
LCM.Entities.Set_Value(moi, "meca_dot", 0)

dire("== penetration et resistance s'equilibrent")
-- La regle voulue : a valeurs egales, ni l'un ni l'autre ne l'emporte.
attendu("à valeurs égales, le facteur vaut 1", D.FacteurResistance(10, 10), 1)
attendu("une cible qui résiste mieux encaisse moins", D.FacteurResistance(10, 20) < 1, true)
attendu("une cible qui résiste moins encaisse plus", D.FacteurResistance(20, 10) > 1, true)
-- Borne des deux cotes : un dot n'est jamais ni nul ni devastateur.
attendu("jamais nul", D.FacteurResistance(1, 1000), E.dot.resistance.plancher)
attendu("jamais dévastateur", D.FacteurResistance(1000, 1), E.dot.resistance.plafond)
attendu("deux zéros ne divisent pas par zéro", D.FacteurResistance(0, 0), 1)

dire("== la resistance reduit la MORSURE, pas le pool")
ViderLesEtats()
local f2 = LCM.Entities.Gauge(moi, "fatigue")
LCM.Entities.SetGauge(moi, "fatigue", f2.max)
-- Le meme dot, pose avec un facteur de moitie.
D.Poser(moi, { nom = "Rouille", id = "dot_rouille",
    choix = { pf = 1, rounds = 3 }, jet = 12, facteur = 0.5 })
local plein = math.ceil(f2.max * 0.05)
T.Round(moi)
local retire = f2.max - LCM.Entities.Gauge(moi, "fatigue").current
attendu("la morsure est réduite de moitié", retire, math.ceil(plein * 0.5))
-- Et le facteur est FIGE a la pose : le recalculer chaque round ferait varier
-- la morsure au gre d'un buff pose entre-temps.
local fige
for _, e in ipairs(D.Liste(moi)) do if e.id == "dot_rouille" then fige = e.dot.facteur end end
attendu("le facteur est retenu sur l'état", fige, 0.5)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
