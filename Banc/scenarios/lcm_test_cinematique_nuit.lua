__declencher("PLAYER_LOGIN")
__personnage()
local N=LCM.UI.NuitCampement
local ko=0
local function test(n,v) if not v then ko=ko+1 end print((v and "ok " or "KO ")..n) end
test("horodatage ancien refuse",not N.Lancer("ancien",123,GetServerTime()-30))
test("graine invalide refusee",not N.Lancer("invalide",math.huge,GetServerTime()))
test("lancement",N.Lancer("nuit-test",12345,GetServerTime()))
local f=N.frame
local function temps(t) f.origine=GetTime()-t; f:GetScript("OnUpdate")(f,0) end
temps(0); test("debut transparent",f:GetAlpha()==0)
temps(4); test("voile opaque au dessus du HUD",f:GetAlpha()==1 and f.__strata=="TOOLTIP" and f.__level==9000)
test("calques distincts dans la plage du moteur",f.ciel.__level<f.terre.__level and f.terre.__level<f.tente.__level and f.tente.__level<f.feu.__level and f.voteCadre.__level<10000)
test("decor rogne aux limites de la scene",f.scene:DoesClipChildren())
for _,nom in ipairs({"lac-montagne","tente","ciel-nuit","ciel-aube","lune","soleil","feu1","feu2","feu3","feu4"}) do
    test("BLP livre : "..nom,__fichierExiste("LesContesMalveillants/ressources/campement/"..nom..".blp"))
end
local imageFeu=f.imageFeu
temps(4.2); test("feu change de frame",f.imageFeu~=imageFeu)
test("tente visible",f.tente:GetAlpha()==1)
local avant=f.lune.__points[1][4]
temps(8); test("lune traverse le ciel",f.lune.__points[1][4]>avant)
test("deux ciels fixes sans rotation",f.ciel.nuit:GetRotation()==0 and f.ciel.aube:GetRotation()==0)
test("aucune bordure",f.bords==nil)
test("texte visible dans sa seule banniere",f.titre:GetAlpha()==1 and f.legende:GetAlpha()>0 and f.legende:GetWidth()<UIParent:GetWidth())
test("scene couvre tout l ecran",math.abs(f.scene:GetWidth()*f.scene:GetScale()-UIParent:GetWidth())<.01 and math.abs(f.scene:GetHeight()*f.scene:GetScale()-UIParent:GetHeight())<.01)
test("feu interpole deux poses",f.feu.base:GetTexture()~=f.feu.suivante:GetTexture() and f.feu.suivante:GetAlpha()>=0 and f.feu.suivante:GetAlpha()<=1)
test("doublon ignore",not N.Lancer("nuit-test",12345,GetServerTime()))
temps(14); test("aube et soleil a la fin",f.ciel.aube:GetAlpha()==1 and f.soleil:GetAlpha()>.8 and f.lune:GetAlpha()==0)
local ancienneLargeur,ancienneHauteur=UIParent:GetWidth(),UIParent:GetHeight()
for _,taille in ipairs({{2560,1080},{1024,768}}) do
    UIParent:SetSize(taille[1],taille[2]); temps(14)
    test("plein ecran "..taille[1].."x"..taille[2],math.abs(f.scene:GetWidth()*f.scene:GetScale()-taille[1])<.01 and f.foret.__w>=f.scene:GetWidth() and f.foret.__h>=216)
