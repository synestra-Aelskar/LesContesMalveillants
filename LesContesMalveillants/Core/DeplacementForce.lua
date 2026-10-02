-- Le deplacement force : une Repulsion, une Attraction, une intervention
-- « avec deplacement ».
--
-- Quelqu'un te pousse de six metres. Personne ne compte six metres a l'oeil, et
-- la bonne foi n'a rien a voir la-dedans : sans mesure, chacun s'arrete ou il
-- croit etre arrive. L'addon mesure a ta place et dit quand c'est fait.
--
-- Repris de Necronicon (`Deplacement.lua`, `StartForcedDeplacement` et
-- `_DeplacementTick`), mecanique comprise :
--
--   * la distance est celle qui te separe de ton POINT DE DEPART, a vol
--     d'oiseau — jamais le chemin parcouru. Tourner en rond n'avance a rien,
--     c'est tout l'interet d'une poussee ;
--   * le relief ne compte pas : une variation verticale de moins d'une unite
--     (une marche, un saut sur place) est ignoree ;
--   * `unitesParMetre` convertit les unites de `UnitPosition` en metres de la
--     fiche. A 1 chez nous, comme chez Necronicon.
--
-- Ce qu'on ne reprend PAS : Necronicon finit par des commandes serveur
-- (`.mod speed`, `.aura`) pour clouer le personnage sur place. Ca tient a leur
-- serveur et a leurs droits ; ici on annonce la fin, et le joueur s'arrete.
--
-- `LCM.Deplacement` est la FONCTION de calcul des deplacements (Data/Fiche.lua).
-- Ce module s'appelle `LCM.DeplacementForce` : les deux noms se ressemblent, ils
-- n'ont rien a voir.

local _, LCM = ...

local DeplacementForce = {}
LCM.DeplacementForce = DeplacementForce

-- Un echantillon tous les dixiemes de seconde (Necronicon : sampleInterval).
local INTERVALLE = 0.1
local UNITES_PAR_METRE = 1
-- En dessous, une variation verticale est du relief, pas un deplacement.
local RELIEF_IGNORE = 1

-- L'etat vit en memoire vive : un deplacement force ne survit pas a un
-- /reload, et c'est tant mieux — on ne reprend pas une poussee a froid.
local course = nil

local function Position()
    if type(UnitPosition) ~= "function" then return nil end
    local ok, x, y, z = pcall(UnitPosition, "player")
    if not ok or type(x) ~= "number" or type(y) ~= "number" then return nil end
    return x, y, tonumber(z) or 0
end

-- Le cadre qui bat la mesure. OnUpdate plutot que C_Timer : il existe toujours,
-- et le banc sait le faire avancer.
local horloge
local function Horloge()
    if horloge then return horloge end
    horloge = CreateFrame("Frame", nil, UIParent)
    horloge:Hide()
    horloge.reste = 0
    horloge:SetScript("OnUpdate", function(self, ecoule)
        if not course then self:Hide() return end
        self.reste = self.reste + (ecoule or 0)
        if self.reste < INTERVALLE then return end
        self.reste = 0
        DeplacementForce.Mesurer()
    end)
    return horloge
end

function DeplacementForce.EnCours()
    return course
end

-- La distance franchie, et celle qu'il reste. Toujours des nombres : une
-- fenetre qui affiche « nil / 6 m » n'aide personne.
function DeplacementForce.Etat()
    if not course then return 0, 0, false end
    return course.distance, course.limite, true
end

function DeplacementForce.Mesurer()
    if not course then return end
    local x, y, z = Position()
    if not x then return end
    local dx, dy, dz = x - course.x0, y - course.y0, z - course.z0
    if math.abs(dz) < RELIEF_IGNORE then dz = 0 end
    course.distance = math.sqrt(dx * dx + dy * dy + dz * dz) / UNITES_PAR_METRE
    if course.distance >= course.limite then
        DeplacementForce.Arreter("fini")
        return
    end
    if DeplacementForce.onChange then DeplacementForce.onChange() end
end

-- `metres` : ce qu'il faut franchir. `raison` : ce qui te pousse, pour l'ecrire.
function DeplacementForce.Demarrer(metres, raison)
    metres = tonumber(metres) or 0
    if metres <= 0 then return false, "distance nulle." end
    local x, y, z = Position()
    if not x then return false, "position indisponible (UnitPosition)." end
    -- Une poussee en remplace une autre : on ne cumule pas deux dettes de
    -- metres, la seconde est celle qui compte.
    course = {
        limite = metres, distance = 0, raison = tostring(raison or "Déplacement forcé"),
        x0 = x, y0 = y, z0 = z, debut = (GetTime and GetTime()) or 0,
    }
    Horloge():Show()
    LCM.Alerte(string.format("%s : éloigne-toi de %s m de ton point de départ.",
        course.raison, tostring(metres)))
    if DeplacementForce.onDemarrage then DeplacementForce.onDemarrage(course) end
    if DeplacementForce.onChange then DeplacementForce.onChange() end
    return true
end

-- `cause` : « fini » (distance atteinte) ou « interrompu » (fenetre fermee).
function DeplacementForce.Arreter(cause)
    if not course then return false end
    local fini = cause ~= "interrompu"
    local termine = course
    course = nil
    if horloge then horloge:Hide() end
    if fini then
        LCM.Ok(string.format("%s : %.1f m parcourus, c'est fait.", termine.raison, termine.limite))
    else
        LCM.Alerte(string.format("%s interrompu : %.1f / %.1f m.",
            termine.raison, termine.distance, termine.limite))
    end
    if DeplacementForce.onFin then DeplacementForce.onFin(termine, fini) end
    if DeplacementForce.onChange then DeplacementForce.onChange() end
    return true
end
