__declencher('PLAYER_LOGIN')
local person=__personnage();LCM.Personnages.Actif=function() return person end
LCM.IsMaster=function() return false end
local Z=LCM.Crossings
local start=os.clock()
for i=1,10000 do Z:MarquerVu(994,i,.5,60) end
local total=os.clock()-start
local state=Z:PreparerBrouillard(994)
local rows,intervals=0,0
for _,row in pairs(state.rows) do rows=rows+1;intervals=intervals+#row/2 end
assert(rows>=119 and rows<=121 and intervals==rows,'historique non compacte')
local rev=state.revision
for i=1,10000 do Z:MarquerVu(994,i,.5,60) end
assert(state.revision==rev,'revisiter modifie la surface')
local function copy(t) local out={} for k,v in pairs(t) do out[k]=type(v)=='table' and copy(v) or v end return out end
local data=LCM_CrossingsChar.parPerso[person.id].brouillard
data[994]=copy(data[994])
local reloaded=Z:PreparerBrouillard(994)
assert(reloaded~=state and reloaded.ready and reloaded.revision==rev,'rechargement rejoue historique')
assert(Z:EstVu(994,5000,.5),'savoir perdu au rechargement')
print(string.format('BENCH 10000 pas: %.3f s; surface sauvegardee: %d lignes / %d intervalles',total,rows,intervals))
print('TOUT PASSE')
