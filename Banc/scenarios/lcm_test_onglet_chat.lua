-- Les notifications techniques de synchronisation vont dans l'onglet de
-- l'addon, sans polluer General ni le journal persistant des incidents.
local function attendu(ok, texte)
    if not ok then error(texte) end
    print("  ok  " .. texte)
end

local onglet = { lignes = {} }
function onglet:AddMessage(texte) self.lignes[#self.lignes + 1] = texte end
ChatFrame2 = onglet
NUM_CHAT_WINDOWS = 2
GetChatWindowInfo = function(i)
    return i == 2 and "LesContesMalveillants" or "General"
end

__declencher("PLAYER_LOGIN")
__personnage()
local general = #__sorties
local persistant = #LCM.LignesJournal()
local deja = #onglet.lignes
LCM.Onglet("un transfert technique", "ok")
attendu(#__sorties == general, "aucune notification technique dans General")
attendu(#onglet.lignes == deja + 1
    and __sansCouleur(onglet.lignes[#onglet.lignes]):find("transfert technique", 1, true),
    "la notification apparaît dans l'onglet de l'addon")
attendu(#LCM.LignesJournal() == persistant, "elle n'encombre pas le journal persistant")

-- La réception réelle d'un réglage emprunte le même chemin.
__groupe({ "Nytherah-Apertus" })
local avant = #onglet.lignes
local generalAvant = #__sorties
LCM.Reseau.Recevoir("Nytherah-Apertus", "931:1:1:regl|c=pa.base;v=12", "PARTY")
attendu(#onglet.lignes == avant + 1
    and __sansCouleur(onglet.lignes[#onglet.lignes]):find("règle l'équilibrage", 1, true),
    "la réception d'un réglage est annoncée dans l'onglet")
attendu(#__sorties == generalAvant, "le réglage ne s'affiche pas dans General")

print("TOUT PASSE")
