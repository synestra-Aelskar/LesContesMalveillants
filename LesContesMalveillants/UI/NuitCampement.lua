-- Cinematique commune : textures BLP transparentes, calques ordonnes.
local _, LCM = ...
local N = {}
LCM.UI.NuitCampement = N
local floor, min, max = math.floor, math.min, math.max
local function borne(v) return max(0, min(1, v)) end
local function doux(v) v = borne(v); return v * v * (3 - 2 * v) end
local function cadre(parent, niveau)
    local f = CreateFrame("Frame", nil, parent)
    f:SetFrameStrata("TOOLTIP"); f:SetFrameLevel(niveau)
    f:SetSize(384, 216); f:Show()
    f.pool = {}; f.utilises = 0
    return f
end
local CHEMIN = "Interface\\AddOns\\LesContesMalveillants\\ressources\\campement\\"
local function sprite(parent, nom, x, y, w, h)
    local t=parent:CreateTexture(nil,"ARTWORK")
    t:SetTexture(CHEMIN..nom..".blp")
    t:SetPoint("BOTTOMLEFT",parent,"BOTTOMLEFT",x,y); t:SetSize(w,h)
    parent.pool[#parent.pool+1]=t
    return t
end
local function horloge() return (GetServerTime and GetServerTime()) or time() end
local vus, ordre = {}, {}

local function actualiserVote(f)
    local n=0
    for _ in pairs(f.votes) do n=n+1 end
    f.nombreVotes=n
    f.voteTexte:SetText(string.format("%d/%d votes pour passer",n,f.nombreVotants))
    f.voteAide:SetText((f.votes[LCM.PlayerId()] and "Vote enregistré" or "Espace pour voter")
        .. string.format("  ·  %d requis (80 %%)",f.seuilVotes))
    if n>=f.seuilVotes and not f.finVote then
        f.finVote=GetTime(); f.alphaFinVote=f:GetAlpha()
    end
end

local function recevoirVote(qui,id)
    local f=N.frame
    if not f or not f:IsShown() or f.idNuit~=id or not f.votants[qui]
        or f.votes[qui] or f.finVote then return false end
    f.votes[qui]=true
    actualiserVote(f)
    return true
end

function N.Voter()
    local f=N.frame
    if not f or not f:IsShown() or GetTime()<f.origine then return false end
    local id=f.idNuit
    if not recevoirVote(LCM.PlayerId(),id) then return false end
    local canal=LCM.Combat.CanalGroupe()
    if canal then LCM.Reseau.Envoyer("CAMP_VOTE",{c=id},canal) end
    return true
end

LCM.Reseau.Ecouter("CAMP_VOTE",function(qui,d)
    if d and LCM.Reseau.DansLeGroupe(qui) then recevoirVote(qui,d.c) end
end)

local function creer()
    if N.frame then return N.frame end
    local f = cadre(UIParent, 9000); N.frame=f
    f:SetAllPoints(UIParent); f:EnableMouse(true)
    if f.SetIgnoreParentAlpha then f:SetIgnoreParentAlpha(true) end
    f.noir=f:CreateTexture(nil,"BACKGROUND"); f.noir:SetAllPoints(f); f.noir:SetColorTexture(0,0,0,1)
    f.scene=cadre(f,9010); f.scene:SetPoint("CENTER"); f.scene:SetClipsChildren(true)
    f.ciel=cadre(f.scene,9020); f.ciel:SetAllPoints(f.scene)
    f.terre=cadre(f.scene,9050); f.terre:SetAllPoints(f.scene)
    f.tente=cadre(f.scene,9060)
    f.feu=cadre(f.scene,9070); f.feu:SetAllPoints(f.scene)
    f.titre=f:CreateFontString(nil,"OVERLAY")
    f.titre:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",18,"")
    f.titre:SetPoint("TOP",f.scene,"BOTTOM",0,-24); f.titre:SetTextColor(.82,.77,.61)
    f.voteCadre=cadre(f,9080)
    f.voteCadre:SetSize(330,60); f.voteCadre:SetPoint("TOPRIGHT",f,"TOPRIGHT",-26,-22)
    f.voteTexte=f.voteCadre:CreateFontString(nil,"OVERLAY")
    f.voteTexte:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",16,"")
    f.voteTexte:SetPoint("TOPRIGHT"); f.voteTexte:SetTextColor(.94,.88,.70)
    f.voteAide=f.voteCadre:CreateFontString(nil,"OVERLAY")
    f.voteAide:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",12,"")
    f.voteAide:SetPoint("TOPRIGHT",f.voteTexte,"BOTTOMRIGHT",0,-8); f.voteAide:SetTextColor(.66,.67,.65)
    f:EnableKeyboard(true)
    f:SetScript("OnKeyDown",function(self,touche)
        if not (InCombatLockdown and InCombatLockdown()) then
            self:SetPropagateKeyboardInput(touche~="SPACE")
        end
        if touche=="SPACE" then N.Voter() end
    end)
    f:Hide()
    f:SetScript("OnHide",function(self)
        self:SetScript("OnUpdate",nil)
        self.votes=nil; self.votants=nil; self.idNuit=nil; self.finVote=nil
    end)
    return f
end

local function decor(f,graine)
    if not f.images then
        f.images=true
        -- Une seule image opaque : lune et soleil sont peints aux antipodes.
        -- Le carre depasse la diagonale de la scene : jamais de coin vide.
        f.ciel.image=sprite(f.ciel,"ciel-cycle",-108,-260,600,600)
        f.foretG=sprite(f.terre,"foret",-12,22,210,180)
        f.foretD=sprite(f.terre,"foret",186,20,210,180)
        f.foretD:SetTexCoord(1,0,0,1)
        f.sol=sprite(f.terre,"sol",-28,-24,440,140)
        f.tente.image=sprite(f.tente,"tente",0,0,134,134)
        f.feu.images={}
        for i=1,4 do
            local t=sprite(f.feu,"feu"..i,216,15,48,60)
            t:Hide(); f.feu.images[i]=t
        end
    end
    -- Meme graine pour tous, positions et orientation du bois variables.
    local variante=graine%3
    local decalage=(graine%17)-8
    f.foretG:ClearAllPoints(); f.foretG:SetPoint("BOTTOMLEFT",f.terre,"BOTTOMLEFT",-20+decalage,16+variante*3)
    f.foretD:ClearAllPoints(); f.foretD:SetPoint("BOTTOMLEFT",f.terre,"BOTTOMLEFT",186+decalage,20-variante*2)
    f.foretG:SetSize(210+variante*8,180+variante*4)
    f.foretD:SetSize(210-variante*6,180-variante*3)
    f.graine=graine
    f.imageFeu=nil
end

function N.Lancer(id,graine,debut,membres)
    graine,debut=tonumber(graine),tonumber(debut)
    local maintenant=horloge()
    if type(id)~="string" or id=="" or vus[id] or not graine or not debut
        or graine~=graine or debut~=debut or graine<1 or graine>2147483646
        or debut<maintenant-16 or debut>maintenant+10 then return false end
    local f=creer()
    if f:IsShown() then return false end
    vus[id]=true; ordre[#ordre+1]=id
    if #ordre>64 then vus[table.remove(ordre,1)]=nil end
    decor(f,floor(graine))
    f.origine=GetTime()+debut-maintenant
    f.idNuit=id; f.votes={}; f.votants={}; f.nombreVotants=0; f.finVote=nil
    -- Liste figee au lancement, commune a tous les clients meme si le groupe change.
    if type(membres)~="table" then
        membres=LCM.Combat.Membres(); membres[#membres+1]=LCM.PlayerId()
    end
    for _,nom in ipairs(membres) do
        if type(nom)=="string" and not f.votants[nom] then
            f.votants[nom]=true; f.nombreVotants=f.nombreVotants+1
        end
    end
    f.seuilVotes=max(1,math.ceil(f.nombreVotants*.8))
    actualiserVote(f)
    if not (InCombatLockdown and InCombatLockdown()) then f:SetPropagateKeyboardInput(true) end
    f:SetAlpha(0); f.scene:SetAlpha(0); f.titre:SetAlpha(0); f:Show()
    local function avancer(self)
        if self.finVote then
            local p=(GetTime()-self.finVote)/.45
            if p>=1 then self:Hide() else self:SetAlpha(self.alphaFinVote*(1-doux(p))) end
            return
        end
        local t=GetTime()-self.origine
        if t>=18 then self:Hide(); return end
        self.temps=t
        self:EnableMouse(t>=0)
        self:SetAlpha(t<1.3 and doux(t/1.3) or (1-doux((t-16.5)/1.5)))
        local reveal=doux((t-1.4)/1.2)*(1-doux((t-15)/1.3))
        self.scene:SetAlpha(reveal); self.titre:SetAlpha(reveal*.8)
        self.scene:SetScale(max(.5,min((UIParent:GetWidth()-60)/384,(UIParent:GetHeight()-140)/216)))
        self.titre:SetText(t<10.5 and "L A   N U I T   P A S S E" or "U N   N O U V E A U   J O U R")
        local jour=doux((t-9.5)/4)
        local progression=borne((t-2)/12)
        self.ciel.image:SetRotation(-.65+(math.pi+.65)*progression)
        self.tente:SetAlpha(doux((t-2)/.65)); self.tente:ClearAllPoints()
        self.tente:SetPoint("BOTTOMLEFT",self.scene,"BOTTOMLEFT",124,20-8*(1-doux((t-2)/.65)))
        local lumiere=.58+jour*.42
        for _,image in ipairs({self.foretG,self.foretD,self.sol}) do image:SetVertexColor(lumiere*.87,lumiere*.96,lumiere) end
        self.tente.image:SetVertexColor(.75+jour*.25,.70+jour*.30,.65+jour*.35)
        local feu=math.floor(max(0,t)*8)%4+1
        if self.imageFeu~=feu then
            for i,image in ipairs(self.feu.images) do image:SetShown(i==feu) end
            self.imageFeu=feu
        end
        self.feu:SetAlpha(doux((t-2)/.65)*(1-jour*.3))

    end
    f:SetScript("OnUpdate",avancer); avancer(f)
    return true
end
