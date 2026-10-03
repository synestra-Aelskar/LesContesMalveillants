-- Ou partent les resultats de jets.
--
-- Un jet qu'on est seul a voir ne sert qu'a soi ; un jet envoye au mauvais
-- canal se perd, ou derange. Le choix se fait une fois, en haut de la fiche
-- (comme dans le template, « Canal : Raid »), et il est retenu.
--
-- « Local » n'envoie rien : le resultat reste dans sa propre fenetre de chat.
-- C'est le defaut, parce qu'un addon ne doit pas se mettre a parler a la place
-- du joueur sans qu'il l'ait demande.

local _, LCM = ...

local Canal = {}
LCM.Canal = Canal

-- L'ordre est celui du menu. `type` est ce que SendChatMessage attend ; nil
-- pour « Local ».
-- Quatre, et pas davantage : ce sont ceux ou l'on joue. Un canal retire d'ici
-- et retrouve dans une vieille sauvegarde retombe sur Local — `Get` rend le
-- premier quand il ne connait pas.
-- `lettre` et `couleur` : la pastille de la fiche. Une lettre et une teinte
-- suffisent a dire ou part un jet, et tiennent dans un coin — un bouton large
-- avec « Raid » ecrit dedans prenait la moitie de l'en-tete pour une chose
-- qu'on regle une fois par seance.
Canal.LISTE = {
    { id = "local", label = "Local",  lettre = "L", couleur = { 1.00, 1.00, 1.00 } },
    { id = "emote", label = "Emote",  type = "EMOTE", lettre = "E", couleur = { 0.98, 0.86, 0.30 } },
    { id = "party", label = "Groupe", type = "PARTY", lettre = "G", couleur = { 0.38, 0.62, 0.98 } },
    { id = "raid",  label = "Raid",   type = "RAID",  lettre = "R", couleur = { 0.98, 0.60, 0.20 } },
}

function Canal.Get(id)
    for _, canal in ipairs(Canal.LISTE) do
        if canal.id == tostring(id or "") then return canal end
    end
    return Canal.LISTE[1]
end

function Canal.Actuel()
    LCM.EnsureDatabase()
    return Canal.Get(LCM.db.settings and LCM.db.settings.canalJets)
end

function Canal.Choisir(id)
    local canal = Canal.Get(id)
    LCM.EnsureDatabase()
    LCM.db.settings.canalJets = (canal.id ~= "local") and canal.id or nil
    if Canal.onChange then Canal.onChange(canal) end
    return canal
end

-- Peut-on vraiment parler la ? Un canal de groupe sans groupe avale le message
-- sans rien dire ; on prefere le signaler et parler pour soi.
function Canal.Disponible(canal)
    local type_ = canal and canal.type
    if not type_ then return true end
    if type_ == "PARTY" or type_ == "RAID" then
        return (GetNumGroupMembers and (GetNumGroupMembers() or 0) > 0) or false
    end
    return true
end

-- Envoie une ligne la ou il faut. Retourne le canal effectivement utilise.
function Canal.Dire(texte)
    local canal = Canal.Actuel()
    if not canal.type then
        LCM.Info(texte)
        return canal
    end
    if not Canal.Disponible(canal) then
        LCM.Alerte(string.format("pas de %s : le jet reste pour toi.", canal.label:lower()))
        LCM.Info(texte)
        return Canal.LISTE[1]
    end
    if SendChatMessage then
        -- Sans couleur : le chat du jeu n'en veut pas dans un message envoye.
        SendChatMessage(LCM.SansCouleur(texte), canal.type)
    end
    return canal
end

function LCM.SansCouleur(texte)
    return (tostring(texte or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end
