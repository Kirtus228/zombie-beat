
import fs from 'node:fs';
const { decodePNG, encodePNG, save, blank } = await import('file:///D:/OneDrive/Desktop/Mobidick/games/zombie-beat/tools/pngtool.mjs');
const A='D:/OneDrive/Desktop/Mobidick/games/zombie-beat/assets/';
const W=480,H=270;
const img=blank(W,H,[10,13,24]);
const D=img.data;
const px=(x,y,c)=>{ x=Math.round(x); y=Math.round(y); if(x<0||y<0||x>=W||y>=H) return; const i=(y*W+x)*4; D[i]=c[0];D[i+1]=c[1];D[i+2]=c[2];D[i+3]=255; };
const get=(x,y)=>{ const i=(y*W+x)*4; return [D[i],D[i+1],D[i+2]]; };
const rect=(x0,y0,x1,y1,c)=>{ for(let y=Math.round(y0);y<=Math.round(y1);y++) for(let x=Math.round(x0);x<=Math.round(x1);x++) px(x,y,c); };
const disc=(cx,cy,r,c)=>{ for(let y=-Math.round(r);y<=Math.round(r);y++) for(let x=-Math.round(r);x<=Math.round(r);x++) if(x*x+y*y<=r*r) px(cx+x,cy+y,c); };
const ell=(cx,cy,rx,ry,c)=>{ for(let y=-Math.round(ry);y<=Math.round(ry);y++) for(let x=-Math.round(rx);x<=Math.round(rx);x++){ const dx=x/rx, dy=y/ry; if(dx*dx+dy*dy<=1) px(cx+x,cy+y,c); } };
const add=(x,y,c,a)=>{ x=Math.round(x); y=Math.round(y); if(x<0||y<0||x>=W||y>=H) return; const i=(y*W+x)*4; D[i]=Math.min(255,Math.round(D[i]+c[0]*a)); D[i+1]=Math.min(255,Math.round(D[i+1]+c[1]*a)); D[i+2]=Math.min(255,Math.round(D[i+2]+c[2]*a)); };
let seed=99; const rnd=()=>{ seed=(seed*1103515245+12345)&0x7fffffff; return seed/0x7fffffff; };

// ---- небо ----
const sky=[[0,12,14,26],[24,2,16,42],[40,10,20,52],[56,16,24,62],[70,26,26,58],[84,40,28,50]];
for(const [y0,r,g,b] of sky) rect(0,y0,W-1,Math.min(H-1,y0+16),[r,g,b]);
// зарево у горизонта
for(let y=60;y<196;y++){
  const k=Math.max(0,(y-60)/136);
  for(let x=0;x<W;x++){
    const gx=Math.abs(x-150)/480;
    add(x,y,[120,40,10], 0.35*k*k*(1-gx));
  }
}
// луна
disc(392,50,24,[232,230,208]); disc(400,44,6,[212,209,184]); disc(383,57,4,[212,209,184]);
for(let y=-34;y<=34;y++) for(let x=-34;x<=34;x++){
  const d2=x*x+y*y; if(d2>34*34||d2<=24*24) continue;
  const k=1.0-(Math.sqrt(d2)-24)/10.0;
  add(392+x,50+y,[70,72,50], 0.9*k);
}

// ---- город ----
function skyline(baseY, col, minH, maxH, step, lit){
  for(let x=-10;x<W+10;x+=step){
    const h=minH+Math.floor(rnd()*(maxH-minH));
    const w=step-2;
    rect(x,baseY-h,x+w,baseY,col);
    if(lit){
      for(let wy=baseY-h+5; wy<baseY-5; wy+=8) for(let wx=x+3; wx<x+w-2; wx+=6){
        const r=rnd();
        if(r>0.72) rect(wx,wy,wx+2,wy+2,[240,206,120]);
        else if(r<0.06) rect(wx,wy,wx+2,wy+2,[150,60,40]);
      }
    }
  }
}
skyline(196,[11,16,30],46,96,32,true);
skyline(203,[17,24,44],24,58,24,true);

// ---- дорога ----
rect(0,196,W-1,H-1,[28,29,38]);
rect(0,196,W-1,199,[18,19,27]);
for(let x=-40;x<W;x+=58) rect(x,236,x+26,239,[54,56,68]);
// мокрые пятна
for(let i=0;i<26;i++){ const x=rnd()*W, y=200+rnd()*68; ell(x,y,6+rnd()*10,2+rnd()*2,[23,24,32]); }

// ---- кровь ----
const BLOOD=[122,18,22], BLOOD_D=[74,10,16], BLOOD_L=[168,40,34];
function bloodPool(cx,cy,rx,ry){
  ell(cx,cy,rx,ry,BLOOD_D);
  ell(cx,cy,rx*0.8,ry*0.72,BLOOD);
  for(let i=0;i<Math.round(rx);i++){
    const a=rnd()*Math.PI*2, r=1+rnd()*1.9;
    px(cx+Math.cos(a)*rx*r, cy+Math.sin(a)*ry*r, rnd()>0.5?BLOOD_D:BLOOD);
  }
}
function splatter(cx,cy,n,spread){
  for(let i=0;i<n;i++){
    const a=rnd()*Math.PI*2, r=rnd()*spread;
    px(cx+Math.cos(a)*r, cy+Math.sin(a)*r*0.6, rnd()>0.6?BLOOD_L:BLOOD_D);
  }
}

