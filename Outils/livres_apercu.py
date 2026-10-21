"""Composition de controle : BLP decodes et positions/textes du lecteur Lua.

Ce rendu Pillow n'est pas une capture du client WoW. Il permet de controler
les marges, les polices et les ressources issues du meme code que le lecteur.
Lancer avec Banc/.venv/Scripts/python.exe Outils/livres_apercu.py.
"""
from pathlib import Path
import sys, re
from PIL import Image, ImageDraw, ImageFont, ImageChops

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'Banc'))
import lcm_bench

OUT = ROOT / 'Banc/apercus/livres'
OUT.mkdir(parents=True, exist_ok=True)
lua = lcm_bench.charger(str(ROOT / 'Banc/scenarios/lcm_test_livres_animation.lua'))
assert lua is not None
lua.execute('''
__apercuLivre = {id="apercu", label="Chroniques du voyage", format="livre",
couverture={titre="Chroniques du voyage", texte="Récits des terres oubliées\\nVolume premier"},
pages={
 {titre="Le départ", texte="À l’aube, la cité s’éveillait sous une brume légère. Les voyageurs avaient quitté les remparts avant le premier appel des cloches.\\n\\nSur la route, chacun emportait un souvenir et une promesse. Le chemin traversait les collines, puis disparaissait au pied des grandes forêts.\\n\\nNous avons consigné dans ces pages les lieux rencontrés, les visages et les histoires que le temps aurait pu effacer."},
 {titre="Au-delà des collines", texte="Le vieux pont marquait la frontière des terres connues. Sur sa pierre la plus haute, une inscription demeurait lisible :\\n\\n« Nul voyage ne s’achève tant qu’il reste quelqu’un pour en raconter l’histoire. »\\n\\nNous avons poursuivi notre route vers le nord. À la nuit tombée, les feux du premier village dessinaient une constellation au creux de la vallée."}}
}
''')
anchors = {'TOPLEFT':(0,0),'TOP':(.5,0),'TOPRIGHT':(1,0),'LEFT':(0,.5),
           'CENTER':(.5,.5),'RIGHT':(1,.5),'BOTTOMLEFT':(0,1),'BOTTOM':(.5,1),'BOTTOMRIGHT':(1,1)}

def size(obj):
    allpoints = obj['__allPoints']
    if allpoints is not None:
        return size(allpoints)
    return float(obj['__w'] or 0), float(obj['__h'] or 0)

def origin(obj):
    if obj['__name'] == 'LCM_lecture_livre':
        return 0., 0.
    allpoints = obj['__allPoints']
    if allpoints is not None:
        return origin(allpoints)
    p = obj['__points'][1]
    if p is None:
        return origin(obj['parent'])
    target = p[2] or obj['parent']
    tx, ty = origin(target)
    tw, th = size(target)
    w, h = size(obj)
    ax, ay = anchors[p[1]]
    bx, by = anchors[p[3] or p[1]]
    return tx+tw*bx-w*ax+(p[4] or 0), ty+th*by-h*ay-(p[5] or 0)

def font_of(obj):
    spec = obj['__font']
    rel = spec[1].replace('Interface\\AddOns\\','').replace('\\','/')
    return ImageFont.truetype(str(ROOT / rel), round(spec[2]))

def lines(text, font, width):
    result=[]
    for paragraph in text.split('\n'):
        line=''
        for word in paragraph.split(' '):
            trial=(line+' '+word).strip()
            if line and font.getlength(trial)>width:
                result.append(line); line=word
            else: line=trial
        result.append(line)
    return result

def text(canvas, obj, clip=None):
    value=re.sub(r'\|c[0-9a-fA-F]{8}|\|r','',str(obj['__text'] or ''))
    if not value: return
    x,y=origin(obj); w,h=size(obj)
    font=font_of(obj)
    rows=lines(value,font,w)
    ink=obj['__textColor']
    color=tuple(round(255*ink[i]) for i in (1,2,3))+(255,)
    layer=Image.new('RGBA',canvas.size)
    d=ImageDraw.Draw(layer)
    advance=font.size+4
    if obj['__justifyV']=='MIDDLE':
        y+=(h-len(rows)*advance)/2
    for row in rows:
        left=x+(w-font.getlength(row))/2 if obj['__justifyH']=='CENTER' else x
        d.text((round(left),round(y)),row,font=font,fill=color,anchor='lt')
        y+=advance
    if clip:
        crop=layer.crop(clip);canvas.alpha_composite(crop,(clip[0],clip[1]))
    else: canvas.alpha_composite(layer)

def render(f):
    canvas=Image.new('RGBA',(940,650),'#151917')
    for key in ('ouvert','couverture','note'):
        s=f[key]
        if not s['__shown']: continue
        x,y=map(round,origin(s));w,h=map(round,size(s))
        texture=s['image']
        path=texture['__texture'].replace('Interface\\AddOns\\','').replace('\\','/')
        im=Image.open(ROOT/path).convert('RGBA').resize((w,h),Image.Resampling.LANCZOS)
        tint=texture['__vertex']
        if tint:
            rgb=Image.new('RGBA',im.size,tuple(round(255*tint[i]) for i in (1,2,3))+(255,))
            im=ImageChops.multiply(im,rgb)
        canvas.alpha_composite(im,(x,y))
        pages=[f['gauche'],f['droite']] if key=='ouvert' else [s['page']]
        for p in pages:
            if not p['__shown']: continue
            text(canvas,p['titre']);text(canvas,p['numero'])
            zx,zy=map(round,origin(p['zone']));zw,zh=map(round,size(p['zone']))
            text(canvas,p['texte'],(zx,zy,zx+zw,zy+zh))
    for key in ('precedent','suivant','fermer','zoom'):
        if f[key]['__shown']:text(canvas,f[key]['label'])
    if f['compteur']['__shown']:text(canvas,f['compteur'])
    return canvas.convert('RGB')

covers=[]
for theme in ('chronique','astral','herbier','necronicon'):
    if theme == 'necronicon':
        lua.execute('__apercuLivre.label="Necronicon"; __apercuLivre.couverture.titre="Necronicon"; __apercuLivre.couverture.texte="Les Contes Malveillants\\nArchives des ombres"')
    lua.execute(f'__apercuLivre.modele="{theme}"; LCM.UI.Livres.Apercu(__apercuLivre); __avancer(2)')
    f=lua.globals().LCM.UI.Livres.frame
    cover=render(f);cover.save(OUT/f'{theme}-couverture.png')
    covers.append(cover.crop((225,0,715,650)))
    lua.execute('LCM.UI.Livres.frame:Tourner(1); __avancer(1.6)')
    render(f).save(OUT/f'{theme}-lecture.png')
sheet=Image.new('RGB',(1960,700),'#151917')
d=ImageDraw.Draw(sheet)
font=ImageFont.truetype('C:/Windows/Fonts/georgia.ttf',19)
for i,(cover,label) in enumerate(zip(covers,('CHRONIQUE','ATLAS ASTRAL','HERBIER','NECRONICON'))):
    sheet.paste(cover,(490*i,40));d.text((490*i+245,12),label,font=font,fill='#e4c78e',anchor='mt')
sheet.save(OUT/'quatre-modeles.png')
print('Apercus :',OUT)
