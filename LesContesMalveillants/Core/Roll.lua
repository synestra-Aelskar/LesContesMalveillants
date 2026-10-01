-- Jets.
--
-- Un jet = des + valeur investie + apport des primaires (Core/Formules.lua)
-- + bonus portes (traits, objets) + modificateur ponctuel. Avec avantage, on lance DEUX FOIS et l'on garde le meilleur : c'est
-- le joueur qui coche la case, car lui seul sait si la situation correspond a
-- son trait ou a son objet.
--
-- Le resultat est detaille (les deux jets, ce qui a ete garde, d'ou vient
-- chaque point) : un jet qu'on ne peut pas expliquer est un jet qu'on conteste.

local _, LCM = ...

local Roll = {}
LCM.Roll = Roll

local function Alea(minimum, maximum)
    if maximum <= minimum then return minimum end
    return math.random(minimum, maximum)
end

-- Un jet brut, entre deux bornes : le grimoire s'en sert pour ses sorts, qui
-- portent leur propre plage et ne passent pas par un champ de la fiche.
function Roll.Des(minimum, maximum)
    minimum = math.floor(tonumber(minimum) or 0)
    maximum = math.floor(tonumber(maximum) or 0)
    if maximum < minimum then minimum, maximum = maximum, minimum end
    return Alea(minimum, maximum), minimum, maximum
end

-- options : { avantage = true, modificateur = 0 }
function Roll.Field(entity, fieldId, options)
    options = type(options) == "table" and options or {}
    local field = LCM.Schema.Field(fieldId)
    if not field then return nil, "champ inconnu" end
    if field.kind ~= "roll" then return nil, "ce champ ne se lance pas" end

    local dice = type(field.dice) == "table" and field.dice or {}
    local minimum = math.floor(tonumber(dice.min) or 0)
    local maximum = math.floor(tonumber(dice.max) or 0)
    if maximum < minimum then minimum, maximum = maximum, minimum end

    local valeur = tonumber(LCM.Entities.Get_Value(entity, fieldId)) or 0
    local apport = LCM.Formules.Apport(entity, fieldId)
    local bonus = LCM.Effets.Bonus(entity, fieldId)
    local modificateur = tonumber(options.modificateur) or 0
    local fixe = valeur + apport + bonus + modificateur

    -- L'avantage doit etre accorde par un trait ou un objet : cocher la case
    -- ne suffit pas. `trait` garde son nom, mais peut designer un objet.
    local trait, source = LCM.Effets.Avantage(entity, fieldId)
    local avantage = options.avantage == true and trait ~= nil

    local premier = Alea(minimum, maximum)
    local second = avantage and Alea(minimum, maximum) or nil
    local garde = premier
    if second and second > premier then garde = second end

    return {
        field = field,
        label = field.label,
        des = { min = minimum, max = maximum },
        jets = second and { premier, second } or { premier },
        garde = garde,
        valeur = valeur,
        apport = apport,
        bonus = bonus,
        modificateur = modificateur,
        total = garde + fixe,
        avantage = avantage,
        trait = trait,
        source = source,
        -- Vrai quand la case etait cochee mais qu'aucun trait ne l'autorisait :
        -- on le dit plutot que d'ignorer en silence.
        avantageRefuse = options.avantage == true and trait == nil,
    }
end

-- Une ligne lisible, pour le chat.
function Roll.Describe(resultat)
    if type(resultat) ~= "table" then return "" end
    local morceaux = {}
    if #resultat.jets > 1 then
        morceaux[#morceaux + 1] = string.format("des %d et %d, on garde %d",
            resultat.jets[1], resultat.jets[2], resultat.garde)
    else
        morceaux[#morceaux + 1] = string.format("de %d", resultat.garde)
    end
    if resultat.valeur ~= 0 then morceaux[#morceaux + 1] = string.format("valeur %+d", resultat.valeur) end
    if (resultat.apport or 0) ~= 0 then morceaux[#morceaux + 1] = string.format("stats %+d", resultat.apport) end
    if resultat.bonus ~= 0 then morceaux[#morceaux + 1] = string.format("bonus %+d", resultat.bonus) end
    if resultat.modificateur ~= 0 then morceaux[#morceaux + 1] = string.format("modificateur %+d", resultat.modificateur) end
    local ligne = string.format("%s : %d  (%s)", resultat.label, resultat.total, table.concat(morceaux, ", "))
    if resultat.avantage and resultat.trait then
        ligne = ligne .. "  — avantage : " .. resultat.trait.label
    end
    return ligne
end
