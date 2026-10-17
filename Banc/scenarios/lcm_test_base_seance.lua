-- La base publique en seance (Core/BasePublique.lua, 17 octobre 2026) :
-- ce que le MJ enregistre part tout de suite chez les joueurs, une demande
-- ne coute qu'un message quand tout concorde, et sans MJ un tiers du groupe
-- relaie ce qu'il sait de plus recent — sans jamais faire la loi.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__groupe({ "Joueur-Apertus", "Tiers-Apertus" })
__declencher("PLAYER_LOGIN")
__personnage()

local B = LCM.BasePublique
local R = LCM.Reseau

-- Un jeu d'equilibrage TEMOIN : ce scenario teste la diffusion, pas le bareme.
LCM.Brouillons.Enregistrer("jeux", {
    id = "essai_base", label = "Essai (base)", categorie = "traits",
    raretes = { { id = "libre", label = "Libre", points = 999, couleur = "FFFFFF" } },
}, true)

-- Ce qui part, en clair : on ecoute Reseau.Envoyer plutot que de recoller les
-- morceaux du banc.
local envois = {}
local envoyer = R.Envoyer
R.Envoyer = function(sujet, donnees, canal, cible, options)
    envois[#envois + 1] = { sujet = sujet, donnees = donnees, canal = canal, cible = cible }
    return envoyer(sujet, donnees, canal, cible, options)
end
local function sujets(depuis, sujet)
    local out = {}
    for i = depuis or 1, #envois do
        if not sujet or envois[i].sujet == sujet then out[#out + 1] = envois[i] end
    end
    return out
end

-- Le temps passe pour tout le monde : l'horloge (GetTime, GetServerTime)
-- et les cadres qui battent la mesure.
local function passer(secondes)
    __avancerTemps(secondes)
    __avancer(secondes)
end

local numero = 700
local function recevoir(expediteur, sujet, donnees)
    numero = numero + 1
    R.Recevoir(expediteur, string.format("%d:1:1:%s|%s", numero, sujet, R.Encoder(donnees or {})))
end

local function trait(id, label)
    return { id = id, label = label, description = "Essai.", forge = "essai_base/libre",
        bonus = { vue = 1 } }
end

dire("== MJ : enregistrer, c'est envoyer")
attendu("on est MJ", LCM.IsMaster(), true)
local avant = #envois
local ok, raison = LCM.Brouillons.Enregistrer("traits", trait("essai_seance", "Essai de séance"), true)
attendu("le trait s'enregistre", ok, true)
local plus = sujets(avant + 1, "base+")
attendu("il part chez les joueurs tout de suite", #plus, 1)
attendu("sur le canal de presence", plus[1] and plus[1].canal, "CHANNEL")
attendu("avec sa cle", plus[1] and plus[1].donnees.cle, "traits/essai_seance")

avant = #envois
LCM.Brouillons.Enregistrer("traits", trait("essai_seance", "Essai de séance"), false)
attendu("le reenregistrer tel quel ne renvoie rien", #sujets(avant + 1, "base+"), 0)
LCM.Brouillons.Enregistrer("traits", trait("essai_seance", "Essai modifié"), false)
attendu("le modifier le renvoie", #sujets(avant + 1, "base+"), 1)

avant = #envois
local prive = trait("essai_prive", "Secret")
prive.distributionMJ = true
LCM.Brouillons.Enregistrer("traits", prive, true)
attendu("une entree reservee au MJ ne part pas", #sujets(avant + 1, "base+"), 0)

avant = #envois
LCM.Brouillons.Supprimer("traits", "essai_seance")
attendu("la supprimer le dit aux joueurs", #sujets(avant + 1, "base-"), 1)
LCM.Brouillons.Enregistrer("traits", trait("essai_seance", "Essai revenu"), false)

dire("== MJ : une demande, une empreinte")
avant = #envois
recevoir("Joueur-Apertus", "base?", { e = "autre", q = 0 })
recevoir("Joueur-Apertus", "base?", { e = "autre", q = 0 })   -- la meme, par le groupe
local offres = sujets(avant + 1, "base=")
attendu("une seule reponse pour les deux canaux", #offres, 1)
attendu("en un message, sans la liste", #sujets(avant + 1, "base_liste"), 0)
attendu("signee MJ", offres[1] and offres[1].donnees.m, 1)
local empreinteMJ = offres[1] and offres[1].donnees.e

avant = #envois
recevoir("Joueur-Apertus", "base_liste?", {})
local listes = sujets(avant + 1, "base_liste")
attendu("la liste ne part que si on la demande", #listes, 1)
local listeMJ = listes[1] and LCM.Lien.Deserialiser(listes[1].donnees.corps) or {}
attendu("elle porte ce qui a ete ecrit en seance", listeMJ["traits/essai_seance"] ~= nil, true)
attendu("pas ce qui est reserve au MJ", listeMJ["traits/essai_prive"], nil)

avant = #envois
passer(6)
recevoir("Ancien-Apertus", "base?", {})
attendu("un joueur pas a jour recoit la liste, comme avant", #sujets(avant + 1, "base_liste"), 1)

local ajout = plus[1]
local revisionMJ = listeMJ["traits/essai_seance"]
local corpsMJ
avant = #envois
recevoir("Joueur-Apertus", "base_demande", { cles = "traits/essai_seance" })
for _, e in ipairs(sujets(avant + 1, "base_entree")) do corpsMJ = e.donnees.corps end
attendu("le MJ sert l'entree de seance", corpsMJ ~= nil, true)

-- ===== Cote joueur ===========================================================
-- Le meme client passe en mode joueur : il ne sert plus rien, il recoit. On
-- efface d'abord ce que le MJ a pose en memoire, pour le voir revenir.
LCM.BasculerModeJoueur(true)
attendu("on est joueur", LCM.IsMaster(), false)
LCM.Traits.Retirer("essai_seance")
LCM.db.basePublique = {}
passer(31)

dire("== joueur : la demande porte son empreinte")
avant = #envois
B.Demander(true)
local demandes = sujets(avant + 1, "base?")
attendu("la demande part", #demandes > 0, true)
attendu("avec une empreinte", demandes[1] and type(demandes[1].donnees.e), "string")

dire("== joueur : le MJ a autre chose, on synchronise")
avant = #envois
recevoir("Maitre-Apertus", "base=", { e = empreinteMJ, m = 1 })
attendu("on demande la liste au MJ", #sujets(avant + 1, "base_liste?"), 1)
recevoir("Maitre-Apertus", "base_liste", { corps = LCM.Lien.Serialiser(listeMJ) })
local demande = sujets(avant + 1, "base_demande")[1]
attendu("on ne demande que ce qui differe", demande and demande.donnees.cles, "traits/essai_seance")
recevoir("Maitre-Apertus", "base_entree", { cle = "traits/essai_seance", revision = revisionMJ, corps = corpsMJ })
recevoir("Maitre-Apertus", "base_fin", {})
local recu = LCM.Traits.Get("essai_seance")
attendu("le trait de seance est la", recu and recu.label, "Essai revenu")
attendu("notre empreinte est celle du MJ", B.Empreinte(), empreinteMJ)

dire("== joueur : quand tout concorde, rien d'autre ne voyage")
passer(31)
avant = #envois
B.Demander(true)
recevoir("Maitre-Apertus", "base=", { e = empreinteMJ, m = 1 })
attendu("pas de liste", #sujets(avant + 1, "base_liste?"), 0)
local confirme = LCM.db.basePublique["traits/essai_seance"]
attendu("l'entree est confirmee a l'heure serveur", confirme and confirme.quand, GetServerTime())

dire("== joueur : en seance, la modification arrive seule")
local modifie = trait("essai_seance", "Essai en direct")
recevoir("Maitre-Apertus", "base+", { cle = "traits/essai_seance", revision = "jmodif",
    corps = LCM.Lien.Serialiser(modifie) })
recu = LCM.Traits.Get("essai_seance")
attendu("le trait est a jour", recu and recu.label, "Essai en direct")
local nouveau = trait("essai_neuf", "Tout neuf")
recevoir("Maitre-Apertus", "base+", { cle = "traits/essai_neuf", revision = "jneuf",
    corps = LCM.Lien.Serialiser(nouveau) })
attendu("un trait cree en seance existe chez le joueur", LCM.Traits.Get("essai_neuf") ~= nil, true)
attendu("et il est garde pour la prochaine connexion",
    LCM.db.basePublique["traits/essai_neuf"] and LCM.db.basePublique["traits/essai_neuf"].revision, "jneuf")
local cache = trait("essai_cache", "Secret envoyé")
cache.distributionMJ = true
recevoir("Maitre-Apertus", "base+", { cle = "traits/essai_cache", revision = "jcache",
    corps = LCM.Lien.Serialiser(cache) })
attendu("une entree reservee au MJ, meme envoyee, reste absente", LCM.Traits.Get("essai_cache"), nil)
attendu("et n'est pas gardee", LCM.db.basePublique["traits/essai_cache"], nil)
recevoir("Maitre-Apertus", "base-", { cle = "traits/essai_neuf" })
attendu("une suppression retire le trait", LCM.Traits.Get("essai_neuf"), nil)
attendu("et s'en souvient", LCM.db.basePublique["traits/essai_neuf"].supprime, true)

dire("== joueur : sans MJ, le tiers le plus a jour relaie")
-- On oublie le trait de seance, comme un joueur qui n'etait pas connecte.
LCM.Traits.Retirer("essai_seance")
LCM.db.basePublique["traits/essai_seance"] = nil
local heure = GetServerTime()
local liste = {}
for cle, v in pairs(B.Versions()) do liste[cle] = v.revision .. "@0" end
liste["traits/essai_seance"] = "jrelais@" .. heure
liste["traits/essai_vieux"] = "jvieux@" .. (heure - 100000)
liste["traits/essai_neuf"] = "jneuf@" .. (heure - 100000)   -- plus vieux que la suppression
-- Une entree du fichier que ce relais ne porte pas : il ne la retire pas.
local absente
for cle in pairs(LCM.SourcePublique) do
    if cle:match("^traits/") then absente = cle break end
end
liste[absente] = nil

passer(31)
avant = #envois
B.Demander(true)
recevoir("Tiers-Apertus", "base=", { e = "x", q = heure - 50 })
recevoir("Autre-Apertus", "base=", { e = "y", q = heure })
attendu("on attend : un MJ pourrait encore repondre", #sujets(avant + 1, "base_liste?"), 0)
passer(B.ATTENTE_OFFRES + 1)
local choix = sujets(avant + 1, "base_liste?")[1]
attendu("on choisit le relais le plus frais", choix and choix.cible, "Autre-Apertus")
recevoir("Autre-Apertus", "base_liste", { corps = LCM.Lien.Serialiser(liste), r = 1 })
demande = sujets(avant + 1, "base_demande")[1]
local cles = demande and demande.donnees.cles or ""
attendu("on lui demande l'entree qu'il sait plus recente", cles:find("traits/essai_seance", 1, true) ~= nil, true)
attendu("pas celle dont on tient une suppression plus recente", cles:find("traits/essai_neuf", 1, true), nil)
recevoir("Autre-Apertus", "base_entree", { cle = "traits/essai_seance", revision = "jrelais",
    quand = heure, corps = LCM.Lien.Serialiser(trait("essai_seance", "Par un tiers")) })
recevoir("Autre-Apertus", "base_fin", {})
recu = LCM.Traits.Get("essai_seance")
attendu("le tiers l'a transmise", recu and recu.label, "Par un tiers")
attendu("avec l'heure du MJ, pas la sienne",
    LCM.db.basePublique["traits/essai_seance"].quand, heure)
attendu("un relais ne supprime pas ce qu'il ne porte pas",
    LCM.Traits.Get(absente:match("/(.+)$")) ~= nil, true)

dire("== joueur : un relais ne parle que s'il en sait plus")
avant = #envois
passer(6)
recevoir("Tiers-Apertus", "base?", { e = B.Empreinte(), q = heure })
attendu("meme empreinte : silence", #sujets(avant + 1, "base="), 0)
passer(6)
recevoir("Tiers-Apertus", "base?", { e = "autre", q = heure + 10 })
attendu("il en sait plus que nous : silence", #sujets(avant + 1, "base="), 0)
passer(6)
recevoir("Tiers-Apertus", "base?", { e = "autre", q = 0 })
attendu("on en sait plus : on se propose", #sujets(avant + 1, "base="), 1)
passer(6)
recevoir("Inconnu-Apertus", "base?", { e = "autre", q = 0 })
attendu("hors du groupe : silence", #sujets(avant + 2, "base="), 0)

dire("== joueur : le MJ revient et fait la loi")
passer(31)
B.Demander(true)
recevoir("Maitre-Apertus", "base=", { e = empreinteMJ, m = 1 })
recevoir("Maitre-Apertus", "base_liste", { corps = LCM.Lien.Serialiser(listeMJ) })
recevoir("Maitre-Apertus", "base_entree", { cle = "traits/essai_seance", revision = revisionMJ, corps = corpsMJ })
recevoir("Maitre-Apertus", "base_fin", {})
recu = LCM.Traits.Get("essai_seance")
attendu("la version du MJ remplace celle du tiers", recu and recu.label, "Essai revenu")
attendu("et l'empreinte est de nouveau la sienne", B.Empreinte(), empreinteMJ)

LCM.BasculerModeJoueur(false)
dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
