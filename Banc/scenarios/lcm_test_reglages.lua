-- Les reglages d'equilibrage : changer un nombre du jeu en seance.
--
-- « Le perce-armure est trop fort, on passe ses degats a 90 % » demandait
-- d'ouvrir un fichier, de republier, et de faire mettre a jour tout le monde
-- (9 octobre 2026). Une surcharge s'applique tout de suite, se range dans la
-- sauvegarde, et reste a reporter dans le fichier.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()
LCM.db.settings.modeJoueur = nil
LCM._masterCompanion = true

local R, E = LCM.Reglages, LCM.Equilibrage

dire("== lire un vecteur par son chemin")
attendu("un nombre simple", R.Lire("pa.base"), E.pa.base)
attendu("un nombre profond", R.Lire("pv.constitution.base"), E.pv.constitution.base)
attendu("un chemin qui n'existe pas", R.Lire("nimporte.quoi"), nil)

dire("== surcharger, et revenir en arriere")
local avant = E.pa.base
attendu("on pose", R.Definir("pa.base", 9), true)
attendu("la valeur a changé dans l'équilibrage", E.pa.base, 9)
attendu("le défaut est retenu", R.Defaut("pa.base"), avant)
attendu("et la surcharge est rangée", R.Surcharges()["pa.base"], 9)
attendu("on la compte", R.Compte() >= 1, true)

attendu("on retire", R.Retirer("pa.base"), true)
attendu("le fichier reprend la main", E.pa.base, avant)
attendu("plus de surcharge rangée", R.Surcharges()["pa.base"], nil)

dire("== ce qui n'est pas un nombre est refusé")
local ok, raison = R.Definir("pa.base", "beaucoup")
attendu("un texte est refusé", ok, false)
attendu("et on dit pourquoi", tostring(raison):find("nombre") ~= nil, true)
attendu("un chemin inconnu aussi", (R.Definir("rien.du.tout", 1)), true)
-- Un chemin inconnu se CREE (parMecanique est vide au depart) : c'est voulu.
R.Retirer("rien.du.tout")

dire("== le cas qui a fait naitre le module")
-- La grille de puissance lit parMecanique[id], avec repli sur la valeur
-- globale. Elle etait vide : rien ne pouvait la remplir.
local globale = E.puissanceMecanique.base
attendu("le perce-armure suit la valeur globale",
    R.PuissanceMecanique("perce_armure").base, globale)
attendu("et n'a pas de réglage propre",
    R.PuissanceMecanique("perce_armure").propre, false)

local chemin = R.CheminMecanique("perce_armure", "base")
attendu("le chemin attendu", chemin, "puissanceMecanique.parMecanique.perce_armure.base")
attendu("on le passe à 90", R.Definir(chemin, 90), true)
attendu("le perce-armure est à 90", R.PuissanceMecanique("perce_armure").base, 90)
attendu("il a maintenant son réglage", R.PuissanceMecanique("perce_armure").propre, true)
-- Et SEULEMENT lui : une surcharge par mecanique ne doit pas deborder.
attendu("le soin n'a pas bougé", R.PuissanceMecanique("soin").base, globale)
attendu("ni la valeur globale", E.puissanceMecanique.base, globale)
R.Retirer(chemin)
attendu("retiré, il revient au global", R.PuissanceMecanique("perce_armure").base, globale)

dire("== le tableau des vecteurs")
local vecteurs = R.Vecteurs()
attendu("il y en a beaucoup", #vecteurs > 30, true)
local parChemin = {}
for _, v in ipairs(vecteurs) do parChemin[v.chemin] = v end
attendu("pa.base y est", parChemin["pa.base"] ~= nil, true)
attendu("avec sa valeur", parChemin["pa.base"].valeur, E.pa.base)
-- Les listes de definitions ne sont pas des vecteurs d'equilibrage : les
-- melanger noierait les nombres qu'on veut vraiment regler.
local pollution = 0
for _, v in ipairs(vecteurs) do
    if v.chemin:find("^mecaniques%.") or v.chemin:find("^primaires%.")
        or v.chemin:find("^types%.") then pollution = pollution + 1 end
end
attendu("les listes de données sont écartées", pollution, 0)

local groupes = {}
for _, g in ipairs(R.Groupes()) do groupes[g] = true end
attendu("les groupes sont listés", groupes.pv and groupes.dot and true, true)
local duDot = R.Vecteurs("dot")
attendu("on peut n'en demander qu'un", #duDot > 0, true)
local tousDuDot = true
for _, v in ipairs(duDot) do if not v.chemin:find("^dot%.") then tousDuDot = false end end
attendu("et il ne contient que lui", tousDuDot, true)

dire("== la surcharge voyage, sinon on ne joue pas au même jeu")
-- Le MJ regle, le joueur calcule : sans diffusion, sa fiche garderait l'ancien
-- nombre et les deux ne joueraient pas au meme jeu.
__groupe({ "Akriaxx" })
local envois = #__envois
R.Definir("pa.base", 7)
local parti = false
for i = envois + 1, #__envois do
    if tostring(__envois[i].message or ""):find("regl", 1, true) then parti = true end
end
attendu("le réglage part sur le réseau", parti, true)
R.Retirer("pa.base")

-- Et il s'applique en arrivant.
LCM.Reseau.Recevoir("Akriaxx", "40:1:1:regl|" .. LCM.Reseau.Encoder({ c = "pa.base", v = 11 }))
attendu("un réglage reçu s'applique", E.pa.base, 11)
LCM.Reseau.Recevoir("Akriaxx", "41:1:1:regl|" .. LCM.Reseau.Encoder({ c = "pa.base" }))
attendu("et son retrait aussi", E.pa.base, avant)
__groupe({})

dire("== un reglage publie devient la reference")
-- Le fichier genere appelle Publier au chargement. La difference avec Definir
-- compte : un reglage publie n'est plus une surcharge, il ne se range pas dans
-- la sauvegarde et ne se rediffuse pas — sinon il serait eternellement
-- reannonce comme « a exporter ».
local avantPub = E.initiative.parNiveau
attendu("on publie", R.Publier("initiative.parNiveau", 3), true)
attendu("la valeur est prise", E.initiative.parNiveau, 3)
attendu("rien n'est rangé en surcharge", R.Surcharges()["initiative.parNiveau"], nil)
attendu("et c'est le nouveau défaut", R.Defaut("initiative.parNiveau"), 3)
R.Publier("initiative.parNiveau", avantPub)

dire("== une surcharge devenue identique au fichier s'oublie")
-- Sinon elle resterait « a exporter » pour toujours, alors qu'elle est deja
-- dans le depot. Meme regle que les brouillons du compendium.
R.Definir("fatigue.base", 21)
attendu("la surcharge est là", R.Surcharges()["fatigue.base"], 21)
-- Le depot la publie a son tour, a la meme valeur.
R.Publier("fatigue.base", 21)
local oubliees = R.OublierLesRedondantes()
attendu("elle est oubliée", oubliees >= 1, true)
attendu("plus rien à exporter pour elle", R.Surcharges()["fatigue.base"], nil)
attendu("mais la valeur reste celle du fichier", E.fatigue.base, 21)
-- Une surcharge qui DIFFERE du fichier, elle, survit : c'est du travail en
-- cours, pas un doublon.
R.Definir("fatigue.base", 25)
R.OublierLesRedondantes()
attendu("une surcharge différente survit", R.Surcharges()["fatigue.base"], 25)
R.Retirer("fatigue.base")

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
