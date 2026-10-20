__declencher("PLAYER_LOGIN")
local IC = LCM.IC
local d = {coutBase=3, baremeCommun=true, declencheursInclus={critique_recu=true}}
local p = {frequence={type="combat",nombre=1},duree={type="tours",nombre=1},declencheur="critique_recu"}
assert(IC.Cout(d,p)==3, "declencheur intrinseque inclus")
p.declencheur="degats_recus"
assert(IC.Cout(d,p)==4)
p.frequence={type="sans_limite"}
assert(IC.Cout(d,p)==10)
p.duree={type="rounds",nombre=1}
assert(IC.Cout(d,p)==9)
p.duree={type="tours",nombre=2}
assert(IC.Cout(d,p)==12)
p.frequence={type="heures24",nombre=1}
p.duree={type="rounds",nombre=1}
p.declencheur="critique_recu"
assert(IC.Cout(d,p)==1, "base plus les deux rabais")
d.coutBase=2
assert(IC.Cout(d,p)==1, "plancher commun")
d.instantane=true
assert(IC.Cout(d,p)==nil, "pas de rabais de duree sur un soin instantane")
p.duree={type="instantanee"}
assert(IC.Cout(d,p)==1)
p.declencheur="inconnu"
assert(IC.Cout(d,p)==nil)
p.declencheur=nil
p.frequence={type="combat",nombre=3}
assert(IC.Cout(d,p)==nil, "pas de frequence gratuite sans bareme")
print("TOUT PASSE — barèmes IC configurables")
