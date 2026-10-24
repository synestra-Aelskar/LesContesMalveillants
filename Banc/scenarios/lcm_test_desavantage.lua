-- Le desavantage se DECLARE, et un avantage l'annule (le MJ, 24 octobre 2026).
--
-- Remonte de l'event, deux plaintes, deux causes :
--
--   * « des lors qu'on a un etat negatif, on jette avec desavantage — c'est
--     beaucoup trop punitif. » Il s'imposait tout seul : le premier element
--     porte dont le bonus etait NEGATIF sur ce jet suffisait. Un etat qui
--     retirait un point d'Adresse condamnait tous les jets d'Adresse ;
--   * « un desavantage ne se contrebalance pas par un avantage. » L'annulation
--     etait pourtant ecrite ; ce qui manquait, c'etait de pouvoir en
--     REVENDIQUER un sans qu'un trait l'accorde.
--
-- Contenu TEMOIN : etats et trait d'essai, jamais ceux de la campagne.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

-- « vue » est un jet d'expertise, « adresse » un jet simple : les deux portes
-- par lesquelles un desavantage arrive.
LCM.Brouillons.Set("etats", { id = "fievre_temoin", label = "Fièvre témoin",
    categorie = "etat", bonus = { vue = -2 } })
LCM.Brouillons.Set("etats", { id = "aveugle_temoin", label = "Aveuglé témoin",
    categorie = "etat", bonus = { vue = -1 }, desavantage = { "vue" } })

__declencher("PLAYER_LOGIN")
__personnage()
local moi = LCM.Entities.Self()
local E, R, T = LCM.Effets, LCM.Roll, LCM.EtatsTemporaires

dire("== ce qu'une definition declare arrive jusqu'a l'element")
local fievre = LCM.Etats.Get("fievre_temoin")
local aveugle = LCM.Etats.Get("aveugle_temoin")
attendu("l'état témoin existe", fievre ~= nil and fievre.label, "Fièvre témoin")
attendu("  il retire bien des points", fievre.bonus.vue, -2)
attendu("  et ne déclare aucun désavantage", next(fievre.desavantage or {}), nil)
attendu("l'autre le déclare", (aveugle.desavantage or {}).vue, true)

