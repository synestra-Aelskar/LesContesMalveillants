// Sources vectorielles adaptees du journal de quete Omega_Hub / BindingEdges.
// Installation : npm install --prefix Outils/.livres-deps sharp
const fs = require('fs'), path = require('path');
const sharp = require('./.livres-deps/node_modules/sharp');
const root = path.join(__dirname, 'sources/livres');
const themes = [
  {id:'chronique', paper:'#e0d2b1', colors:{}, mark:`<g fill="none" stroke="#c3a56b" stroke-width="2"><rect x="179" y="290" width="112" height="88" rx="3"/><path d="M235 296 V372 M189 306 H225 M189 318 H225 M189 330 H225 M245 306 H281 M245 318 H281 M245 330 H281"/><path d="M235 264 L246 277 L235 290 L224 277Z M235 380 L246 393 L235 406 L224 393Z"/></g>`},
  {id:'astral', paper:'#e6dfc8', colors:{'#201a16':'#101a2b','#574130':'#304965','#30251e':'#192d47','#392b22':'#203650','#594432':'#3c526e','#b58a58':'#7391b3','#8d6742':'#486282','#826347':'#617894','#4c392b':'#34485f','#30231c':'#192d47','#34271f':'#203650','#59422f':'#3c526e'}, mark:`<g fill="none" stroke="#c3a56b"><circle cx="235" cy="334" r="68" stroke-width="2"/><circle cx="235" cy="334" r="55"/><path d="M235 251 L245 323 L318 334 L245 345 L235 417 L225 345 L152 334 L225 323Z" stroke-width="2"/><path d="M188 287 L282 381 M282 287 L188 381"/><circle cx="235" cy="334" r="14"/></g>`},
  {id:'herbier', paper:'#ded7b7', colors:{'#201a16':'#151e17','#574130':'#3c533d','#30251e':'#253b2b','#392b22':'#2c4432','#594432':'#4b6346','#b58a58':'#90a06d','#8d6742':'#63734b','#826347':'#687c51','#4c392b':'#3c533d','#30231c':'#253b2b','#34271f':'#2c4432','#59422f':'#4b6346'}, mark:`<g fill="none" stroke="#c3a56b" stroke-width="2"><path d="M235 414 C220 364 249 322 235 260 M234 370 C190 373 177 349 180 328 C215 329 230 344 234 370Z M237 344 C272 343 291 320 288 300 C255 306 240 319 237 344Z M236 310 C207 309 198 290 201 276 C225 281 235 291 236 310Z"/><path d="M202 422 Q235 435 268 422 M221 251 L235 239 L249 251"/></g>`}
];
async function main(){
  for(const theme of themes){
    const out=path.join(root,'rendus',theme.id);fs.mkdirSync(out,{recursive:true});
    let cover=fs.readFileSync(path.join(root,'couverture-reference.svg'),'utf8');
    // Retirer le sceau Omega en conservant le cuir, les coins et le dos.
    cover=cover.replace(/<path[^>]*d="M235[^>]*\/>/g,'').replace(/<circle[^>]*cx="235"[^>]*\/>/g,'').replace(/<path[^>]*d="M214[^>]*\/>/g,'');
    cover=cover.replace('</svg>',theme.mark+'</svg>');
    let book=fs.readFileSync(path.join(root,'ouvert-reference.svg'),'utf8');
    for(const [from,to] of Object.entries(theme.colors)){cover=cover.split(from).join(to);book=book.split(from).join(to);}
    // Papier clair uniforme ; le pli et les tranches du dessin restent visibles.
    book=book.replace(/#ddcda8/g,theme.paper);
    for(const [name,svg,w,h] of [['cover',cover,512,1024],['grimoire',book,2048,2048]]){
      fs.writeFileSync(path.join(out,name+'.svg'),svg);
      const raster=sharp(Buffer.from(svg)).resize(w,h,{fit:'fill'});
      if(name==='cover'){
        // Grain de cuir deterministe : casse les bandes des degrades en DXT5.
        const {data,info}=await raster.ensureAlpha().raw().toBuffer({resolveWithObject:true});
        let seed=1747;
        for(let pixel=0;pixel<data.length;pixel+=4){
          seed=(Math.imul(seed,1664525)+1013904223)>>>0;
          const grain=((seed>>>24)/255-.5)*18;
          for(let c=0;c<3;c++)data[pixel+c]=Math.max(0,Math.min(255,Math.round(data[pixel+c]+grain)));
        }
        await sharp(data,{raw:info}).png().toFile(path.join(out,name+'.png'));
      }else await raster.png().toFile(path.join(out,name+'.png'));
    }
    if(theme.id==='chronique'){
      const note=`<svg xmlns="http://www.w3.org/2000/svg" width="470" height="650"><defs><linearGradient id="p" x2="0" y2="1"><stop stop-color="#f0e6cc"/><stop offset="1" stop-color="#d6c49a"/></linearGradient></defs><path d="M18 12 L452 18 L459 630 L15 639 L21 460 L12 205Z" fill="url(#p)" stroke="#967e52" stroke-width="2"/><path d="M30 28 L438 33 M30 620 L441 612" stroke="#b39c6e" fill="none"/></svg>`;
      await sharp(Buffer.from(note)).resize(512,1024,{fit:'fill'}).png().toFile(path.join(out,'note.png'));
    }
  }
  // Necronicon conserve son illustration d'origine retravaillee : normalisation
  // des marges transparentes et des dimensions uniquement, sans redessin.
  const out=path.join(root,'rendus','necronicon');fs.mkdirSync(out,{recursive:true});
  for(const [source,name,w,h] of [['necronicon-couverture.png','cover',512,1024],['necronicon-ouvert.png','grimoire',2048,2048]]){
    await sharp(path.join(root,source)).trim().resize(w,h,{fit:'fill'}).png().toFile(path.join(out,name+'.png'));
  }
}
main().catch(e=>{console.error(e);process.exit(1)});
