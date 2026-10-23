-- Ceinture porte-outils et puits de tonnerre : equipement, portee, console MJ.
local ko = 0
local function attendu(label, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    print((ok and "  ok  " or "  KO  ") .. label .. " = " .. tostring(obtenu))
end

__declencher("PLAYER_LOGIN")
__personnage()
LCM._masterCompanion = true
local moi = LCM.Entities.Self()
local O, I, P = LCM.Objets, LCM.Inventaire, LCM.PuitsTonnerre

attendu("scanner defini", O.Get("outil_scanner_valrazkah") ~= nil, true)
local ok, raison = O.Equiper(moi, "outil_scanner_valrazkah")
attendu("sans scanner dans les sacs, equipement refuse", ok, false)
attendu("portee de la ceinture", O.Capacite("outil"), 2)
attendu("scanner mis dans les sacs", (I.Deposer(moi, "objets/outil_scanner_valrazkah", 1)), true)
LCM.UI.Menu.Trouver("outils_portes").onClick()
local ceinture = LCM.UI.Ceinture.frame
attendu("la ceinture propose deux crochets", #ceinture.emplacements, 2)
ceinture.emplacements[1]:Click()
_G.LCM_Choix_ceinture_outils.lignes[1]:Click()
attendu("scanner equipe depuis la ceinture", O.Porte(moi, "outil_scanner_valrazkah"), true)
attendu("scanner parti des sacs", O.Possede(moi, "outil_scanner_valrazkah"), false)
attendu("premiere place affiche le scanner", ceinture.emplacements[1].porte.id, "outil_scanner_valrazkah")
attendu("deuxieme place libre", ceinture.emplacements[2].porte, nil)
attendu("scanner ouvert", (LCM.UI.Scanner.Basculer()), true)
local f = LCM.UI.Scanner.frame
attendu("console MJ presente", f.poser ~= nil, true)

__position(100, 200, 0)
local avant = #P.Tous()
f.poser:Click()
attendu("puits pose sur place", #P.Tous(), avant + 1)
local point = P.Tous()[#P.Tous()]
attendu("carte enregistree", point.carte, LCM.DeplacementForce.Carte())
attendu("altitude enregistree", point.z, 0)
__position(150, 200, 0)
f:Afficher()
attendu("un echo a 50 m", math.floor(f.echos[1].distance + 0.5), 50)
attendu("point place a gauche du curseur", f.echos[1].x < 0, true)
local loin = P.Echos({ x = 400, y = 200, z = 0, carte = point.carte, source = point.source }, 200)
attendu("hors portee, aucun echo", #loin, 0)
local autreCarte = P.Echos({ x = 100, y = 200, z = 0, carte = point.carte + 1, source = point.source }, 200)
attendu("autre carte, aucun echo", #autreCarte, 0)
local autreSource = P.Echos({ x = 100, y = 200, z = 0, carte = point.carte,
    source = point.source == "gps" and "monde" or "gps" }, 200)
attendu("autre repere, aucun echo", #autreSource, 0)
__position(100, 200, 0)
f.retirer:Click()
attendu("puits retire par la console", #P.Tous(), avant)

-- Le groupe recoit les positions MJ par le reseau de l'addon.
__groupe({ "Autre-Apertus" })
local distant = { id = "pt_distant", x = 108, y = 200, z = 0,
    carte = point.carte, source = point.source }
local function recevoir(sujet, donnees)
    return LCM.Reseau.Recevoir("Autre-Apertus", "1:1:1:" .. sujet .. "|"
        .. LCM.Reseau.Encoder(donnees))
end
recevoir("puits+", distant)
attendu("puits distant recu", #P.Tous(), 1)
attendu("auteur retenu", P.Tous()[1].auteur, "Autre-Apertus")
attendu("position numerique", type(P.Tous()[1].x), "number")
recevoir("puits-", { id = distant.id })
attendu("retrait distant recu", #P.Tous(), 0)
f:Hide()
attendu("scanner retire de la ceinture", (O.Desequiper(moi, "outil_scanner_valrazkah")), true)
attendu("scanner revenu dans les sacs", O.Possede(moi, "outil_scanner_valrazkah"), true)
ok = LCM.UI.Scanner.Basculer()
attendu("scanner sans equipement refuse", ok, false)

print(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
