# Новые картинки v0.4: этикетки, вывески, текстуры кирпича/ковра/обоев, фото собаки, лица.
import numpy as np, math, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter
OUT="/home/claude/game-fish/art/"
B="/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
R="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
def font(s, bold=True): return ImageFont.truetype(B if bold else R, s)
rng=np.random.default_rng(11)
def noise(n, falloff=1.6):
    w=rng.normal(size=(n,n)); F=np.fft.fft2(w)
    fy=np.fft.fftfreq(n)[:,None]; fx=np.fft.fftfreq(n)[None,:]
    f=np.sqrt(fx**2+fy**2); f[0,0]=1; F*=1/(f**falloff); F[0,0]=0
    r=np.real(np.fft.ifft2(F)); return (r-r.min())/(r.max()-r.min())
def save(arr, name): Image.fromarray(np.clip(arr,0,255).astype(np.uint8)).save(OUT+name)

# ---------- этикетки (как в gen_faces_labels.py)
def label(name, text, bg, fg=(255,255,255), sub="", stripe=None, w=512, h=160):
    im=Image.new("RGB",(w,h),bg); d=ImageDraw.Draw(im)
    if stripe: d.rectangle([0,h*0.72,w,h], fill=stripe); d.rectangle([0,0,w,h*0.12], fill=stripe)
    size=52
    while d.textlength(text,font=font(size))>w/2*0.86: size-=2
    f=font(size); tw=d.textlength(text,font=f)
    for o in (0,w/2): d.text(((w/2-tw)/2+o, h*0.22), text, font=f, fill=fg)
    if sub:
        f2=font(22); sw=d.textlength(sub,font=f2)
        for o in (0,w/2): d.text(((w/2-sw)/2+o, h*0.56), sub, font=f2, fill=fg)
    im.save(OUT+"labels/"+name+".png")
label("samogon","ДЕД МИТЯ",(235,225,200),(90,50,20),"самогон 45%",(120,70,30))
label("champagne","ПУЗЫРЬ",(20,70,35),(240,210,120),"шампанское",(200,170,70))
label("seeds","СЕМЕЧКИ",(240,200,40),(30,30,30),"от бабушки",(30,30,30))
def pack(name, text, bg, fg, sub):
    w,h=256,384; im=Image.new("RGB",(w,h),bg); d=ImageDraw.Draw(im)
    d.rectangle([0,0,w,60], fill=(245,245,240)); d.rectangle([0,h-90,w,h], fill=(20,20,20))
    size=60
    while d.textlength(text,font=font(size))>w*0.9: size-=2
    tw=d.textlength(text,font=font(size)); d.text(((w-tw)/2,120),text,font=font(size),fill=fg)
    sw=d.textlength(sub,font=font(22)); d.text(((w-sw)/2,200),sub,font=font(22),fill=fg)
    t="КУРЕНИЕ УБИВАЕТ"; tw=d.textlength(t,font=font(19)); d.text(((w-tw)/2,h-58),t,font=font(19),fill=(255,255,255))
    im.save(OUT+"labels/"+name+".png")
pack("cigs","ОКУРОК",(200,30,25),(255,255,255),"сигареты")
pack("belomor","БЕЛОМОР",(60,110,180),(255,255,255),"папиросы")

# ---------- вывески
def sign(name, text, bg, fg, w=1024, h=220, stripe=None, sub=None, glow=None):
    im=Image.new("RGB",(w,h),bg); d=ImageDraw.Draw(im)
    if stripe: d.rectangle([0,h-30,w,h], fill=stripe); d.rectangle([0,0,w,12], fill=stripe)
    size=100 if sub else 130
    while d.textlength(text,font=font(size))>w*0.9: size-=4
    tw=d.textlength(text,font=font(size)); y=(h-size)/2-(18 if sub else 8)
    if glow:
        g=Image.new("RGB",(w,h),(0,0,0)); gd=ImageDraw.Draw(g); gd.text(((w-tw)/2,y),text,font=font(size),fill=glow)
        g=g.filter(ImageFilter.GaussianBlur(10)); im=Image.composite(g, im, Image.new("L",(w,h),110)); d=ImageDraw.Draw(im)
    d.text(((w-tw)/2,y),text,font=font(size),fill=fg)
    if sub:
        sw=d.textlength(sub,font=font(34)); d.text(((w-sw)/2,h-80),sub,font=font(34),fill=fg)
    im.save(OUT+"textures/"+name+".png")
