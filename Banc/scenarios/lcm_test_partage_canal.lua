-- Coffres, points de recolte, vendeurs et sacs au sol se partagent avec TOUS
-- les possesseurs de l'addon — pas seulement avec le raid.
--
-- Le defaut, rapporte le 20 octobre 2026 : « j'ai fait mes coffres, Bily se
-- connecte, il va a l'emplacement, il n'a rien ». Deux moities manquaient, et
-- il fallait les deux :
--
--   * l'ENVOI partait sur le canal du GROUPE. Hors du raid, personne ne
--     recevait rien ;
--   * la RECEPTION refusait tout expediteur hors du groupe. Meme envoye sur le
--     canal de l'addon, un coffre venu d'un MJ hors groupe etait jete.
--
-- Et tout cela doit rester muet : le canal est un canal de discussion, mais il
-- ne porte que des messages d'addon et il est retire des fenetres de chat.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

LCM.Brouillons.Set("objets", { id = "babiole_canal", label = "Babiole témoin",
    categorie = "accessoire", pileMax = 1 })
LCM.Brouillons.Set("ressources", { id = "herbe_canal", label = "Herbe témoin" })
LCM.Brouillons.Set("devises", { id = "piece_canal", label = "Pièce témoin" })
LCM.Brouillons.Set("points", {
    id = "coffre_canal", label = "Coffre témoin", nature = "coffre",
    coffre = { places = 4, rayon = 4, verrous = 0, reset = false, expertises = {}, outils = {},
        objets = { { entree = "objets/babiole_canal", quantite = 1 } } },
})
LCM.Brouillons.Set("points", {
    id = "filon_canal", label = "Filon témoin", nature = "ressource",
    recolte = { entree = "ressources/herbe_canal", dd = 0, rayon = 3,
        ressources = { { entree = "ressources/herbe_canal", min = 1, max = 1 } } },
})
LCM.Brouillons.Set("points", {
    id = "etal_canal", label = "Étal témoin", nature = "vendeur",
    deviseDefaut = "piece_canal", rayon = 3,
    onglets = { { id = "o1", label = "Articles", offres = {
        { id = "herbe", entree = "ressources/herbe_canal", quantite = 1, prix = 1,
          devise = "piece_canal" },
    } } },
})

__declencher("PLAYER_LOGIN")
__personnage()
local MOI = LCM.PlayerId()
local R, C = LCM.Reseau, LCM.Coffres

local function GPS(x, y, z)
    LCM.DeplacementForce.NoterGPS(string.format(
        "Map: 585 (Magisters' Terrace) Zone: 0 ( <unknown> ), Area: 0 ( <unknown> ), "
        .. "Phase: 158070, X: %f, Y: %f, Z: %f, O: 1.904451", x, y, z))
end