// ---- трупы ----
function corpse(cx,cy,dir){ // dir=1 вправо
  const SK=[146,174,130], OU=[24,26,22], CLO=[80,80,92];
  bloodPool(cx+8*dir, cy+6, 17, 6);
  // тело: сначала тёмный контур, потом кожа — иначе на асфальте не читается
  for(let i=0;i<24;i++){
    const yy=cy+Math.round(Math.sin(i*0.35)*1)-2;
    for(let k=-3;k<=3;k++) px(cx+i*dir, yy+k, OU);
  }
  for(let i=1;i<23;i++){
    const yy=cy+Math.round(Math.sin(i*0.35)*1)-2;
    for(let k=-2;k<=2;k++) px(cx+i*dir, yy+k, k>0?CLO:SK);
  }
  disc(cx-3*dir, cy-4, 5, OU);
  disc(cx-3*dir, cy-4, 4, SK);
  px(cx-5*dir, cy-5, OU);
  for(let i=0;i<8;i++) px(cx+4*dir+i*dir, cy+4+Math.round(i*0.35), (i%2)?OU:SK);
  for(let i=0;i<8;i++) px(cx+12*dir+i*dir, cy-5-Math.round(i*0.3), (i%2)?OU:SK);
  splatter(cx+8*dir, cy+8, 28, 22);
}

// ---- машина ----
function car(cx, cy, s, kind){
  const BODY = kind==='burn'? [44,40,46] : (kind==='wreck'? [66,70,84] : [52,56,68]);
  const HIL  = kind==='burn'? [70,60,54] : (kind==='wreck'? [102,108,126] : [78,84,100]);
  const GLASS= kind==='burn'? [26,22,26] : [34,44,60];
  const r=(v)=>Math.round(v*s);
  // тень
  ell(cx, cy+r(9), r(26), r(5), [18,18,24]);
  // кузов
  rect(cx-r(24), cy-r(4), cx+r(24), cy+r(5), OUT_CAR(BODY));
  rect(cx-r(24), cy-r(4), cx+r(24), cy+r(1), HIL);
  // кабина
  rect(cx-r(12), cy-r(13), cx+r(11), cy-r(4), BODY);
  rect(cx-r(10), cy-r(12), cx-r(1), cy-r(5), GLASS);
  rect(cx+r(1), cy-r(12), cx+r(9), cy-r(5), GLASS);
  // разбитые стёкла
  if(kind==='burn'||kind==='wreck'){
    for(let i=0;i<5;i++){ const gx=cx-r(10)+r(rnd()*18), gy=cy-r(12)+r(rnd()*7); rect(gx,gy,gx+r(1.5),gy+r(1.5),[10,10,14]); }
  }
  // колёса
  disc(cx-r(14), cy+r(7), r(5), [16,16,20]);
  disc(cx-r(14), cy+r(7), r(2), [50,50,56]);
  disc(cx+r(14), cy+r(7), r(5), [16,16,20]);
  disc(cx+r(14), cy+r(7), r(2), [50,50,56]);
  // фары
  px(cx+r(24), cy-r(2), kind==='burn'?[90,60,30]:[200,190,150]);
}
function OUT_CAR(c){ return c; }

// горящая машина
function flame(cx, baseY, w, h){
  for(let i=0;i<h;i++){
    const t=i/h;
    const wob=0.6+0.4*Math.abs(Math.sin(i*0.9+cx*0.13));
    const half=Math.max(0, Math.round(w*wob*(1-t)));
    for(let x=-half;x<=half;x++){
      const d=half>0?Math.abs(x)/half:0;
      if(d>0.8 && t>0.45) continue;
      const c = t<0.22? [255,238,158] : (t<0.5? [250,166,48] : (t<0.78? [222,92,30] : [150,44,20]));
      px(cx+x, baseY-i, c);
    }
  }
}
function fire(cx, cy, s, t){
  // языки пламени поверх капота и крыши
  flame(cx-8*s, cy-6*s, 11*s, 30*s);
  flame(cx+3*s, cy-5*s, 13*s, 38*s);
  flame(cx+14*s, cy-7*s, 8*s, 22*s);
  flame(cx-16*s, cy-8*s, 6*s, 16*s);
  // искры
  for(let i=0;i<50;i++){
    const a=rnd()*Math.PI*2, r=rnd();
    px(cx+Math.cos(a)*22*s*r, cy-16*s-Math.abs(Math.sin(a))*34*s*r, rnd()>0.5?[255,214,120]:[240,130,40]);
  }
  // световое пятно на асфальте
  for(let y=-12;y<=14;y++) for(let x=-52;x<=52;x++){
    const d=Math.sqrt((x/52)**2+(y/14)**2);
    if(d>=1) continue;
    add(cx+x, cy+8*s+y, [200,96,32], 0.6*(1-d));
  }
  // дым столбом
  for(let i=0;i<80;i++){
    const t2=rnd();
    const sx=cx+(rnd()-0.5)*24*s + t2*26;
    const sy=cy-34*s-t2*70;
    const w=3+rnd()*6;
    ell(sx, sy, w, w*0.7, [22,20,26]);
  }
}