dire("== un etat qui RETIRE des points n'impose plus le desavantage")
-- C'est toute la plainte : « beaucoup trop punitif ».
T.Poser(moi, { nom = "Fièvre témoin", bonus = fievre.bonus, id = "fievre_temoin" })
attendu("l'état est porté", #T.Liste(moi), 1)
attendu("les points sont bien retirés", LCM.Effets.Bonus(moi, "vue"), -2)
attendu("mais aucun désavantage", (E.Desavantage(moi, "vue")), nil)
local jet = R.Field(moi, "vue", {})
attendu("  le jet ne relance pas", #jet.jets, 1)
attendu("  et ne se dit pas désavantagé", jet.desavantage, false)
T.Retirer(moi, "Fièvre témoin")

dire("== un etat qui le DECLARE l'impose")
T.Poser(moi, { nom = "Aveuglé témoin", bonus = aveugle.bonus,
    desavantage = aveugle.desavantage, id = "aveugle_temoin" })
local genant, source = E.Desavantage(moi, "vue")
attendu("le désavantage est là", genant ~= nil and genant.label, "Aveuglé témoin")
attendu("  et il vient de l'état", source, "état temporaire")
jet = R.Field(moi, "vue", {})
attendu("le jet relance", #jet.jets, 2)
attendu("  et garde le pire", jet.garde, math.min(jet.jets[1], jet.jets[2]))

dire("== un avantage revendique l'ANNULE, sans qu'aucun trait l'accorde")
attendu("aucun trait ne donne l'avantage", (E.Avantage(moi, "vue")), nil)
jet = R.Field(moi, "vue", { avantage = true })
attendu("un seul dé", #jet.jets, 1)
attendu("  plus de désavantage", jet.desavantage, false)
attendu("  ni d'avantage", jet.avantage, false)
attendu("  la fenêtre peut dire qu'il a servi à annuler", jet.annule, true)
-- Et l'on ne pretend pas lui avoir refuse son avantage : il a servi.
attendu("  sans se dire refusé", jet.avantageRefuse, false)

dire("== l'avantage SEUL exige toujours un trait")
T.Retirer(moi, "Aveuglé témoin")
jet = R.Field(moi, "vue", { avantage = true })
attendu("un seul dé", #jet.jets, 1)
attendu("  et le refus se dit", jet.avantageRefuse, true)
attendu("  sans annulation", jet.annule, false)

dire("== un jet d'EXPERTISE accepte l'annulation")
-- Il refusait de partir : « aucun trait ne donne de bonus a cette expertise ».
T.Poser(moi, { nom = "Aveuglé témoin", bonus = aveugle.bonus,
    desavantage = aveugle.desavantage, id = "aveugle_temoin" })
local res, raison = R.ResoudreExpertise(moi, "vue", 10, 0, { avantage = true })
attendu("le jet part", res ~= nil, true)
if not res then dire("     refus :", tostring(raison)) end
attendu("  et il a annulé", res and res.jet and res.jet.annule, true)
-- Sans desavantage a annuler, la regle d'avant tient.
T.Retirer(moi, "Aveuglé témoin")
local sans, pourquoi = R.ResoudreExpertise(moi, "vue", 10, 0, { avantage = true })
attendu("sans désavantage, l'avantage se mérite", sans, nil)
attendu("  et on dit pourquoi",
    tostring(pourquoi):find("aucun trait", 1, true) ~= nil, true)

dire("== un trait, lui, garde sa faiblesse")
-- « On ne choisit pas ses faiblesses » : un defaut pris a la creation impose
-- encore le desavantage. Le MJ n'a pas demande a changer les traits.
-- « initiative » plutot qu'une primaire : un trait n'a pas le droit d'y
-- toucher, et c'est le code qui le verifie.
LCM.Traits.Add({ id = "maladroit_temoin", label = "Maladroit témoin", cout = 1,
    bonus = { initiative = -1 } })
-- Les traits portes se lisent sur entity.traits, pas dans les valeurs : les
-- poser par Set_Value ne les fait porter a personne.
moi.traits = { "maladroit_temoin" }
local porte = false
for _, t in ipairs(LCM.Traits.Owned(moi)) do
    if t.id == "maladroit_temoin" then porte = true end
end
attendu("le trait est porté", porte, true)
if porte then
    local g, s = E.Desavantage(moi, "initiative")
    attendu("il impose encore le désavantage", g ~= nil and g.label, "Maladroit témoin")
    attendu("  et ça vient d'un trait", s, "trait")
end

dire("== poser et retirer un etat depuis la CONSULTATION (24 octobre 2026)")
-- La fenetre Sante d'une fiche consultee ne permettait ni l'un ni l'autre : le
-- bouton « Retirer » etait cache des que la fiche etait distante — le retirer
-- sur une copie recue n'aurait rien change chez le joueur — et il n'existait
-- aucune route reseau pour le demander.
__groupe({ LCM.PlayerId(), "Nytherah-Apertus" })
attendu("il y a une route pour imposer", type(T.Envoyer), "function")
attendu("et une pour retirer", type(T.EnvoyerRetrait), "function")

local avantEnvois = #__envois
attendu("le MJ impose un état", (T.Envoyer("Nytherah-Apertus", "aveugle_temoin", 3)), true)
local function DernierSujet(sujet, depuis)
    for i = #__envois, (depuis or 0) + 1, -1 do
        local corps = tostring(__envois[i].message or ""):match("^%d+:%d+:%d+:(.*)$")
        if corps and corps:sub(1, #sujet + 1) == sujet .. "|" then
            return __envois[i], LCM.Reseau.Decoder(corps:sub(#sujet + 2))
        end
    end
end
local envoi, paquet = DernierSujet("etat_mj", avantEnvois)
attendu("  en privé, au joueur", envoi and envoi.cible, "Nytherah-Apertus")
attendu("  seul l'identifiant voyage", paquet and paquet.i, "aveugle_temoin")
attendu("  avec la durée", paquet and tostring(paquet.r), "3")

avantEnvois = #__envois
attendu("le MJ retire un état", (T.EnvoyerRetrait("Nytherah-Apertus", "Aveuglé témoin")), true)
envoi, paquet = DernierSujet("etat_mj-", avantEnvois)
attendu("  en privé aussi", envoi and envoi.cible, "Nytherah-Apertus")
attendu("  et il nomme l'état", paquet and paquet.n, "Aveuglé témoin")
attendu("sur soi-même, non : la fiche locale suffit",
    (T.EnvoyerRetrait(LCM.PlayerId(), "Aveuglé témoin")), false)

dire("== et le joueur applique ce que le MJ demande")
-- C'est lui qui pose et retire : un paquet ne porte jamais les effets, ils
-- viennent du catalogue partage.
T.Retirer(moi, "Aveuglé témoin")
LCM.Reseau.Recevoir("Nytherah-Apertus",
    "1:1:1:etat_mj|" .. LCM.Reseau.Encoder({ i = "aveugle_temoin", r = 2 }), "WHISPER")
local pose
for _, e in ipairs(T.Liste(moi)) do if e.nom == "Aveuglé témoin" then pose = e end end
attendu("l'état est posé", pose ~= nil, true)
attendu("  avec sa durée", pose and pose.restant, 2)
-- Il voyage en ENSEMBLE, comme Effets.Lire le met en forme, pas en liste :
-- c'est sous cette forme que Effets.Desavantage le lit.
attendu("  et son désavantage déclaré", pose and (pose.desavantage or {}).vue, true)
attendu("  qui agit", (E.Desavantage(moi, "vue")) ~= nil, true)
LCM.Reseau.Recevoir("Nytherah-Apertus",
    "1:1:1:etat_mj-|" .. LCM.Reseau.Encoder({ n = "Aveuglé témoin" }), "WHISPER")
attendu("le retrait est appliqué", (function()
    for _, e in ipairs(T.Liste(moi)) do if e.nom == "Aveuglé témoin" then return false end end
    return true
end)(), true)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