sign("sign_liquor","БУХЛО & ТАБАК",(25,30,35),(250,200,60),stripe=(200,40,40),sub="круглосуточно")
sign("sign_casino","ЗОЛОТОЙ КАРАСЬ",(40,10,40),(255,215,80),sub="К А З И Н О",glow=(255,120,40))
sign("sign_thimbles","НАПЁРСТКИ",(120,30,20),(255,240,200),sub="угадай — удвой! (нет)")
sign("sign_fandomat","ФАНДОМАТ",(30,120,60),(255,255,255),w=512,h=160,sub="12 ₽ за бутылку")
sign("sign_job","ТРЕБУЮТСЯ ГРУЗЧИКИ",(240,235,220),(30,30,30),w=1024,h=260,sub="45 ₽ за коробку · с коробкой на склад")
sign("sign_closed","ЗАКРЫТО",(180,20,20),(255,255,255),w=512,h=180,sub="охранник в отключке")
sign("sign_house","НАШ ДОМ",(90,60,40),(250,235,200),w=512,h=160)

# ---------- текстуры
N=512
def brick(name, base, mortar, bw=64, bh=28):
    im=np.zeros((N,N,3)); im[:]=mortar
    n=noise(N,1.2)
    for row in range(N//bh+1):
        off=(bw//2) if row%2 else 0
        for col in range(-1,N//bw+1):
            c=np.array(base)*(0.82+0.3*rng.random())
            x0=col*bw+off+2; y0=row*bh+2
            x1=min(x0+bw-4,N); y1=min(y0+bh-4,N)
            if x1<=0 or y0>=N: continue
            im[y0:y1, max(x0,0):x1]=c
    im*=(0.85+0.25*n[...,None])
    save(im,"textures/"+name+".png")
brick("brick",[160,70,50],[200,190,175])
brick("brick_dark",[70,60,70],[40,35,40])
c=noise(N,0.9); carpet=np.zeros((N,N,3)); carpet[:]=[140,20,30]; carpet*=(0.8+0.35*c[...,None])
yy,xx=np.mgrid[0:N,0:N]; pat=((np.sin(xx/16.0)*np.sin(yy/16.0))>0.6)
carpet[pat]=[200,160,60]; save(carpet,"textures/carpet.png")
wp=np.zeros((N,N,3)); wp[:]=[205,190,150]; wp*=(0.92+0.1*noise(N,1.0)[...,None])
stripe=(xx//24)%2==0; wp[stripe]*=0.93
flower=((xx%48-24)**2+(yy%48-24)**2)<30; wp[flower]=[160,110,90]
save(wp,"textures/wallpaper.png")
lino=np.zeros((N,N,3)); lino[:]=[150,110,70]; lino*=(0.85+0.25*noise(N,1.3)[...,None]); save(lino,"textures/linoleum.png")
road=np.zeros((N,N,3)); road[:]=[70,70,72]; road*=(0.8+0.35*noise(N,1.0)[...,None]); road+=rng.normal(0,8,(N,N,1))
cr=noise(N,0.5)>0.82; road[cr]*=0.7; save(road,"textures/road.png")
felt=np.zeros((N,N,3)); felt[:]=[20,110,55]; felt*=(0.9+0.15*noise(N,0.9)[...,None]); save(felt,"textures/felt.png")
metal=np.zeros((N,N,3)); metal[:]=[150,155,160]; metal*=(0.9+0.12*noise(N,0.7)[...,None]); save(metal,"textures/metal.png")

# ---------- фото собаки
w,h=256,320; im=Image.new("RGB",(w,h),(235,225,200)); d=ImageDraw.Draw(im)
d.rectangle([14,14,w-14,h-60],fill=(150,190,220))
d.rectangle([14,h-150,w-14,h-60],fill=(110,170,80))
cx,cy=128,150
d.ellipse([cx-62,cy-50,cx+62,cy+70],fill=(190,130,70))   # голова
d.ellipse([cx-82,cy-40,cx-40,cy+40],fill=(120,75,40)); d.ellipse([cx+40,cy-40,cx+82,cy+40],fill=(120,75,40))  # уши
d.ellipse([cx-36,cy+10,cx+36,cy+66],fill=(235,215,185))  # морда
d.ellipse([cx-14,cy+14,cx+14,cy+34],fill=(30,25,25))     # нос
for ex in (cx-26,cx+26):
    d.ellipse([ex-10,cy-14,ex+10,cy+6],fill=(255,255,255)); d.ellipse([ex-6,cy-10,ex+6,cy+2],fill=(25,20,20))
d.arc([cx-20,cy+30,cx+20,cy+58],20,160,fill=(80,30,30),width=4)
d.ellipse([cx-8,cy+48,cx+8,cy+70],fill=(230,90,110))     # язык
t="Шарик ♥ 2019"; tw=d.textlength(t,font=font(24,False)); d.text(((w-tw)/2,h-48),t,font=font(24,False),fill=(60,40,30))
im.save(OUT+"textures/dog_photo.png")

# ---------- лица
S=256
def face(name, eyes="open", brows="flat", mouth="flat", cheeks=False, mustache=False, lashes=False, lips=False, stubble=False, glasses=False, gold=False):
    im=Image.new("RGBA",(S,S),(0,0,0,0)); d=ImageDraw.Draw(im)
    if stubble:
        for i in range(500):
            random.seed(i); x=random.randint(60,196); y=random.randint(170,240)
            if (x-128)**2/70**2+(y-200)**2/45**2<1: d.point((x,y),fill=(60,50,45,140))
    if cheeks:
        for cx in (62,194): d.ellipse([cx-24,150,cx+24,182], fill=(230,80,80,120))
    ey=118
    for cx in (88,168):
        if eyes=="open":
            d.ellipse([cx-17,ey-20,cx+17,ey+20], fill=(255,255,255,255)); d.ellipse([cx-9,ey-10,cx+9,ey+10], fill=(25,22,20,255))
            d.ellipse([cx-3,ey-7,cx+2,ey-2], fill=(255,255,255,230))
        elif eyes=="sly":
            d.chord([cx-17,ey-12,cx+17,ey+20], 0, 180, fill=(255,255,255,255)); d.ellipse([cx-3,ey,cx+11,ey+14], fill=(25,22,20,255))
            d.line([cx-19,ey+2,cx+19,ey-2], fill=(70,40,35,255), width=6)
        if lashes:
            for k in range(3): d.line([cx-12+k*12,ey-20,cx-16+k*14,ey-30], fill=(30,25,25,255), width=4)
        if glasses:
            d.ellipse([cx-26,ey-24,cx+26,ey+24], outline=(20,20,20,255), width=6)
    if glasses: d.line([114,ey,142,ey], fill=(20,20,20,255), width=6)
    by=82
    for side,cx in ((-1,88),(1,168)):
        if brows=="flat": d.line([cx-20,by,cx+20,by], fill=(60,40,30,255), width=9)
        elif brows=="angry": d.line([cx-20,by+10*side,cx+20,by-10*side], fill=(50,35,25,255), width=11)
        elif brows=="up": d.arc([cx-22,by-6,cx+22,by+18],200,340, fill=(60,40,30,255), width=8)
    my=190; col=(150,40,45,255) if lips else (70,35,30,255)
    if mouth=="flat": d.line([100,my,156,my], fill=col, width=8)
    elif mouth=="smile": d.arc([92,my-30,164,my+14], 20, 160, fill=col, width=8)
    elif mouth=="grin":
        d.chord([92,my-26,164,my+20], 0, 180, fill=(255,255,255,255)); d.arc([92,my-26,164,my+20], 0, 180, fill=col, width=6)
        if gold: d.rectangle([132,my-4,146,my+10], fill=(240,190,40,255))
    if mustache:
        d.chord([84,my-36,128,my-4], 180, 360, fill=(40,30,25,255)); d.chord([128,my-36,172,my-4], 180, 360, fill=(40,30,25,255))
    im.save(OUT+"faces/"+name+".png")
face("gosha", eyes="sly", brows="angry", mouth="grin", stubble=True, gold=True)
face("croupier", brows="up", mouth="smile", mustache=True)
face("dealer_f", lashes=True, lips=True, mouth="smile", brows="up")
face("dealer_m", glasses=True, mouth="flat")
face("seller", lashes=True, lips=True, mouth="flat", brows="angry")
face("hurt", eyes="sly", brows="up", mouth="flat", cheeks=True)
print("v4 art ok")
