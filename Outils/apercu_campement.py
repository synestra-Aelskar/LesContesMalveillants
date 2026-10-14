"""Controle visuel hors jeu : execute le Lua et compose les BLP effectivement utilises.

Sorties temporaires uniquement. Ce rendu ne remplace pas une verification en jeu.
"""
import math
import os
from pathlib import Path
import sys
import tempfile

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'Banc'))
import lcm_bench
from PIL import Image, ImageDraw


def apercu(lua, instant):
    f = lua.globals().LCM.UI.NuitCampement.frame
    f.origine = lua.globals().GetTime() - instant
    f.GetScript(f, 'OnUpdate')(f, 0)
    facteur = 3
    image = Image.new('RGBA', (384*facteur, 216*facteur), (0,0,0,255))
    for nom in ('ciel', 'astres', 'terre', 'tente', 'feu'):
        parent = f[nom]
        ox = oy = 0
        if nom == 'tente':
            ox, oy = parent.__points[1][4], parent.__points[1][5]
        for _, texture in parent.pool.items():
            if texture.__shown is False:
                continue
            point = texture.__points[1]
            x, y = ox+point[4], oy+point[5]
            w, h = texture.__w, texture.__h
            if texture.__texture:
                fichier = ROOT / texture.__texture.replace('Interface\\AddOns\\', '').replace('\\', '/')
                sprite = Image.open(fichier).convert('RGBA')
                uv = texture.__texCoord
                if uv and uv[1] == 1:
                    sprite = sprite.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                sprite = sprite.resize((round(w*facteur), round(h*facteur)), Image.Resampling.LANCZOS)
                teinte = texture.__vertex
                if teinte:
                    canaux = sprite.split()
                    sprite = Image.merge('RGBA', tuple(canaux[i].point(lambda v, t=teinte[i+1]: round(v*t)) for i in range(3))+(canaux[3],))
            else:
                c = texture.__color
                sprite = Image.new('RGBA', (max(1,round(w*facteur)),max(1,round(h*facteur))), tuple(round(c[i]*255) for i in range(1,5)))
            alpha = texture.GetAlpha(texture)*parent.GetAlpha(parent)
            sprite.putalpha(sprite.getchannel('A').point(lambda v: round(v*alpha)))
            angle = texture.__rotation or 0
            if angle:
                sprite = sprite.rotate(math.degrees(angle), Image.Resampling.BICUBIC, expand=True)
            centre_x = (x+w/2)*facteur
            centre_y = (216-y-h/2)*facteur
            image.alpha_composite(sprite, (round(centre_x-sprite.width/2), round(centre_y-sprite.height/2)))
    return image.convert('RGB')


def main():
    os.chdir(ROOT)
    lua = lcm_bench.charger(str(ROOT/'Banc/scenarios/lcm_test_cinematique_nuit.lua'))
    if lua is None:
        raise RuntimeError('Echec du scenario Lua')
    lua.execute('UIParent:SetSize(1920,1080); assert(LCM.UI.NuitCampement.Lancer("apercu-final",12345,GetServerTime()))')
    destination = Path(tempfile.gettempdir()) / 'lcm-apercu-campement'
    destination.mkdir(exist_ok=True)
    moments = (3, 6, 9, 12, 14)
    planche = Image.new('RGB', (1152, (648+28)*len(moments)))
    for i, instant in enumerate(moments):
        image = apercu(lua, instant)
        image.save(destination/f'nuit-{instant}.png', optimize=True)
        planche.paste(image, (0,i*676+28))
        ImageDraw.Draw(planche).text((12,i*676+7), f'{instant} secondes', fill='white')
    planche.save(destination/'sequence.jpg', quality=90)
    print(destination/'sequence.jpg')


if __name__ == '__main__':
    main()