-- Le dernier envoi d'un sujet, et son canal.
local function DernierEnvoi(sujet, depuis)
    for i = #__envois, (depuis or 0) + 1, -1 do
        local e = __envois[i]
        local _, rang, _, corps = tostring(e.message or ""):match("^(%d+):(%d+):(%d+):(.*)$")
        if corps and rang == "1" and corps:sub(1, #sujet + 1) == sujet .. "|" then return e end
    end
end

dire("== le canal : rejoint a la connexion, et muet")
attendu("le canal a un nom a nous", LCM.Presence.CANAL, "LesContesMalveillants")
attendu("il est rejoint", LCM.Presence.Canal() ~= nil, true)
-- Il est retire des fenetres de discussion : un message d'addon ne s'y
-- afficherait pas, mais le canal n'a pas non plus a encombrer la liste.
attendu("et retire des fenetres", __canauxCaches[LCM.Presence.CANAL], true)
attendu("rien n'est dit dans le chat du jeu", #__chats, 0)

dire("== TOUT SEUL, sans groupe : un coffre pose part quand meme")
-- C'est la moitie qui manquait a l'envoi. Sans groupe, Combat.CanalGroupe()
-- rend nil : l'ancien code ne diffusait rien du tout.
__groupe({})
attendu("aucun canal de groupe", LCM.Combat.CanalGroupe(), nil)
attendu("mais un canal pour tous", R.Diffusable(), R.TOUS)
__position(100, 200, 0)
GPS(100, 200, 0)
local avant = #__envois
local coffreId = LCM.CoffresMJ.Placer("coffre_canal")
attendu("le coffre est pose", coffreId ~= nil, true)
local envoi = DernierEnvoi(C.SUJETS.definition, avant)
attendu("  et sa definition est partie", envoi ~= nil, true)
attendu("  sur le canal de l'addon", envoi and envoi.canal, "CHANNEL")
attendu("  a son index", envoi and envoi.cible, LCM.Presence.Canal())

dire("== un point de recolte et un etal font de meme")
avant = #__envois
attendu("un filon pose", LCM.Recoltes.Placer("filon_canal") ~= nil, true)
attendu("  diffuse sur le canal", (DernierEnvoi(LCM.Recolte.SUJETS.definition, avant) or {}).canal, "CHANNEL")
avant = #__envois
attendu("un etal pose", LCM.MarchandsMJ.Placer("etal_canal") ~= nil, true)
attendu("  diffuse sur le canal", (DernierEnvoi(LCM.Marchands.SUJETS.definition, avant) or {}).canal, "CHANNEL")

dire("== une modification de contenu part aussi sur le canal")
-- Prendre dans un coffre, acheter chez un vendeur, recolter : l'etat
-- autoritaire repart a tous.
avant = #__envois
C.courant = coffreId
LCM.CoffresMJ.Traiter(MOI, { i = coffreId, a = "ouvrir" })
attendu("l'etat du coffre est diffuse", (DernierEnvoi(C.SUJETS.etat, avant) or {}).canal, "CHANNEL")

dire("== et rien de tout cela ne se voit dans le chat")
attendu("toujours rien dans le chat du jeu", #__chats, 0)

dire("== la RECEPTION accepte ce qui vient du canal, hors groupe")
-- La seconde moitie. On rejoue l'arrivee d'un coffre pose par un autre MJ, sur
-- le canal, alors qu'on n'est dans aucun groupe avec lui.
local paquet = C.Paquet(LCM.Points.Get("coffre_canal"), LCM.CoffresMJ.Points("coffre_canal"))
local charge = "1:1:1:" .. C.SUJETS.definition .. "|" .. R.Encoder(paquet)
C.definitions.coffre_canal = nil
for id in pairs(C.points) do C.points[id] = nil end
attendu("on ne connait plus ce coffre", C.definitions.coffre_canal, nil)
attendu("l'autre MJ n'est pas dans mon groupe", R.DansLeGroupe("Syn-Apertus"), false)
R.Recevoir("Syn-Apertus", charge, "CHANNEL")
attendu("venu du canal : accepte", C.definitions.coffre_canal ~= nil, true)
attendu("  avec son auteur", (C.definitions.coffre_canal or {}).auteur, "Syn-Apertus")

dire("== mais pas n'importe qui, par n'importe quel chemin")
C.definitions.coffre_canal = nil
-- Un chuchotement d'un inconnu qu'on n'a jamais vu : refuse, comme avant.
R.Recevoir("Inconnu-Apertus", charge, "WHISPER")
attendu("un inconnu en prive : refuse", C.definitions.coffre_canal, nil)
-- Mais quelqu'un dont la presence est confirmee, si : sa reponse en prive n'a
-- pas d'autre marque que son nom.
LCM.Reseau.Recevoir("Connu-Apertus", "1:1:1:ici|v=0.2.0", "CHANNEL")
attendu("sa presence est notee", LCM.Presence.Confirmee("Connu-Apertus"), true)
R.Recevoir("Connu-Apertus", charge, "WHISPER")
attendu("en prive, lui : accepte", C.definitions.coffre_canal ~= nil, true)

dire("== « coucou, je suis la » : la demande part sur le canal")
-- Un joueur qui arrive demande ses coffres a la ronde ; les MJ repondent en
-- prive. La demande partait sur le canal du groupe : sans groupe, nulle part.
LCM.BasculerModeJoueur(true)
avant = #__envois
C.Demander()
local demande = DernierEnvoi(C.SUJETS.demande, avant)
attendu("la demande est partie", demande ~= nil, true)
attendu("  sur le canal", demande and demande.canal, "CHANNEL")
LCM.BasculerModeJoueur(false)

dire("== et le MJ repond a qui n'est pas dans son groupe")
avant = #__envois
R.Recevoir("Bily-Apertus", "1:1:1:" .. C.SUJETS.demande .. "|", "CHANNEL")
local reponse = DernierEnvoi(C.SUJETS.definition, avant)
attendu("il renvoie ses coffres", reponse ~= nil, true)
attendu("  en prive, a lui", reponse and reponse.canal, "WHISPER")
attendu("  nommement", reponse and reponse.cible, "Bily-Apertus")

dire("== le canal arrive apres la connexion : on redemande")
-- Dans le jeu, le canal n'existe pas encore a la connexion : la demande
-- partait dans le vide, et il fallait entrer dans le raid (ou recharger).
local rappels = 0
LCM.Presence.QuandCanal(function() rappels = rappels + 1 end)
attendu("un inscrit au canal deja la est appele tout de suite", rappels, 1)
LCM.Presence.Pret()
attendu("et rappele quand le canal repond", rappels, 2)

dire("== le repli : sans canal, le groupe")
local vraiCanal = LCM.Presence.Canal
LCM.Presence.Canal = function() return nil end
__groupe({ MOI, "Bily-Apertus" })
attendu("le groupe prend le relais", select(1, R.CanalTous()), "PARTY")
avant = #__envois
LCM.CoffresMJ.Renvoyer()
attendu("  et le renvoi l'emprunte", (DernierEnvoi(C.SUJETS.definition, avant) or {}).canal, "PARTY")
__groupe({})
attendu("ni canal ni groupe : rien a diffuser", R.Diffusable(), nil)
attendu("  et l'envoi le dit", (LCM.Reseau.Envoyer("cof", {}, R.TOUS)), false)
LCM.Presence.Canal = vraiCanal

dire("== le bouton du MJ : forcer l'envoi")
local f = LCM.UI.CoffresMJ.Fenetre()
f:Onglet("placement")
attendu("le bouton est la", f.placement.renvoyer ~= nil, true)
avant = #__envois
f.placement.renvoyer:Click()
attendu("  il renvoie tout", (DernierEnvoi(C.SUJETS.definition, avant) or {}).canal, "CHANNEL")
local g = LCM.UI.Recoltes.Fenetre()
g:Onglet("placement")
attendu("les récoltes l'ont aussi", g.placement.renvoyer ~= nil, true)
local h = LCM.UI.MarchandsMJ.Fenetre()
h:Onglet("placement")
attendu("les vendeurs aussi", h.placement.renvoyer ~= nil, true)

dire("== rien de tout cela n'a parle dans le chat")
attendu("le chat du jeu est reste muet", #__chats, 0)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
