-- Vues : les fenetres du menu qui montrent un morceau de la fiche.
--
-- Une vue ne declare AUCUN champ : elle designe des parties du schema (un
-- onglet, une section, une liste de champs) et la fenetre les dessine avec les
-- lignes de la fiche. Ajouter une fenetre « Sante » ou « Expertise », c'est
-- donc ecrire trois lignes dans Data/Vues.lua, pas un ecran.
--
-- L'identifiant d'une vue est celui de l'entree du menu radial qu'elle habille.
--
--   Vues.Add({ id = "sante", titre = "Santé", blocs = {
--       { section = { "general", "Vitalite" } },    -- une section d'onglet
--       { onglet = "expertises" },                  -- toutes ses sections
--       { label = "Divers", champs = { "age", "poids" } },
--   } })

local _, LCM = ...

local Vues = { list = {}, byId = {} }
LCM.Vues = Vues

local function Erreur(message)
    error("LCM/Vues : " .. tostring(message), 0)
end

local function Onglet(id)
    for _, tab in ipairs(LCM.Schema.Tabs()) do
        if tab.id == id then return tab end
    end
end

-- Un bloc -> des sections { label, fields }, celles que la fiche sait dessiner.
-- Resolu a la declaration : Data/Vues.lua se charge apres toute la feuille, et
-- une reference fausse doit casser au chargement, pas au premier clic.
local function Resoudre(vueId, bloc, sections)
    if type(bloc) ~= "table" then Erreur(vueId .. " : bloc invalide") end

    if bloc.onglet then
        local tab = Onglet(bloc.onglet)
        if not tab then Erreur(vueId .. " : onglet inconnu « " .. tostring(bloc.onglet) .. " »") end
        for _, section in ipairs(tab.sections) do sections[#sections + 1] = section end

    elseif bloc.section then
        local tabId, label = bloc.section[1], bloc.section[2]
        local tab = Onglet(tabId)
        if not tab then Erreur(vueId .. " : onglet inconnu « " .. tostring(tabId) .. " »") end
        local trouvee
        for _, section in ipairs(tab.sections) do
            if section.label == label then trouvee = section end
        end
        if not trouvee then
            Erreur(string.format("%s : section « %s » absente de l'onglet %s", vueId, tostring(label), tabId))
        end
        sections[#sections + 1] = trouvee

    elseif bloc.champs then
        local fields = {}
        for _, fieldId in ipairs(bloc.champs) do
            local field = LCM.Schema.Field(fieldId)
            if not field then Erreur(vueId .. " : champ inconnu « " .. tostring(fieldId) .. " »") end
            fields[#fields + 1] = field
        end
        sections[#sections + 1] = { label = tostring(bloc.label or ""), fields = fields }

    else
        Erreur(vueId .. " : un bloc designe un onglet, une section ou des champs")
    end
end

function Vues.Add(definition)
    if type(definition) ~= "table" then Erreur("vue invalide") end
    local id = tostring(definition.id or "")
    if id == "" then Erreur("vue sans identifiant") end
    if Vues.byId[id] then Erreur("vue en double : " .. id) end

    local vue = {
        id = id,
        titre = tostring(definition.titre or id),
        largeur = tonumber(definition.largeur) or 460,
        hauteur = tonumber(definition.hauteur) or 520,
        sections = {},
    }
    for _, bloc in ipairs(definition.blocs or {}) do Resoudre(id, bloc, vue.sections) end
    if #vue.sections == 0 then Erreur(id .. " : vue vide") end

    Vues.byId[id] = vue
    Vues.list[#Vues.list + 1] = vue
    return vue
end

function Vues.Get(id)
    return Vues.byId[tostring(id or "")]
end
