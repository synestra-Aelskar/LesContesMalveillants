-- Ce que le MJ ecrit en seance : prise en compte immediate, et synchro entre
-- maitres du jeu.
--
-- Le nom du fichier date de l'epoque des « brouillons ». Depuis le 15 octobre
-- 2026, une entree enregistree EXISTE : plus de comptage « en attente
-- d'export », plus de signalement des doublons « deja publies », plus de
-- commande /lcm brouillons. Ces trois sections ont ete remplacees par ce qui
-- les remplace dans le jeu.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

-- Le MJ cree un trait AVANT la connexion (comme s'il venait d'une seance
-- precedente, deja en sauvegarde).
LCM.Brouillons.Set("traits", {
    id = "oeil_du_faucon",
    label = "Oeil du faucon",
    description = "Repere ce que les autres manquent.",
    bonus = { vue = 2, investigation = 1 },
    avantage = { "vue" },
})
LCM.Brouillons.Set("races", { id = "gobelin", label = "Gobelin", morphology = "humanoide" })

__declencher("PLAYER_LOGIN")

-- Un jeu d'equilibrage TEMOIN pour les traits d'essai. Le bareme BLOQUE depuis
-- le 3 octobre 2026 : un trait sans `forge` est refuse, et c'est voulu. Les
-- traits de ce scenario servent a tester la SYNCHRO, pas l'equilibrage — on
-- leur donne leur propre jeu plutot que de les accrocher a celui de la
-- campagne, qui a le droit de changer de bornes.
LCM.Brouillons.Enregistrer("jeux", {
    id = "essai_traits", label = "Essai (traits)", categorie = "traits",
    raretes = { { id = "libre", label = "Libre", points = 999, couleur = "FFFFFF" } },
}, true)

__personnage()   -- ce scenario joue un personnage : il le dit

dire("== ce qui est enregistre est jouable tout de suite")
attendu("le trait existe", LCM.Traits.Get("oeil_du_faucon") ~= nil, true)
attendu("la race aussi", LCM.Races.Get("gobelin") ~= nil, true)
attendu("le jeu temoin aussi", LCM.Forge.Get("essai_traits") ~= nil, true)

local moi = LCM.Entities.Self()
LCM.Traits.Grant(moi, "oeil_du_faucon")
attendu("bonus en vue", LCM.Traits.Bonus(moi, "vue"), 2)
attendu("bonus en investigation", LCM.Traits.Bonus(moi, "investigation"), 1)
attendu("avantage en vue", LCM.Traits.Advantage(moi, "vue") ~= nil, true)

dire("== un brouillon fautif est refuse, pas avale")
local avant = #__sorties
LCM.Brouillons.Set("traits", { id = "triche", label = "Triche", bonus = { force = 9 } })
-- il ne sera declare qu'au prochain WhenReady ; on force la declaration ici
local ok = pcall(LCM.Traits.Add, LCM.Brouillons.Get("traits", "triche"))
attendu("refus d un bonus primaire", ok, false)

dire("== une race inconnue en morphologie est refusee")
local ok2 = pcall(LCM.Races.Add, { id = "chimere", label = "Chimere", morphology = "nexistepas" })
attendu("refus", ok2, false)

dire("== une entree venue d'un fichier se modifie comme les autres")
-- Avant, il fallait la « reprendre en brouillon » ; sans ce detour, elle
-- etait refusee comme « contenu publie ».
local B1 = LCM.Brouillons
local escalade = LCM.Copie(LCM.Traits.Get("escalade_jungle"))
escalade.label = "Escalade de la jungle (corrigée)"
escalade.forge = "essai_traits/libre"
local modifiee, pourquoi = B1.Enregistrer("traits", escalade, false)
attendu("modifiee sans detour", modifiee, true)
if not modifiee then dire("   raison :", tostring(pourquoi)) end
attendu("  et en jeu", LCM.Traits.Get("escalade_jungle").label, "Escalade de la jungle (corrigée)")
local double, raisonDouble = B1.Enregistrer("traits", escalade, true)
attendu("la CREER une seconde fois est une collision", double, false)
dire("   ->", tostring(raisonDouble))

