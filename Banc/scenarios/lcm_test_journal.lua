-- Journal local : pas de message reseau ni de repli dans le General.
local noms, lignes, ouvertures, nettoyages = {}, {}, 0, 0
local combat, indisponible, selection = false, false, nil
NUM_CHAT_WINDOWS = 10
function GetChatWindowInfo(i) return noms[i] end
function InCombatLockdown() return combat end
function FCF_OpenNewWindow(nom)
    ouvertures = ouvertures + 1
    if indisponible then return nil end
    local frame = CreateFrame("Frame")
    frame.AddMessage = function(_, ligne) lignes[#lignes+1] = ligne end
    ChatFrame7, noms[7] = frame, nom
    return frame
end
function ChatFrame_RemoveAllMessageGroups() nettoyages=nettoyages+1 end
function ChatFrame_RemoveAllChannels() nettoyages=nettoyages+1 end
function FCF_SelectDockFrame(frame) selection=frame end
local ancien = DEFAULT_CHAT_FRAME
SELECTED_CHAT_FRAME = ancien
LCM.Journal("avant connexion")
assert(ouvertures==0)
__declencher("PLAYER_LOGIN")
assert(ouvertures==1 and #lignes==1 and nettoyages==2)
assert(selection==ancien and noms[7]=="LesContesMalveillants")
local general=0
DEFAULT_CHAT_FRAME={AddMessage=function() general=general+1 end}
LCM.Journal("reprise de garde")
assert(ouvertures==1 and #lignes==2 and general==0)
LCM.Info("information normale")
LCM.Erreur("erreur normale")
assert(general==2)
__declencher("PLAYER_LOGIN")
LCM.Journal("onglet existant")
assert(ouvertures==1 and nettoyages==2)
ChatFrame7=nil; noms[7]=nil; combat=true
LCM.Journal("en combat")
assert(#lignes==3 and general==2 and ouvertures==1)
combat=false
__declencher("PLAYER_REGEN_ENABLED")
assert(#lignes==4 and ouvertures==2)
ChatFrame7=nil; noms[7]=nil; indisponible=true
LCM.Journal("plus de place")
assert(#lignes==4 and general==2)
indisponible=false
__declencher("PLAYER_REGEN_ENABLED")
assert(#lignes==5 and general==2)
DEFAULT_CHAT_FRAME=ancien
print("TOUT PASSE — journal local, reuse, combat et saturation")
