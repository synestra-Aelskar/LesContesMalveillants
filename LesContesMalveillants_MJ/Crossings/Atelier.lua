-- Visual workstation built around the existing theme setters and renderer.
local ZG,UI=LCMCrossings.ThemeEditor,LCMCrossings.EditorUI
local K=LCM.UI
local panel=LCMCrossingsThemePanel
local c=panel.studioControls
local W,H=1280,760
panel:SetSize(W,H);panel:SetClampedToScreen(true)
c.title:SetText("CROSSINGS  /  Atelier des bannières")
local function place(region,parent,x,y)
    region:ClearAllPoints();region:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y)
end
local function text(parent,label,x,y,size)
    local f=parent:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    place(f,parent,x,y);f:SetText(label);f:SetTextColor(.83,.79,.69)
    if size then f:SetFont("Fonts\\FRIZQT__.TTF",size,"") end
    return f
end
local function button(parent,label,x,y,width,callback)
    local b=UI.CreatePanelButton(parent,width,26,label);place(b,parent,x,y)
    b:SetScript("OnClick",callback);return b
end
local function theme() return panel.selectedId and ZG:GetTheme(panel.selectedId) end
local function duration(t) return math.max(.05,t.fadeIn or .4)+math.max(0,t.hold or 2.5)+math.max(.05,t.fadeOut or .8) end
local function fit() panel:SetScale(math.min(1,(UIParent:GetWidth()-40)/W,(UIParent:GetHeight()-40)/H)) end
panel:HookScript("OnShow",fit)
panel:RegisterEvent("DISPLAY_SIZE_CHANGED");panel:SetScript("OnEvent",fit)
fit()

-- Library and contextual settings.
place(c.listScroll,panel,12,110);c.listScroll:SetHeight(590)
-- « Purger les modèles », sous la liste des thèmes. Omega le cachait ici et
-- ne l'offrait que par /crossings clean ; LCM n'a pas de commande, le bouton
-- revient donc dans l'atelier (premier clic : compte et arme, second :
-- supprime — voir Themes.lua).
if c.cleanBtn then
    c.cleanBtn:ClearAllPoints();place(c.cleanBtn,panel,12,712)
    c.cleanBtn:SetSize(168,26);c.cleanBtn:Show()
end
place(c.listSep,panel,196,48);c.listSep:SetHeight(696)
place(c.form,panel,816,80);c.form:SetSize(448,650)
c.placeholder:SetWidth(420);c.placeholder:SetText("Choisissez un modèle pour ouvrir le builder.\n\nPersonnalisez votre brouillon, puis cliquez sur Créer le thème. Rien n'est ajouté à la bibliothèque avant cette validation.")
local search=UI.CreateStyledEditBox(panel,168,24,false);place(search,panel,12,76)
search:SetScript("OnTextChanged",function(self) panel.searchText=string.lower(self:GetText() or "");panel:RefreshList() end)
c.listHeader:SetText("Mes thèmes")
local inspectorTitle=text(panel,"PERSONNALISER",820,55,13)
local saveHint=text(panel,"Modifications du thème existant : automatiques",820,710)
text(panel,"Affectation du thème : Crossings > Déclenchement",820,731)
local selectedTab="text"
local tabs={}
local optionRefresh={}
local groups={"text","decor","timing"}
local function showTab(key)
    selectedTab=key
    for _,group in ipairs(groups) do
        for _,control in ipairs(c[group]) do control:SetShown(group==key) end
        if tabs[group] then tabs[group].accent:SetShown(group==key) end
    end
    local t=theme()
    c.customFont:SetShown(key=="text" and t and t.font=="custom")
    c.customFontLabel:SetShown(key=="text" and t and t.font=="custom")
end
for i,entry in ipairs({{"text","Typographie"},{"decor","Ornements"},{"timing","Rythme & son"}}) do
    local key=entry[1]
    tabs[key]=button(c.edit,entry[2],4+(i-1)*144,36,138,function() showTab(key) end)
