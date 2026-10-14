-- Le combat : invitation, initiative, tours et rounds, bandeau, reseau.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end
local function aDit(motif)
    for i = #__sorties, 1, -1 do
        if __sansCouleur(__sorties[i]):find(motif, 1, true) then return true end
    end
    return false
end
-- Un message tel que le reseau le recoit d'un autre joueur, en un morceau.
local function recevoir(expediteur, sujet, donnees)
    return LCM.Reseau.Recevoir(expediteur, "1:1:1:" .. sujet .. "|" .. LCM.Reseau.Encoder(donnees))
end
local function dernierEnvoi()
    return __envois[#__envois]
end

__declencher("PLAYER_LOGIN")
__personnage()   -- ce scenario joue un personnage : il le dit
local C = LCM.Combat
local I = LCM.Incarnation
local B = LCM.UI.Combat
local moi = LCM.PlayerId()
local maFiche = LCM.Personnages.Actif() or LCM.Entities.Self()
LCM.Personnages.Choisir(maFiche.id)
LCM.Entities.Set_Value(maFiche, "sec_initiative", 2)
LCM.Entities.SetGauge(maFiche, "pa", 3, 5)
LCM.Entities.SetGauge(maFiche, "fatigue", 47, 60)

dire("== les reglages du profil")
attendu("3 rounds par tour", LCM.Equilibrage.combat.roundsParTour, 3)
attendu("annonces au raid", LCM.Equilibrage.combat.annonces, "RAID")

dire("== l'ordre : du plus haut au plus bas, a egalite par nom")
local liste = C.Trier({ { nom = "Bram", v = 5 }, { nom = "anya", v = 5 }, { nom = "Zed", v = 9 }, { nom = "Cole", v = 1 } })
attendu("ordre", liste[1].nom .. "," .. liste[2].nom .. "," .. liste[3].nom .. "," .. liste[4].nom, "Zed,anya,Bram,Cole")

dire("== le jet d'initiative est celui de la fiche")
local total, jet = C.Jet(LCM.Entities.Self())
attendu("un jet detaille", jet ~= nil, true)
attendu("des 0 a 10, plus la valeur", total >= jet.valeur and total <= jet.valeur + 10 + jet.apport + jet.bonus, true)

dire("== un joueur ne lance pas de combat")
LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = false
local fait, raison = C.Inviter({})
attendu("refuse", fait, nil)
attendu("et dit pourquoi", raison, "reserve au maitre du jeu.")
LCM._masterCompanion = true
__addonsCharges["LesContesMalveillants_MJ"] = true

dire("== le MJ seul, avec un PNJ : pas d'invitation, on lance")
__groupe({})
local garde = I.Instancier(LCM.PNJ.list[1].id, "Garde")
local etat = C.Inviter({ pnj = { garde.id } })
attendu("lance tout de suite", C.EnCours(), true)
attendu("deux combattants", #etat.entrees, 2)
attendu("le PNJ est marque", (etat.entrees[1].pnj or etat.entrees[2].pnj) == true, true)
attendu("tour 1, round 1 sur 3", etat.t .. "/" .. etat.r .. "/" .. etat.rm, "1/1/3")
attendu("je mene", C.EstMJ(), true)
attendu("rien n'est parti sur le reseau sans groupe", dernierEnvoi() == nil or not dernierEnvoi().message:find("combat="), true)
attendu("annonce locale du tour", aDit("Tour 1."), true)
attendu("annonce locale du round", aDit("Round 1/3."), true)
attendu("qui a l'initiative", aDit("a désormais l'initiative !"), true)

dire("== le bandeau")
local f = B.frame
attendu("affiche", f:IsShown(), true)
attendu("tour en deux chiffres", f.tour:GetText(), "01")
attendu("round", f.round:GetText(), "Round 1 / 3")
attendu("deux cartes", f.cartes[1]:IsShown() and f.cartes[2]:IsShown() and not f.cartes[3]:IsShown(), true)
attendu("le reste en cases vides", f.vides[3]:IsShown() and not f.vides[1]:IsShown(), true)
attendu("le premier est actif", f.cartes[1].actif:IsShown() and not f.cartes[2].actif:IsShown(), true)
attendu("pas de pages a seize ou moins", f.suivant:IsShown(), false)
attendu("a 70 %", f:GetScale(), 0.7)
attendu("decor en cinq morceaux", #f.decor, 5)
attendu("longueur PA et PF symetrique", f.ressourcesPA:GetWidth(), f.ressourcesPF:GetWidth())
attendu("la barre PF remplit symetriquement le panneau", f.ressourcesPF.barre:GetWidth(),
    f.ressourcesPF:GetWidth() - 60)
local _, taillePF = f.ressourcesPF.barre.label:GetFont()
attendu("valeur PF agrandie", taillePF, 16)
local rougePF, vertPF, bleuPF = f.ressourcesPF.barre.label:GetTextColor()
attendu("valeur PF tres claire", rougePF > 0.9 and vertPF > 0.9 and bleuPF > 0.9, true)
-- Les ressources sous le bandeau sont celles de CE QU'ON JOUE. Le garde a
-- l'initiative, le MJ l'incarne donc deja : ce sont les siennes qu'on lit.
-- Le bandeau demandait `Personnages.Actif()` avant `Self()` ; l'incarnation
-- ne passait jamais et le MJ voyait ses propres PA et PF (regression trouvee
-- et corrigee le 11 octobre 2026).
attendu("c'est le garde qui joue", I.ActuelleId(), garde.id)
LCM.Entities.SetGauge(garde, "pa", 3, 5)
LCM.Entities.SetGauge(garde, "fatigue", 47, 60)
-- Les pastilles se gardent d'une fois sur l'autre : on compte celles qui sont
-- MONTREES, pas celles qui existent.
local function pastillesVues()
    local n = 0
    for _, p in ipairs(f.ressourcesPA.pastilles) do if p:IsShown() then n = n + 1 end end
    return n
end
attendu("cinq pastilles de PA", pastillesVues(), 5)
attendu("les PA non debloques utilisent la gemme rouge et noire", f.ressourcesPA.pastilles[2].etat, "bloque")
attendu("les PA depenses utilisent la gemme noire", f.ressourcesPA.pastilles[4].etat, "depense")
attendu("PF restant / maximum", f.ressourcesPF.barre.label:GetText(), "47 / 60")

dire("== les états sous les PA suivent ce que le MJ incarne")
LCM.EtatsTemporaires.Poser(garde, { nom = "Fièvre du garde", icone = "Spell_Nature_NullifyDisease",
    description = "Une fièvre de test.", conteneur = "maladie", rounds = 2, debuff = true })
attendu("la maladie temporaire apparaît", f.ressourcesEtats:IsShown(), true)
attendu("son icône apparaît", f.ressourcesEtats.icones[1].etat.nom, "Fièvre du garde")
attendu("sa durée apparaît dans le coin", f.ressourcesEtats.icones[1].temps:GetText(), "2")
LCM.EtatsTemporaires.Poser(maFiche, { nom = "État du joueur", icone = "Spell_Holy_BlessingOfStamina",
    description = "Un état de test.", conteneur = "etat", rounds = 3 })
attendu("l'état du joueur reste caché pendant l'incarnation",
    f.ressourcesEtats.icones[1].etat.nom, "Fièvre du garde")
LCM.Entities.SetGauge(garde, "pa", 1)
LCM.Entities.SetGauge(garde, "fatigue", 28)
attendu("les PA suivent une depense", f.ressourcesPA.pastilles[2].etat, "depense")
attendu("les PF suivent une depense", f.ressourcesPF.barre.label:GetText(), "28 / 60")
-- Et surtout : ce ne sont PAS les miennes. C'est tout l'objet de la
-- correction, et une valeur distincte suffit a le prouver.
LCM.Entities.SetGauge(maFiche, "pa", 5, 5)
LCM.Entities.SetGauge(maFiche, "fatigue", 60, 60)
attendu("ma fiche ne deteint pas sur le bandeau",
    f.ressourcesPF.barre.label:GetText(), "28 / 60")

dire("== le MJ suit l'initiative : il incarne le PNJ a son tour")
local function allerA(id)
    for _ = 1, 10 do
        if C.Courant().id == id then return true end
        C.Avancer(1)
    end
    return false
end
allerA(garde.id)
attendu("le garde joue", C.Courant().id, garde.id)
attendu("le MJ l'incarne", I.ActuelleId(), garde.id)

attendu("le MJ peut passer le tour d'un PNJ", C.PeutPasser(), true)
attendu("le bouton est actif", f.passer:IsEnabled(), true)
attendu("ce n'est pas MON tour", f.avis:IsShown(), false)
allerA(moi)
attendu("a mon tour, je reprends ma place", I.ActuelleId(), "")
-- Relacher est un changement de peau, et rien d'autre n'a bouge : le bandeau
-- doit suivre tout seul (il n'ecoutait pas `EcouterSoi`).
attendu("et le bandeau me rend mes PF", f.ressourcesPF.barre.label:GetText(), "60 / 60")
attendu("et remplace les états par ceux de mon personnage",
    f.ressourcesEtats.icones[1].etat.nom, "État du joueur")
attendu("c'est mon tour", C.EstMonTour(), true)
attendu("« C'est votre tour »", f.avis:IsShown(), true)

dire("== tours et rounds")
local A = LCM.Actions
local utilisables, tranche, totalPA = C.PADisponibles(maFiche)
attendu("round 1 : tranche arrondie sur le total", tranche .. "/" .. totalPA, "2/5")
attendu("round 1 : deux PA depensables", utilisables, 2)
attendu("premier PA paye", A.Payer(maFiche, "#pa", 1), true)
attendu("un PA utilisable reste", C.PADisponibles(maFiche), 1)
attendu("second PA paye", A.Payer(maFiche, "#pa", 1), true)
attendu("le troisieme est bloque malgre les PA conserves", A.Payer(maFiche, "#pa", 1), false)
attendu("la fiche conserve trois PA", LCM.Entities.Gauge(maFiche, "pa").current, 3)
attendu("un PA rendu revient dans la fiche", A.Payer(maFiche, "#pa", -1), true)
attendu("le remboursement ne rouvre pas la tranche", C.PADisponibles(maFiche), 0)
local avant = C.Etat()
local t, r = avant.t, avant.r
-- Deux combattants : deux pas font un round.
C.Avancer(1) C.Avancer(1)
attendu("un round de plus", C.Etat().r, r + 1)
attendu("round 2 : nouvelle tranche", C.PADisponibles(maFiche), 2)
attendu("round 2 : deux PA payes", A.Payer(maFiche, "#pa", 2), true)
attendu("round 2 : reste conserve", LCM.Entities.Gauge(maFiche, "pa").current, 2)
C.Etat().r = 3
attendu("dernier round : tout le reste se debloque", C.PADisponibles(maFiche), 2)
C.Etat().c = #C.Etat().entrees
C.Avancer(1)
attendu("apres le dernier round : round 1", C.Etat().r, 1)
attendu("et tour suivant", C.Etat().t, t + 1)
attendu("le bandeau le montre", f.tour:GetText(), string.format("%02d", t + 1))
attendu("annonce du nouveau tour", aDit(string.format("Tour %d.", t + 1)), true)
C.Avancer(-1)
attendu("a rebours : round 3", C.Etat().r, 3)
attendu("du tour d'avant", C.Etat().t, t)
C.Etat().t, C.Etat().r, C.Etat().c = 1, 1, 1
C.Avancer(-1)
attendu("jamais sous le tour 1", C.Etat().t, 1)

dire("== passer par le bandeau")
allerA(moi)
local c = C.Etat().c
f.passer:Click()
attendu("le clic avance", C.Etat().c ~= c, true)

dire("== terminer")
attendu("un second combat est refuse", select(2, C.Inviter({})), "un combat est deja en cours.")
attendu("termine", (C.Terminer()), true)
attendu("plus de combat", C.EnCours(), false)
attendu("bandeau cache", f:IsShown(), false)

dire("== en groupe : inviter, repondre, lancer")
-- Sur un meme royaume, WoW peut rendre les membres sans suffixe par
-- UnitName, tandis que CHAT_MSG_ADDON suffixe toujours l'expediteur.
__groupe({ "Reika", "Nytherah" })
-- La boucle rend chaque envoi a son expediteur : ce client joue le MJ ET le
-- joueur invite (Nytherah).
__reseauBoucle(true, "Nytherah-Apertus")
local invitation = C.Inviter({ moi = true })
attendu("une invitation", invitation ~= nil and invitation.s ~= nil, true)
attendu("Nytherah est attendue", table.concat(C.Attendus(), ","), "Nytherah-Apertus")
attendu("pas de combat avant les reponses", C.EnCours(), false)
local d = B.invitation
attendu("l'invitation s'affiche chez le joueur", d ~= nil and d:IsShown(), true)
attendu("elle dit qui invite", d.texte:GetText():find("Nytherah-Apertus souhaite lancer un combat", 1, true) ~= nil, true)
local mj = LCM.UI.CombatMJ.Basculer()
attendu("la fenetre du MJ s'ouvre", mj:IsShown(), true)
attendu("elle attend une reponse", mj.bandeau:GetText(), "Invitation envoyée : 1 réponse attendue.")
attendu("on ne coche plus rien pendant l'invitation", mj.moi:IsEnabled(), false)
d.oui:Click()
attendu("la reponse est arrivee : on lance", C.EnCours(), true)
attendu("l'invitation se ferme", d:IsShown(), false)
attendu("le joueur voit son jet", aDit("Initiative :"), true)
local ids = {}
for _, e in ipairs(C.Etat().entrees) do ids[#ids + 1] = e.id end
table.sort(ids)
attendu("moi et Nytherah", table.concat(ids, ","), "Nytherah-Apertus," .. moi)
attendu("aucun message au-dessus de 255 octets", __plusGrosEnvoi() <= 255, true)
attendu("la fenetre du MJ montre l'ordre", mj.titreListe:GetText(), "Ordre d'initiative")
attendu("deux lignes", mj.nombreListe, 2)
-- Un groupe, pas un raid : le canal Raid n'existe pas, on annonce pour soi
-- (comme Necronicon). C'est le chef qui choisit, pas le nombre de membres.
attendu("en groupe sans raid, rien au chat", #__chats, 0)

dire("== un joueur passe son tour : seulement le sien")
__reseauBoucle(false)
local courant = C.Courant()
local autre = courant.id == moi and "Nytherah-Apertus" or nil
if autre then
    -- C'est mon tour : Nytherah essaie de passer a ma place.
    local c1 = C.Etat().c
    recevoir("Nytherah-Apertus", "combat>", { s = C.Etat().s })
    attendu("refuse : ce n'est pas le sien", C.Etat().c, c1)
    C.Avancer(1)
end
attendu("c'est a Nytherah", C.Courant().id, "Nytherah-Apertus")
local c2 = C.Etat().c
recevoir("Nytherah-Apertus", "combat>", { s = "autre-session" })
attendu("une autre session ne compte pas", C.Etat().c, c2)
recevoir("Nytherah-Apertus", "combat>", { s = C.Etat().s })
attendu("son tour passe", C.Etat().c ~= c2, true)
attendu("le pas part au groupe", dernierEnvoi().message:find("combat~", 1, true) ~= nil, true)

dire("== un joueur KO est saute apres les resolutions d'etats")
local etatKO = C.Etat()
local cSauve, tSauve, rSauve = etatKO.c, etatKO.t, etatKO.r
etatKO.c, etatKO.t, etatKO.r = #etatKO.entrees, 1, etatKO.rm
local cibleKO = etatKO.entrees[1]
cibleKO.ko = true
local vieillir = LCM.EtatsTemporaires.Vieillir
local resolutions = 0
LCM.EtatsTemporaires.Vieillir = function() resolutions = resolutions + 1 end
C.Avancer(1)
LCM.EtatsTemporaires.Vieillir = vieillir
attendu("les etats sont resolus au changement de round", resolutions, 1)
attendu("le joueur KO ne garde pas l'initiative", C.Courant().ko, nil)
attendu("l'initiative revient au joueur conscient", C.Courant().id, etatKO.entrees[2].id)
local etatApresKO = C.Etat()
etatApresKO.entrees[1].ko = nil
etatApresKO.c, etatApresKO.t, etatApresKO.r = cSauve, tSauve, rSauve

dire("== un joueur revenu d'un /reload redemande l'etat")
local n = #__envois
recevoir("Nytherah-Apertus", "combat!", {})
attendu("le MJ lui renvoie l'etat", __envois[n + 1] and __envois[n + 1].message:find("combat=", 1, true) ~= nil, true)
attendu("en chuchotant", __envois[n + 1] and __envois[n + 1].cible, "Nytherah-Apertus")
n = #__envois
recevoir("Inconnu-Apertus", "combat!", {})
attendu("pas a quelqu'un qui n'est pas au combat", #__envois, n)
dire("== integrer un joueur apres le lancement")
__groupe({ "Reika-Apertus", "Nytherah-Apertus", "Bram-Apertus" }, true)
local courantAvantAjout = C.Courant().id
local panneauCombat = LCM.UI.CombatMJ.Basculer()
panneauCombat:Afficher()
attendu("la colonne passe aux joueurs disponibles", panneauCombat.titreQui:GetText(), "Joueurs à intégrer")
attendu("le bouton d'integration apparait", panneauCombat.integrer:IsShown(), true)
attendu("le nouveau joueur est proposé", panneauCombat.lignesPNJ[1].nom:GetText(), "Bram-Apertus")
attendu("la case selectionne le joueur", panneauCombat.lignesPNJ[1].case:IsEnabled(), true)
panneauCombat.lignesPNJ[1].case:Click()
panneauCombat.integrer:Click()
local tardive = C.invitationTardive
attendu("invitation tardive", tardive ~= nil, true)
attendu("le nouveau joueur recoit une invitation", dernierEnvoi().cible, "Bram-Apertus")
recevoir("Bram-Apertus", "combat+", { s = C.Etat().s, ok = 1, v = 77, n = "Bram" })
attendu("il est ajoute sans relancer", #C.Etat().entrees, 3)
attendu("le combattant courant ne change pas", C.Courant().id, courantAvantAjout)
attendu("l'etat complet est rediffuse", dernierEnvoi().message:find("combat=", 1, true) ~= nil, true)
C.Terminer()
-- Le combat du MJ est un onglet du Panel MJ depuis le 3 octobre 2026 : on
-- ferme le panneau, pas l'onglet.
LCM.UI.PanneauMJ.frame:Hide()

dire("== refuser, ou ne pas repondre")
__groupe({ "Reika-Apertus", "Nytherah-Apertus", "Bram-Apertus" }, true)
C.Inviter({ moi = true })
recevoir("Nytherah-Apertus", "combat+", { s = C.invitation.s, ok = 0 })
attendu("un refus est note", C.invitation.reponses["Nytherah-Apertus"].ok, false)
attendu("on attend encore Bram", table.concat(C.Attendus(), ","), "Bram-Apertus")
recevoir("Intrus-Apertus", "combat+", { s = C.invitation.s, ok = 1, v = 99 })
attendu("un non-invite ne compte pas", C.invitation.reponses["Intrus-Apertus"], nil)
C.Lancer()
attendu("lance sans attendre : moi seul", #C.Etat().entrees, 1)
attendu("en raid, les annonces vont au raid", __chats[#__chats] and __chats[#__chats].canal, "RAID")
attendu("marquees comme venant des Contes", __chats[#__chats] and __chats[#__chats].texte:find("[Contes] ", 1, true) == 1, true)
C.Terminer()

dire("== un raid d'une seule personne reste un raid")
__groupe({ "Reika-Apertus" }, true)
attendu("canal raid", C.CanalGroupe(), "RAID")
local nChats = #__chats
C.Inviter({ moi = true })
attendu("personne a inviter : lance tout de suite", C.EnCours(), true)
attendu("et annonce au raid", #__chats > nChats and __chats[#__chats].canal, "RAID")
C.Terminer()
__groupe({ "Reika-Apertus", "Nytherah-Apertus" }, true)
attendu("deux joueurs peuvent former un raid", C.CanalGroupe(), "RAID")
__groupe({ "Reika-Apertus", "Nytherah-Apertus", "Bram-Apertus" })
attendu("et trois un simple groupe", C.CanalGroupe(), "PARTY")
__groupe({})
attendu("seul et sans groupe : rien", C.CanalGroupe(), nil)
__groupe({ "Reika-Apertus", "Nytherah-Apertus" })

dire("== cote joueur : l'etat vient du MJ")
LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = false
local paquet = C.Paquet({ s = "s1", c = 2, t = 4, r = 2, rm = 3, entrees = {
    { id = "Nytherah-Apertus", nom = "Nytherah", v = 12 },
    { id = moi, nom = "Reika", v = 8, icone = "Interface\\Icons\\INV_Misc_Book_09" },
    { id = "pnj:loup", nom = "Loup", v = 3, pnj = true },
} })
recevoir("Nytherah-Apertus", "combat=", paquet)
attendu("le combat arrive", C.EnCours(), true)
attendu("mene par Nytherah", C.Etat().mj, "Nytherah-Apertus")
attendu("je ne le mene pas", C.EstMJ(), false)
attendu("le PNJ est reconnu", C.Etat().entrees[3].pnj, true)
attendu("c'est mon tour", C.EstMonTour(), true)
attendu("le bandeau aussi", f:IsShown() and f.avis:IsShown(), true)
attendu("tour 04", f.tour:GetText(), "04")
attendu("l'icone suit", f.cartes[2].icone:GetTexture(), "Interface\\Icons\\INV_Misc_Book_09")
f.passer:Click()
attendu("je demande au MJ de passer", dernierEnvoi().message:find("combat>", 1, true) ~= nil, true)
attendu("a lui seul", dernierEnvoi().cible, "Nytherah-Apertus")
attendu("rien ne bouge avant sa reponse", C.Etat().c, 2)
recevoir("Bram-Apertus", "combat~", { s = "s1", c = 3, t = 4, r = 2 })
attendu("un pas d'un autre que le MJ est ignore", C.Etat().c, 2)
recevoir("Nytherah-Apertus", "combat~", { s = "s1", c = 3, t = 4, r = 2 })
attendu("le pas du MJ s'applique", C.Etat().c, 3)
attendu("ce n'est plus mon tour", C.PeutPasser(), false)
attendu("bouton eteint", f.passer:IsEnabled(), false)
local ok, pourquoi = C.Passer()
attendu("passer hors de son tour est refuse", pourquoi, "ce n'est pas ton tour.")
recevoir("Nytherah-Apertus", "combat.", { s = "s1" })
attendu("fin du combat", C.EnCours(), false)
attendu("bandeau cache", f:IsShown(), false)

dire("== qui n'est pas au combat ne voit pas le bandeau")
local sansMoi = C.Paquet({ s = "s2", c = 1, t = 1, r = 1, rm = 3, entrees = {
    { id = "Nytherah-Apertus", nom = "Nytherah", v = 12 } } })
recevoir("Nytherah-Apertus", "combat=", sansMoi)
attendu("ignore", C.EnCours(), false)

dire("== une invitation d'un etranger au groupe est ignoree")
recevoir("Etranger-Apertus", "combat?", { s = "x" })
attendu("rien", C.invitationRecue, nil)
recevoir("Nytherah-Apertus", "combat?", { s = "x" })
attendu("du groupe : proposee", C.invitationRecue ~= nil, true)
B.invitation.non:Click()
attendu("refuser repond au MJ", dernierEnvoi().message:find("ok=0", 1, true) ~= nil, true)
attendu("sans jet", dernierEnvoi().message:find("v=", 1, true), nil)

dire("== au-dela de seize : celui qui joue reste visible")
local v, debut = B.Visibles({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20 }, 18, 1)
attendu("seize cases", #v, 16)
attendu("le courant en premier", v[1], 18)
attendu("puis la page", v[2], 1)
v = B.Visibles({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20 }, 3, 1)
attendu("courant dans la page : la page telle quelle", v[1] .. ".." .. v[16], "1..16")
v, debut = B.Visibles({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20 }, 20, 17)
attendu("la derniere page recule pour rester pleine", debut, 5)

dire("== les commandes")
LCM._masterCompanion = true
__addonsCharges["LesContesMalveillants_MJ"] = true
SlashCmdList["LCM"]("combat")
local panneau = LCM.UI.PanneauMJ.frame
attendu("/lcm combat ouvre le Panel MJ sur l'onglet Combat",
    panneau:IsShown() and panneau.onglet == "combat" and LCM.UI.CombatMJ.frame:IsShown(), true)

dire("== les defenses puisent dans la reserve sans consommer la tranche")
__groupe({})
I.Relacher()
LCM.Entities.SetGauge(maFiche, "pa", 6, 6)
C.Inviter({ moi = true })
attendu("deux PA offensifs", C.PADisponibles(maFiche), 2)
local defense = { entity = maFiche, recu = {}, vars = {}, journal = {}, nom = "Defense" }
local suiteDefense = false
A.Pas.pay({ tag = "#pa", amount = 1 }, defense, function() suiteDefense = true end)
attendu("la defense est resolue", suiteDefense, true)
attendu("elle consomme un PA reel", LCM.Entities.Gauge(maFiche, "pa").current, 5)
attendu("elle conserve les deux PA offensifs", C.PADisponibles(maFiche), 2)
attendu("les deux PA offensifs peuvent etre payes", A.Payer(maFiche, "#pa", 2), true)
attendu("quota offensif epuise", C.PADisponibles(maFiche), 0)
attendu("la defense voit encore trois PA", A.Disponible(maFiche, true), 3)
attendu("une defense reste possible", A.Payer(maFiche, "#pa", 1, true), true)
attendu("elle ne rend pas de quota offensif", C.PADisponibles(maFiche), 0)
attendu("on ne se defend pas a credit", A.Payer(maFiche, "#pa", 3, true), false)
C.Terminer()

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
