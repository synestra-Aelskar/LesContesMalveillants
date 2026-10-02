-- Les etats temporaires : ce qu'une action pose sur une fiche pour quelques
-- rounds — Immobilise, Entrave, En levitation.
--
-- A ne pas confondre avec les Etats du catalogue (Core/Etats.lua), que le MJ
-- donne et retire a la main : ceux-ci viennent d'une resolution d'action
-- (pas « effect » de Necronicon), portent leur propre effet chiffre et
-- s'eteignent seuls. Repris des « etats ephemeres » de Necronicon
-- (BuildEphemeralStateFromTemplate, PlaceEphemeralStateOnFiche), sans les
-- cumuls ni la guerison par jet, que les controles du template n'utilisent
-- pas.
--
-- Ils vivent SUR l'entite qui les subit (sa fiche, ou l'instance du PNJ) :
-- c'est une donnee de partie, comme une blessure. Une source d'effets
-- (Core/Effets.lua) les ajoute aux bonus : la fiche et les jets les voient
-- sans savoir d'ou ils viennent.
--
-- La duree se compte en rounds du combat (Core/Combat.lua) : un etat pose a
-- 3 rounds s'eteint au troisieme round suivant. Hors combat, il dure jusqu'a
-- ce qu'on le retire.

local _, LCM = ...

local Temporaires = {}
LCM.EtatsTemporaires = Temporaires

local VIDE = {}

-- Lecture : ne cree rien.
function Temporaires.Liste(entity)
    return type(entity) == "table" and type(entity.etatsTemporaires) == "table" and entity.etatsTemporaires or VIDE
end

local function PourEcrire(entity)
    entity.etatsTemporaires = type(entity.etatsTemporaires) == "table" and entity.etatsTemporaires or {}
    return entity.etatsTemporaires
end

-- Une liste redevenue vide disparait de la sauvegarde.
local function Ranger(entity)
    if type(entity.etatsTemporaires) == "table" and #entity.etatsTemporaires == 0 then
        entity.etatsTemporaires = nil
    end
end