end
place(c.fontLabel,c.edit,6,86);place(c.colorsLabel,c.edit,6,214)
place(c.sepStyleLabel,c.edit,6,86);place(c.sepColorLbl,c.edit,6,310)
place(c.timingLabel,c.edit,6,86)
c.timingLabel:SetText("Apparition / Lecture / Disparition (secondes)")
c.preview:Hide()
local function option(key,label,choices,order,group,y)
    local lbl=text(c.edit,label,6,y)
    -- Le champ à choix de LCM, à la place du menu déroulant Blizzard.
    local menu=UI.CreateSelect(c.edit,380,28)
    place(menu,c.edit,6,y+20)
    menu.items=function()
        local list={}
        for _,value in ipairs(order) do list[#list+1]={text=choices[value],value=value} end
        return list
    end
    menu.onSelect=function(value) if panel.selectedId then ZG:SetStudioOption(panel.selectedId,key,value);panel:RefreshForm() end end
    c[group][#c[group]+1]=lbl;c[group][#c[group]+1]=menu
    optionRefresh[#optionRefresh+1]=function(t) menu:SetText(choices[t[key] or ZG.DefaultTheme[key]] or "Classique") end
end
option("design","Composition originale",ZG.StudioDesigns,{"souls","western","sumi","scifi","deco","minimal","classic"},"decor",360)
option("motion","Mouvement d'apparition",ZG.StudioMotions,{"fade","rise","stamp","split"},"timing",240)
option("placement","Position en jeu",ZG.StudioPlacements,{"top","center","bottom"},"timing",310)
local widthLabel=text(c.edit,"Largeur minimum (adaptation automatique)",6,430)
local widthEB=UI.CreateStyledEditBox(c.edit,100,24,false);place(widthEB,c.edit,6,452)
widthEB:SetMaxLetters(3)
local function saveWidth(self)
    if panel.selectedId and not panel.suppressEvents then ZG:SetStudioOption(panel.selectedId,"bannerWidth",self:GetText());self:ClearFocus() end
end
widthEB:SetScript("OnEnterPressed",saveWidth)
widthEB:SetScript("OnEditFocusLost",function(self) if panel.selectedId and not panel.suppressEvents then ZG:SetStudioOption(panel.selectedId,"bannerWidth",self:GetText()) end end)
c.decor[#c.decor+1]=widthLabel;c.decor[#c.decor+1]=widthEB
-- Commit numerical fields when leaving them, not only with Enter.
for _,eb in ipairs({c.size,c.fadeIn,c.hold,c.fadeOut}) do
    eb:HookScript("OnEditFocusLost",function(self)
        if panel.suppressEvents or not panel.selectedId then return end
        if self==c.size then ZG:SetThemeTitleSize(panel.selectedId,tonumber(self:GetText()))
        else ZG:SetThemeTiming(panel.selectedId,tonumber(c.fadeIn:GetText()),tonumber(c.hold:GetText()),tonumber(c.fadeOut:GetText())) end
    end)
end

-- Dedicated preview instance: never hides a real crossing or plays audio.
text(panel,"TEXTE DE DÉMONSTRATION",220,53,12)
local zoneEB=UI.CreateStyledEditBox(panel,270,26,false);place(zoneEB,panel,220,76);zoneEB:SetMaxLetters(64)
local subEB=UI.CreateStyledEditBox(panel,286,26,false);place(subEB,panel,500,76);subEB:SetMaxLetters(72)
zoneEB:SetText("Les Portes d'Astralune");subEB:SetText("Sanctuaire des anciens")
-- La scène d'aperçu : un fond uni et le filet doré du Kit (Omega passait
-- par un backdrop Blizzard). Les trois boutons changent la couleur du fond.
local stage=CreateFrame("Frame",nil,panel);place(stage,panel,220,114);stage:SetSize(566,230)
stage.fond=K.Aplat(stage,{.025,.035,.05,1});stage.fond:SetAllPoints(stage)
K.Bordure(stage)
function stage:SetBackdropColor(r,g,b) self.fond:SetColorTexture(r,g,b,1) end
local stageCaption=text(stage,"APERÇU EN DIRECT",14,13,10);stageCaption:SetTextColor(.55,.58,.62)
local preview=ZG.CreateBannerRenderer(stage)
preview:ClearAllPoints();preview:SetPoint("CENTER",stage,"CENTER",0,0);preview:SetScale(.86)
local stageColors={{.025,.035,.05},{.12,.10,.08},{.60,.61,.59}}
for i,label in ipairs({"Nuit","Pierre","Clair"}) do
    button(stage,label,302+(i-1)*82,194,76,function() stage:SetBackdropColor(unpack(stageColors[i])) end)
end
local clock=text(panel,"",220,357)
local status=text(panel,"",220,739)
-- La frise : le curseur du Kit (UI.Curseur), qui compte en entiers — on y
-- range des centièmes de seconde.
local progress,playing,loop,settingSlider=0,false,false,false
local seek
local timeline=K.Curseur(panel,function(value) if not settingSlider then playing=false;seek(value/100) end end)
place(timeline,panel,226,387);timeline:SetSize(550,12);timeline:Regler(400,0)
local previewTheme=ZG.DefaultTheme
function seek(value)
    progress=math.max(0,math.min(duration(previewTheme),value))
    preview:Seek(progress)
    clock:SetText(string.format("%.1f s / %.1f s   ·   Apparition  /  Lecture  /  Disparition",progress,duration(previewTheme)))
    settingSlider=true;timeline:Poser(progress*100);settingSlider=false
end
local playBtn
playBtn=button(panel,"Lire l'entrée",220,414,124,function()
    playing=not playing
    if playing and progress>=duration(previewTheme) then seek(0) end
    if playing and progress==math.max(.05,previewTheme.fadeIn or .4) then seek(0) end
    playBtn:SetText(playing and "Pause" or "Lire l'entrée")
end)
button(panel,"Rejouer",352,414,100,function() seek(0);playing=true;playBtn:SetText("Pause") end)
local loopBtn
loopBtn=button(panel,"Boucle : non",460,414,130,function() loop=not loop;loopBtn:SetText(loop and "Boucle : oui" or "Boucle : non") end)
button(panel,"Voir en jeu",598,414,188,function()
    ZG:ShowBannerExample(zoneEB:GetText(),subEB:GetText(),theme() or previewTheme)
end)

-- Bounded per-selection history; IDs, ownership and links never change.
local history={undo={},redo={}}
local function fingerprint(value)
    if type(value)~="table" then return tostring(value) end
    local keys={};for k in pairs(value) do keys[#keys+1]=k end;table.sort(keys)
    local out={};for _,k in ipairs(keys) do out[#out+1]=k.."="..fingerprint(value[k]) end
    return table.concat(out,"|")
end
local lastPreviewKey
local function refreshPreview()
    local t=theme() or ZG.DefaultTheme
    local stamp=fingerprint(t)
    if history.id~=panel.selectedId then
        history={id=panel.selectedId,undo={},redo={},last=ZG.CopyTheme(t),stamp=stamp}
        playing=false;progress=math.max(.05,t.fadeIn or .4)
        c.delete:SetText("Supprimer");panel.deleteArmed=nil
    elseif stamp~=history.stamp then
        if history.last then table.insert(history.undo,history.last);if #history.undo>40 then table.remove(history.undo,1) end end
        history.redo={};history.last=ZG.CopyTheme(t);history.stamp=stamp
    end
    local key=stamp..zoneEB:GetText().."/"..subEB:GetText()
    if key~=lastPreviewKey then
        previewTheme=t;preview:Configure(zoneEB:GetText()~="" and zoneEB:GetText() or "Nom du lieu",subEB:GetText(),t)
        preview:SetScale(math.min(.86,160/(preview.baseHeight or 150),520/((preview.baseWidth or 600)*(t.motion=="stamp" and 1.15 or 1))))
        for _,update in ipairs(optionRefresh) do update(t) end
        if not widthEB:HasFocus() then widthEB:SetText(tostring(t.bannerWidth or 600)) end
        timeline:Regler(math.floor(duration(t)*100),progress*100);seek(playing and progress or math.max(.05,t.fadeIn or .4))
        lastPreviewKey=key
    end
    local draft=ZG.draft and ZG.draft.id==panel.selectedId
    if not draft or (t.name or ""):match("%S") then panel.draftError=nil end
    status:SetText(panel.draftError or (draft and ("Brouillon : "..t.name.."   ·   Non enregistré") or theme() and ("Thème : "..t.name.."   ·   Enregistré") or "Choisissez un modèle pour ouvrir le builder."))
    saveHint:SetText(draft and "Brouillon local — validez pour créer le thème" or "Modifications du thème existant : automatiques")
    if panel.createThemeButton then panel.createThemeButton:SetShown(draft and true or false);panel.cancelDraftButton:SetShown(draft and true or false) end
    c.delete:SetShown(theme()~=nil and not draft)
    showTab(selectedTab)
end
local function restore(fromKey,toKey)
    refreshPreview()
    local from,to=history[fromKey],history[toKey]
    local snapshot=table.remove(from)
    if not snapshot or not theme() then return end
    table.insert(to,ZG.CopyTheme(theme()))
    if ZG:RestoreStudioTheme(panel.selectedId,snapshot) then
        history.last=ZG.CopyTheme(snapshot);history.stamp=fingerprint(snapshot)
        panel:RefreshAll();refreshPreview()
    end
end
button(panel,"Annuler",838,12,110,function() restore("undo","redo") end)
button(panel,"Rétablir",954,12,110,function() restore("redo","undo") end)
button(panel,"Dupliquer",1070,12,138,function()
    local t=theme();if not t then return end
    panel:BeginDraft(nil,t)
end)
function panel:BeginDraft(preset,source)
    local draft=ZG:BeginDraft(preset,source)
    search:SetText("");self.selectedId=draft.id;self:RefreshAll()
end
panel.createThemeButton=button(panel,"Créer le thème",820,670,210,function()
    -- Commit pending numerical edits before taking the final snapshot.
    for _,box in ipairs({c.size,c.fadeIn,c.hold,c.fadeOut,widthEB}) do box:ClearFocus() end
    local saved,err=ZG:CommitDraft()
    if saved then panel.selectedId=saved.id;panel:RefreshAll()
    elseif err then panel.draftError=err;status:SetText(err) end
end)
panel.cancelDraftButton=button(panel,"Abandonner le brouillon",1038,670,222,function()
    ZG:CancelDraft();panel.selectedId=nil;panel:RefreshAll()
end)
-- An explicit second click prevents deleting a shared style by accident.
local deleteAction=c.delete:GetScript("OnClick")
c.delete:SetScript("OnClick",function(self)
    if panel.deleteArmed==panel.selectedId and panel.selectedId then deleteAction(self)
    else panel.deleteArmed=panel.selectedId;self:SetText("Confirmer") end
end)

text(panel,"MODÈLES  /  Ouvrir dans le builder",220,463,13)
local galleryPage=1
local galleryTiles={}
local pageLabel=text(panel,"",618,463,11)
local function refreshGallery()
    pageLabel:SetText(galleryPage.." / "..math.ceil(#ZG.StudioPresets/6))
    for i,entry in ipairs(galleryTiles) do
        local preset=ZG.StudioPresets[(galleryPage-1)*6+i]
        entry.preset=preset;entry.tile:SetShown(preset~=nil)
        if preset then
            local t=ZG:StudioPresetTheme(preset)
            entry.sample:Configure(preset.name,"",t);entry.sample:Seek(t.fadeIn)
            entry.sample:SetScale(math.min(.40,250/entry.sample.baseWidth,42/entry.sample.baseHeight))
            entry.caption:SetText(preset.caption)
        end
    end
end
button(panel,"<",714,453,30,function() galleryPage=(galleryPage-2)%math.ceil(#ZG.StudioPresets/6)+1;refreshGallery() end)
button(panel,">",752,453,30,function() galleryPage=galleryPage%math.ceil(#ZG.StudioPresets/6)+1;refreshGallery() end)
for i=1,6 do
    local col,row=(i-1)%2,math.floor((i-1)/2)
    -- Une vignette : le fond des champs du Kit et un filet qui prend la
    -- couleur du modèle au survol.
    local tile=CreateFrame("Button",nil,panel)
    place(tile,panel,220+col*288,486+row*80);tile:SetSize(278,72)
    tile.fond=K.Aplat(tile,{.035,.030,.023,1});tile.fond:SetAllPoints(tile)
    tile.traits=K.Bordure(tile,{K.C.bordure[1],K.C.bordure[2],K.C.bordure[3],.35})
    function tile:SetBackdropBorderColor(r,g,b,a) for _,trait in ipairs(self.traits) do trait:SetColorTexture(r,g,b,a or 1) end end
    local sample=ZG.CreateBannerRenderer(tile);sample:ClearAllPoints();sample:SetPoint("TOP",tile,"TOP",0,-10);sample:SetScale(.40)
    local entry={tile=tile,sample=sample,caption=text(tile,"",14,52,10)}
    galleryTiles[i]=entry
    tile:SetScript("OnEnter",function() if entry.preset then tile:SetBackdropBorderColor(unpack(entry.preset.color)) end end)
    tile:SetScript("OnLeave",function() tile:SetBackdropBorderColor(K.C.bordure[1],K.C.bordure[2],K.C.bordure[3],.35) end)
    tile:SetScript("OnClick",function()
        if not entry.preset then return end
        panel:BeginDraft(entry.preset)
    end)
end
refreshGallery()
local originalRefresh=panel.RefreshForm
function panel:RefreshForm()
    if ZG.draft and self.selectedId~=ZG.draft.id then ZG:CancelDraft() end
    originalRefresh(self);refreshPreview()
end
zoneEB:SetScript("OnTextChanged",refreshPreview);subEB:SetScript("OnTextChanged",refreshPreview)
local elapsed=0
panel:HookScript("OnUpdate",function(_,dt)
    elapsed=elapsed+dt
    if elapsed>=.15 then elapsed=0;refreshPreview() end
    if playing then
        local nextTime=progress+dt
        if nextTime>=duration(previewTheme) then
            if loop then nextTime=nextTime%duration(previewTheme) else nextTime=duration(previewTheme);playing=false;playBtn:SetText("Lire l'entrée") end
        end
        seek(nextTime)
    end
end)
panel:HookScript("OnHide",function()
    playing=false;preview:HideBanner()
    if ZG.draft then ZG:CancelDraft();panel.selectedId=nil end
end)
panel:HookScript("OnShow",function() lastPreviewKey=nil;panel:RefreshAll() end)
panel:RefreshAll()