end
UIParent:SetSize(ancienneLargeur,ancienneHauteur); temps(14)
local empreinte=f.graine
local textures=#f.terre.pool
temps(18); test("voile retire et animation arretee",not f:IsShown() and not f:GetScript("OnUpdate"))
test("clavier libere en fin de nuit",f.__keyboard==false)
test("autre nuit",N.Lancer("nuit-2",12345,GetServerTime()))
test("clavier reactive a la nuit suivante",f.__keyboard==true)
test("decor commun reproductible",f.graine==empreinte)
test("textures reutilisees",#f.terre.pool==textures)
temps(18)
N.Lancer("nuit-3",45678,GetServerTime()); test("decor varie",f.graine~=empreinte); temps(18)
-- Le message atteint aussi un membre qui ne participe pas au camp.
__groupe({"Ami-Apertus"})
LCM.Campement.courant=nil
local d={c="nuit-reseau",nuit=1,graine=87654,debut=GetServerTime()+2,n=1}
LCM.Reseau.Recevoir("Ami-Apertus","987:1:1:CAMP_FIN|"..LCM.Reseau.Encoder(d))
test("spectateur du groupe voit la nuit",f:IsShown())
test("spectateur reste hors camp",LCM.Campement.courant==nil)
temps(18)
__groupe({})
d.c="nuit-hors-groupe"
LCM.Reseau.Recevoir("Intrus-Apertus","988:1:1:CAMP_FIN|"..LCM.Reseau.Encoder(d))
test("message hors groupe ignore",not f:IsShown())
N.Lancer("nuit-retard",123,GetServerTime()-8)
test("message retarde rattrape la sequence",f.temps>=8 and f:GetAlpha()==1)
temps(18)
-- Vote commun : 80 % de tous les joueurs, et non seulement des campeurs.
local amis={"Ami-Apertus","Deux-Apertus","Trois-Apertus","Quatre-Apertus"}
__groupe(amis)
N.Lancer("nuit-vote",123,GetServerTime())
temps(4)
test("seuil 80 % de cinq joueurs",f.nombreVotants==5 and f.seuilVotes==4)
test("compteur initial",f.voteTexte:GetText()=="0/5 votes pour passer")
f:GetScript("OnKeyDown")(f,"A")
test("autres touches transmises sans voter",f.__propagateKeyboard and f.nombreVotes==0)
f:GetScript("OnKeyDown")(f,"SPACE")
test("espace vote et ne saute pas",not f.__propagateKeyboard and f.nombreVotes==1)
test("vote personnel diffuse",__envois[#__envois].message:find("CAMP_VOTE|",1,true)~=nil)
local envois=#__envois
f:GetScript("OnKeyDown")(f,"SPACE")
test("espace repete ne recompte pas",f.nombreVotes==1 and #__envois==envois)
local numero=2000
local function voter(qui,id)
    numero=numero+1
    LCM.Reseau.Recevoir(qui,tostring(numero)..":1:1:CAMP_VOTE|"..LCM.Reseau.Encoder({c=id or "nuit-vote"}))
end
voter(amis[1],"ancienne-nuit"); voter("Intrus-Apertus")
test("votes etrangers ignores",f.nombreVotes==1)
voter(amis[1]); voter(amis[1]); voter(amis[2])
test("trois sur cinq ne suffisent pas et doublon ignore",f.nombreVotes==3 and not f.finVote)
voter(amis[3])
test("quatre sur cinq declenchent la sortie",f.finVote~=nil and f.voteTexte:GetText()=="4/5 votes pour passer")
f.finVote=GetTime()-.5; f:GetScript("OnUpdate")(f,0)
test("sortie du vote nettoie la capture",not f:IsShown() and f.votes==nil and not f:GetScript("OnUpdate"))
amis[#amis+1]="Cinq-Apertus"; __groupe(amis,true)
N.Lancer("nuit-raid",123,GetServerTime()); temps(4)
test("six joueurs demandent cinq voix",f.seuilVotes==5 and f.nombreVotes==0)
for _,nom in ipairs(amis) do voter(nom,"nuit-raid") end
test("vote atteint a distance sans vote local",f.finVote~=nil and f.nombreVotes==5)
f.finVote=GetTime()-.5; f:GetScript("OnUpdate")(f,0)
test("raid termine aussi",not f:IsShown())
print(ko==0 and "TOUT PASSE" or (ko.." ECHEC(S)"))