-- etat = { nom, icone, description, bonus = { [champ] = n }, rounds (nil :
-- jusqu'a ce qu'on le retire), lanceur, debuff, dissipation }
function Temporaires.Poser(entity, etat)
    local liste = PourEcrire(entity)
    -- Le meme etat repose (meme nom) remplace l'ancien : on ne s'immobilise
    -- pas deux fois, on prolonge.
    for i = #liste, 1, -1 do
        if liste[i].nom == etat.nom then table.remove(liste, i) end
    end
    liste[#liste + 1] = {
        nom = tostring(etat.nom or "État"), icone = etat.icone, description = etat.description,
        bonus = etat.bonus or {}, restant = etat.rounds, lanceur = etat.lanceur,
        debuff = etat.debuff == true, dissipation = etat.dissipation, cumul = etat.cumul,
        -- Ce que la dissipation doit battre : le jet du lanceur, et sa
        -- competence (la meme est « adaptee », l'autre « inadaptee »).
        id = etat.id, jet = etat.jet,
    }
    if Temporaires.onChange then Temporaires.onChange(entity) end
    return liste[#liste]
end

-- Retire par nom, ou par identifiant (celui que la dissipation designe).
function Temporaires.Retirer(entity, nom)
    local liste = Temporaires.Liste(entity)
    local retire = false
    for i = #liste, 1, -1 do
        if liste[i].nom == nom or (liste[i].id ~= nil and liste[i].id == nom) then
            table.remove(liste, i)
            retire = true
        end
    end
    if retire then
        Ranger(entity)
        if Temporaires.onChange then Temporaires.onChange(entity) end
    end
    return retire
end

-- Un cumul (« stack ») draine, a chaque round, pct % du maximum de sa jauge
-- par cumul : une zone du corps (« Torse »), la Fatigue ou les Boucliers.
local function Drainer(entity, cumul)
    local Cle = LCM.Actions and LCM.Actions.Cle or function(x) return tostring(x):lower() end
    local voulu = Cle(cumul.jauge)
    local function Part(max) return math.ceil(max * (cumul.pct or 5) / 100 * (cumul.n or 1) - 1e-9) end
    if voulu == "fatigue" or voulu:find("^bouclier") then
        local champ = voulu == "fatigue" and "fatigue" or "armure"
        local j = LCM.Entities.Gauge(entity, champ)
        local n = Part(j.max)
        LCM.Entities.SetGauge(entity, champ, j.current - n)
        return n, champ == "fatigue" and "Fatigue" or "Boucliers"
    end
    for _, z in ipairs(LCM.Body.State(entity, LCM.Body.MaxTotal(entity))) do
        if Cle(z.label) == voulu or Cle(z.label):find(voulu, 1, true) then
            local n = Part(z.max)
            LCM.Body.Damage(entity, z.id, n)
            return n, z.label
        end
    end
end

-- Un round passe : chaque etat compte, ceux qui arrivent a zero s'eteignent ;
-- un cumul draine sa jauge d'abord. Retourne les noms eteints.
function Temporaires.Round(entity)
    local liste = Temporaires.Liste(entity)
    local eteints = {}
    for _, e in ipairs(liste) do
        if type(e.cumul) == "table" then
            local n, ou = Drainer(entity, e.cumul)
            if n and n > 0 then
                LCM.Info(string.format("%s : « %s » draine %d (%s).", tostring(entity.name or "?"), e.nom, n, ou))
            end
        end
    end
    for i = #liste, 1, -1 do
        local e = liste[i]
        if e.restant then
            e.restant = e.restant - 1
            if e.restant <= 0 then
                eteints[#eteints + 1] = e.nom
                table.remove(liste, i)
            end
        end
    end
    if #eteints > 0 then
        Ranger(entity)
        if Temporaires.onChange then Temporaires.onChange(entity) end
    end
    return eteints
end

function Temporaires.Duree(etat)
    if not etat.restant then return "jusqu'à retrait" end
    return string.format("%d round%s", etat.restant, etat.restant > 1 and "s" or "")
end

-- Une source d'effets comme les traits : ses elements ont un libelle, des
-- bonus et pas d'avantage.
LCM.Effets.Source("état temporaire", function(entity)
    local out = {}
    for _, e in ipairs(Temporaires.Liste(entity)) do
        out[#out + 1] = { label = e.nom, bonus = e.bonus or {}, avantage = VIDE }
    end
    return out
end)

-- Les rounds du combat font vieillir les etats de qui s'y trouve ici : soi,
-- et, chez le MJ, les PNJ en jeu. « Soi », c'est le personnage du joueur, pas
-- Entities.Self() : pendant le tour d'un PNJ, le MJ l'incarne, et Self() est
-- alors le PNJ — son propre personnage serait oublie.
local function Vieillir()
    local touches = { LCM.Entities.Self() }
    local actif = LCM.Personnages and LCM.Personnages.Actif and LCM.Personnages.Actif()
    touches[#touches + 1] = actif or LCM.Entities.Get(LCM.PlayerId())
    if LCM.IsMaster() then
        for _, instance in ipairs(LCM.Incarnation.Liste()) do touches[#touches + 1] = instance end
    end
    local vus = {}
    for _, entity in ipairs(touches) do
        if entity and not vus[entity] then
            vus[entity] = true
            for _, nom in ipairs(Temporaires.Round(entity)) do
                LCM.Info(string.format("%s : « %s » prend fin.", tostring(entity.name or "?"), nom))
            end
        end
    end
end
Temporaires.Vieillir = Vieillir

LCM.AddCommand("etats", "les états temporaires : la liste, ou « retirer <nom> »", function(argument)
    local mot, reste = tostring(argument or ""):match("^%s*(%S*)%s*(.-)%s*$")
    local moi = LCM.Entities.Self()
    if mot == "retirer" and reste ~= "" then
        if Temporaires.Retirer(moi, reste) then LCM.Ok(string.format("« %s » retiré.", reste))
        else LCM.Alerte(string.format("aucun état temporaire « %s ».", reste)) end
        return
    end
    local liste = Temporaires.Liste(moi)
    if #liste == 0 then LCM.Info("aucun état temporaire.") return end
    for _, e in ipairs(liste) do
        local effets = {}
        for champ, n in pairs(e.bonus or {}) do
            local field = LCM.Schema.Field(champ)
            effets[#effets + 1] = string.format("%s %+d", field and field.label or champ, n)
        end
        table.sort(effets)
        LCM.Info(string.format("%s (%s)%s", e.nom, Temporaires.Duree(e),
            #effets > 0 and (" — " .. table.concat(effets, ", ")) or ""))
    end
end)
