-- Effets : ce qu'une chose portee apporte a une fiche.
--
-- Un trait, un objet equipe : deux choses differentes, un seul langage.
--   * `bonus`    : { [champ] = montant } — sur les six primaires, seulement
--                  pour un objet (voir Lire) ;
--   * `avantage` : des jets relances, dont on garde le meilleur.
--
-- Ce module tient la REGLE (ce qu'un effet a le droit de viser) et la SOMME
-- (ce que tout ce qu'on porte donne sur un champ). Les registres (Traits,
-- Objets) s'y declarent comme sources ; la fiche et les jets ne demandent
-- qu'ici, sans savoir d'ou vient un bonus.

local _, LCM = ...

local Effets = { sources = {} }
LCM.Effets = Effets

-- Les six primaires sont hors de portee : c'est une regle de jeu, donc elle
-- est verifiee par le code et pas seulement ecrite quelque part.
Effets.PRIMAIRES = {
    force = true, mystique = true, perception = true,
    adresse = true, esprit = true, constitution = true,
}

-- Lit et verifie les effets d'une definition. `Erreur` est celle du registre
-- appelant : le message garde son prefixe (« LCM/Traits : ... »).
-- `primairesPermises` : un objet peut donner de la Force (le template en a),
-- un trait jamais.
function Effets.Lire(id, definition, Erreur, primairesPermises)
    local bonus, avantage = {}, {}
    for fieldId, value in pairs(definition.bonus or {}) do
        local cible = tostring(fieldId)
        if Effets.PRIMAIRES[cible] and not primairesPermises then
            Erreur(id .. " : ne peut pas modifier une statistique primaire (" .. cible .. ")")
        end
        local montant = tonumber(value)
        if not montant or montant == 0 then
            Erreur(id .. " : bonus nul ou illisible sur " .. cible)
        end
        bonus[cible] = montant
    end
    for _, fieldId in ipairs(definition.avantage or {}) do
        avantage[tostring(fieldId)] = true
    end
    return bonus, avantage
end

-- Une source : ce qu'une entite porte de ce genre. `portes(entity)` renvoie
-- les elements (tables a `label`, `bonus`, `avantage`), `liste()` tout ce
-- qui existe (pour la verification au demarrage). L'ordre de declaration est
-- l'ordre de priorite quand deux sources accordent le meme avantage.
function Effets.Source(nom, portes, liste)
    Effets.sources[#Effets.sources + 1] = { nom = nom, portes = portes, liste = liste }
end

-- Somme de tous les bonus portes sur un champ.
function Effets.Bonus(entity, fieldId)
    local total, cible = 0, tostring(fieldId)
    for _, source in ipairs(Effets.sources) do
        for _, element in ipairs(source.portes(entity)) do
            total = total + (element.bonus[cible] or 0)
        end
    end
    return total
end

-- Ce qui accorde l'avantage sur ce jet, s'il y a quelque chose : l'element
-- (trait ou objet) et le nom de sa source.
function Effets.Avantage(entity, fieldId)
    local cible = tostring(fieldId)
    for _, source in ipairs(Effets.sources) do
        for _, element in ipairs(source.portes(entity)) do
            if element.avantage[cible] then return element, source.nom end
        end
    end
    return nil
end

-- Ce qui impose un DESAVANTAGE sur ce jet. Rien ne se declare : il se deduit
-- d'un bonus NEGATIF. Un trait qui retire des points a « Vol a la tire » gene
-- celui qui le porte des qu'il s'en sert — on ne choisit pas ses faiblesses
-- comme on choisit ses forces (regle du 5 octobre 2026).
--
-- Rend l'element fautif et le nom de sa source, comme Avantage.
function Effets.Desavantage(entity, fieldId)
    local cible = tostring(fieldId)
    for _, source in ipairs(Effets.sources) do
        for _, element in ipairs(source.portes(entity)) do
            if (element.bonus[cible] or 0) < 0 then return element, source.nom end
        end
    end
    return nil
end

-- Les champs vises n'existent pas forcement au moment ou un element est
-- declare (les fichiers se chargent dans l'ordre du .toc). On verifie donc une
-- fois, a la connexion, quand toute la feuille est connue.
LCM.WhenReady(function()
    for _, source in ipairs(Effets.sources) do
        for _, element in ipairs(source.liste and source.liste() or {}) do
            for fieldId in pairs(element.bonus) do
                if not LCM.Schema.Field(fieldId) then
                    LCM.Erreur(string.format("%s « %s » : bonus vers un champ inconnu (%s)",
                        source.nom, element.label, fieldId))
                end
            end
            for fieldId in pairs(element.avantage) do
                local field = LCM.Schema.Field(fieldId)
                if not field then
                    LCM.Erreur(string.format("%s « %s » : avantage sur un champ inconnu (%s)",
                        source.nom, element.label, fieldId))
                elseif field.kind ~= "roll" then
                    LCM.Erreur(string.format("%s « %s » : avantage sur « %s », qui ne se lance pas",
                        source.nom, element.label, fieldId))
                end
            end
        end
    end
end)