// ---- зомби из кадров пака ----
function frameImage(){
  const cache={};
  return (name)=>{ if(!cache[name]) cache[name]=decodePNG(A+'zombie/'+name+'.png'); return cache[name]; };
}
const frameOf = frameImage();
function zombie(frame, cx, feetY, s, dim){
  const src=frameOf(frame);
  const fw=Math.round(src.w*s), fh=Math.round(src.h*s);
  const tmp={w:fw,h:fh,data:new Uint8Array(fw*fh*4)};
  for(let y=0;y<fh;y++) for(let x=0;x<fw;x++){
    const sx=Math.min(src.w-1,Math.floor(x/s)), sy=Math.min(src.h-1,Math.floor(y/s));
    const si=(sy*src.w+sx)*4;
    if(src.data[si+3]<40) continue;
    const di=(y*fw+x)*4;
    tmp.data[di]=Math.round(src.data[si]*dim);
    tmp.data[di+1]=Math.round(src.data[si+1]*dim);
    tmp.data[di+2]=Math.round(src.data[si+2]*dim);
    tmp.data[di+3]=255;
  }
  const ox=Math.round(cx-fw*0.5), oy=Math.round(feetY-220*s);
  for(let y=0;y<fh;y++) for(let x=0;x<fw;x++){
    const i=(y*fw+x)*4;
    if(tmp.data[i+3]<40) continue;
    px(ox+x, oy+y, [tmp.data[i],tmp.data[i+1],tmp.data[i+2]]);
  }
}

// ---- сборка сцены ----
// 1) дальние зомби у горизонта — плотная толпа силуэтов
const far=[[18,0.17],[34,0.14],[52,0.16],[70,0.12],[86,0.15],[250,0.13],[268,0.16],[286,0.12],[304,0.15],[322,0.13],[340,0.17],[358,0.14],[376,0.16],[394,0.12],[412,0.15],[430,0.13],[448,0.16],[464,0.14]];
for(const [x,s] of far){
  zombie(rnd()>0.5?'walk_4':'idle', x, 202+rnd()*5, s, 0.34);
}
// 2) средний план — уже различимые
zombie('walk_6', 148, 232, 0.36, 0.76);
zombie('punch1_0', 296, 236, 0.38, 0.74);
zombie('idle', 344, 230, 0.34, 0.72);
zombie('walk_4', 258, 228, 0.30, 0.66);
// 3) машины
car(392, 236, 1.05, 'wreck');
car(96, 228, 1.0, 'burn');
// 4) огонь поверх горящей машины
fire(96, 228, 1.0);
// 5) трупы и кровь на дороге
corpse(178, 258, 1);
corpse(268, 246, -1);
corpse(324, 264, 1);
corpse(230, 234, -1);
corpse(140, 244, 1);
corpse(58, 258, 1);
corpse(432, 264, -1);
corpse(388, 252, 1);
// брызги крови на асфальте и у машин
splatter(200, 268, 40, 26);
splatter(300, 258, 34, 22);
splatter(120, 250, 26, 18);
// 6) передний план
zombie('walk_4', 128, 264, 0.74, 1.0);
zombie('idle', 236, 268, 0.82, 1.0);
zombie('punch1_0', 352, 262, 0.64, 1.0);

// 7) дым только над горящей машиной, не пеленой по всей сцене
for(let i=0;i<70;i++){
  const t2=rnd();
  const x=96+(rnd()-0.5)*26 + t2*18;
  const y=200 - t2*74;
  const w=3+rnd()*6;
  ell(x, y, w, w*0.65, [20,19,25]);
}
for(let i=0;i<26;i++){
  const t2=rnd();
  ell(392+(rnd()-0.5)*40, 210-t2*40, 4+rnd()*7, 2+rnd()*3, [19,18,24]);
}
// 8) лёгкая тёплая пелена от пожара на всей дороге
for(let y=196;y<H;y++) for(let x=0;x<W;x++){
  const d=Math.abs(x-96)/230;
  add(x,y,[70,26,8], Math.max(0, 0.30*(1-d)));
}
// затемнение краёв
for(let y=0;y<H;y++) for(let x=0;x<W;x++){
  const edge=Math.min(x,y,W-1-x,H-1-y);
  if(edge>30) continue;
  const k=1.0-edge/30.0;
  const i=(y*W+x)*4;
  D[i]=Math.round(D[i]*(1-0.6*k)); D[i+1]=Math.round(D[i+1]*(1-0.6*k)); D[i+2]=Math.round(D[i+2]*(1-0.6*k));
}
save(A+'ui/splash.png', img);
console.log('saved');