dire("== la commande /lcm brouillons n'existe plus")
local n = #__sorties
SlashCmdList.LCM("brouillons")
local liste = false
for i = n + 1, #__sorties do
    if __sansCouleur(__sorties[i]):find("en attente d'export", 1, true) then liste = true end
end
attendu("plus de liste d'attente a consulter", liste, false)

dire("== la synchro entre maitres du jeu")
-- On est deux a ecrire en seance : ce que l'un cree part TOUT DE SUITE chez
-- l'autre et s'y applique sans rien demander (5 octobre 2026).
local B2 = LCM.Brouillons
local avant = #__envois

-- Emission : ecrire un brouillon met un message sur le reseau.
B2.Enregistrer("traits", { id = "souffle_sync", label = "Souffle partagé", cout = 1, forge = "essai_traits/libre" }, true)
local partis = 0
for i = avant + 1, #__envois do
    if tostring(__envois[i].message or ""):find("brouillon") then partis = partis + 1 end
end
attendu("l'ecriture part sur le reseau", partis > 0, true)

-- Si le canal n'est pas encore pret (cas normal juste apres une connexion),
-- l'entree reste en attente au lieu d'etre abandonnee au hasard.
local rejoindre = LCM.Presence.Rejoindre
LCM.Presence.Rejoindre = function() return nil end
local avantAttente = B2.SynchronisationsEnAttente()
local avantCanal = #__envois
B2.Enregistrer("traits", { id = "canal_retarde", label = "Canal retardé", cout = 1, forge = "essai_traits/libre" }, true)
attendu("canal absent : le brouillon reste en attente",
    B2.SynchronisationsEnAttente() > avantAttente, true)
local partiSansCanal = false
for i = avantCanal + 1, #__envois do
    if tostring(__envois[i].message or ""):find("brouillon") then partiSansCanal = true end
end
attendu("canal absent : aucun faux envoi", partiSansCanal, false)
LCM.Presence.Rejoindre = rejoindre
__avancer(1.1)
local partiApresCanal = false
for i = avantCanal + 1, #__envois do
    if tostring(__envois[i].message or ""):find("brouillon") then partiApresCanal = true end
end
attendu("le brouillon part quand le canal revient", partiApresCanal, true)

-- Reception : ce qui arrive s'applique, sans question.
B2.Supprimer("traits", "souffle_sync")
attendu("retire chez nous", B2.Get("traits", "souffle_sync"), nil)
local paquet = LCM.Reseau.Encoder({ f = "traits",
    e = { id = "souffle_sync", label = "Souffle partagé", cout = 1, forge = "essai_traits/libre" } })
LCM.Reseau.Recevoir("Akriaxx", "7:1:1:brouillon|" .. paquet)
attendu("arrive chez nous tout seul", B2.Get("traits", "souffle_sync") ~= nil, true)
attendu("et devient jouable", LCM.Traits.Get("souffle_sync") ~= nil, true)

-- Une synchro fiable est acquittee et une relance n'est pas appliquee deux
-- fois. On change volontairement le libelle dans le doublon pour le prouver.
local paquetFiable = LCM.Reseau.Encoder({ s = "essai-dedoublonnage", f = "traits",
    e = { id = "dedouble", label = "Première version", cout = 1, forge = "essai_traits/libre" } })
local avantAccuse = #__envois
LCM.Reseau.Recevoir("Akriaxx", "71:1:1:brouillon|" .. paquetFiable)
local paquetDoublon = LCM.Reseau.Encoder({ s = "essai-dedoublonnage", f = "traits",
    e = { id = "dedouble", label = "Version qui ne doit pas passer", cout = 1, forge = "essai_traits/libre" } })
LCM.Reseau.Recevoir("Akriaxx", "72:1:1:brouillon|" .. paquetDoublon)
attendu("une relance n'est appliquee qu'une fois", B2.Get("traits", "dedouble").label,
    "Première version")
local accuses = 0
for i = avantAccuse + 1, #__envois do
    if tostring(__envois[i].message or ""):find("sync%-ok") then accuses = accuses + 1 end
end
attendu("chaque reception est acquittee", accuses, 2)
B2.Supprimer("traits", "dedouble")

