-- Les points interactifs doivent distinguer deux etages superposes.
local ko = 0
local function attendu(nom, valeur, attendu)
    if valeur ~= attendu then ko = ko + 1 end
    print((valeur == attendu and "  ok  " or "  KO  ") .. nom .. " = " .. tostring(valeur))
end

__declencher("PLAYER_LOGIN")
__personnage()
__position(100, 200, 150)
LCM.DeplacementForce.NoterGPS("100.000000 200.000000 150.000000 1 0.000000")
local R, M, C = LCM.Recolte, LCM.Marchands, LCM.Coffres
local carte = R.Carte()
local defR = { id = "ressource_3d", rayon = 4, limite = 0,
    ressources = { { entree = "ressources/eau", min = 1, max = 1 } } }
R.definitions.ressource_3d = defR
R.points.r3d = { id = "r3d", def = "ressource_3d", x = 100, y = 200,
    z = 0, source = "monde", carte = carte }
M.definitions.m3d = { id = "m3d" }
M.points.m3d = { id = "m3d", def = "m3d", x = 100, y = 200,
    z = 0, source = "monde", carte = carte }
C.definitions.c3d = { id = "c3d", coffre = { rayon = 4 } }
C.points.c3d = { id = "c3d", def = "c3d", x = 100, y = 200,
    z = 0, source = "monde", carte = carte }

attendu("ressource à 150 yards au-dessus masquée", R.Proche(), nil)
attendu("vendeur à 150 yards au-dessus masqué", M.Proche(), nil)
attendu("coffre à 150 yards au-dessus masqué", C.Proche(), nil)
__position(100, 200, 2)
LCM.DeplacementForce.NoterGPS("100.000000 200.000000 2.000000 1 0.000000")
attendu("ressource au bon étage visible", R.Proche().id, "r3d")
attendu("vendeur au bon étage visible", M.Proche().id, "m3d")
attendu("coffre au bon étage visible", C.Proche().id, "c3d")

R.points.rgps = { id = "rgps", def = "ressource_3d", x = 100, y = 200,
    z = 0, source = "gps", carte = carte }
M.points.mgps = { id = "mgps", def = "m3d", x = 100, y = 200,
    z = 0, source = "gps", carte = carte }
__avancerTemps(2)
local commandesAvant = #__chats
for _ = 1, 6 do R.Tick(); M.Tick() end
attendu("ressources et vendeurs GPS n'envoient rien en arrière-plan", #__chats, commandesAvant)

local positions = R.Deplier(R.Plier({ R.points.r3d }))
attendu("altitude conservée dans le paquet", positions[1].z, 0)
local ancien = R.Deplier("ancien,100.00,200.00,monde," .. tostring(carte))
attendu("ancien paquet encore lisible", ancien[1].id, "ancien")
attendu("ancien point sans altitude non interactif",
    R.Distance(ancien[1], { x = 100, y = 200, z = 2 }), nil)

if ko == 0 then print("TOUT PASSE") else print(ko .. " ECHEC(S)") end