-- Ce qui arrive ne REPART pas : sinon deux ateliers se le renvoient sans fin.
local avantRenvoi = #__envois
LCM.Reseau.Recevoir("Akriaxx", "8:1:1:brouillon|" .. paquet)
local renvois = 0
for i = avantRenvoi + 1, #__envois do
    if tostring(__envois[i].message or ""):find("brouillon") then renvois = renvois + 1 end
end
attendu("rien n'est renvoye", renvois, 0)

-- Un JEU D'EQUILIBRAGE traverse aussi, raretes comprises. Elles ne passaient
-- pas : l'encodeur triait les cles en les convertissant en texte, puis lisait
-- la table avec cette chaine — donc nil sur toute cle numerique, et les
-- TABLEAUX disparaissaient en silence (5 octobre 2026).
local jeu = { id = "jeu_reseau", label = "Jeu réseau", categorie = "traits",
    raretes = { { id = "commun", label = "Commun", points = 10, couleur = "FFFFFF" },
                { id = "rare", label = "Rare", points = 25, couleur = "4488FF" } },
    champs = { escalade = { cout = "2", max = "4" } } }
LCM.Reseau.Recevoir("Akriaxx", "11:1:1:brouillon|"
    .. LCM.Reseau.Encoder({ f = "jeux", e = jeu }))
local arrive = LCM.Forge.Get("jeu_reseau")
attendu("le jeu arrive", arrive ~= nil, true)
attendu("avec ses deux raretes", arrive and #arrive.raretes, 2)
attendu("nommees", arrive and arrive.raretes[2] and arrive.raretes[2].label, "Rare")
attendu("et ses champs", arrive and arrive.champs
    and arrive.champs.escalade and tostring(arrive.champs.escalade.max), "4")

-- La Forge gardait auparavant sa copie locale en cache : le registre etait
-- modifie, mais l'ecran semblait ne rien avoir recu.
LCM.UI.Forge.Editer(arrive)
local equilibre = LCM.UI.Forge.Equilibrage()
attendu("la forge montre la premiere version", equilibre:Travail().def.label, "Jeu réseau")
local jeuMaj = LCM.Copie(jeu)
jeuMaj.label = "Jeu réseau mis à jour"
LCM.Reseau.Recevoir("Akriaxx", "73:1:1:brouillon|"
    .. LCM.Reseau.Encoder({ s = "maj-jeu", f = "jeux", r = 1, e = jeuMaj }))
attendu("la forge recharge la modification distante", equilibre:Travail().def.label,
    "Jeu réseau mis à jour")
B2.Supprimer("jeux", "jeu_reseau")

-- Un trait garde ses bonus et son avantage en route.
local trait = { id = "t_reseau", label = "T réseau", cout = 1,
    forge = "essai_traits/libre",
    bonus = { escalade = 1 }, avantage = { "escalade" } }
LCM.Reseau.Recevoir("Akriaxx", "12:1:1:brouillon|"
    .. LCM.Reseau.Encoder({ f = "traits", e = trait }))
local tr = LCM.Traits.Get("t_reseau")
attendu("le trait arrive", tr ~= nil, true)
attendu("avec son bonus", tr and tr.bonus.escalade, 1)
attendu("et son avantage", tr and tr.avantage.escalade, true)
B2.Supprimer("traits", "t_reseau")

-- Une suppression voyage aussi.
LCM.Reseau.Recevoir("Akriaxx", "9:1:1:brouillon-|" .. LCM.Reseau.Encoder({ f = "traits", id = "souffle_sync" }))
attendu("la suppression arrive aussi", B2.Get("traits", "souffle_sync"), nil)

-- Un JOUEUR ne recoit rien : il n'a pas d'atelier.
local etaitCharge = __addonsCharges["LesContesMalveillants_MJ"]
LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = nil
attendu("on joue bien en joueur", LCM.IsMaster(), false)
LCM.Reseau.Recevoir("Akriaxx", "10:1:1:brouillon|" .. paquet)
attendu("un joueur n'en herite pas", B2.Get("traits", "souffle_sync"), nil)
LCM._masterCompanion = true
__addonsCharges["LesContesMalveillants_MJ"] = etaitCharge

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
