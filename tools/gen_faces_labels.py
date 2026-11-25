from PIL import Image, ImageDraw, ImageFont
import math
OUT="/home/claude/game-fish/art/"
B="/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
def font(s): return ImageFont.truetype(B, s)
S=256
def face(name, eyes="open", brows="flat", mouth="flat", cheeks=False, mustache=False, lashes=False, lips=False, stubble=False):
    im=Image.new("RGBA",(S,S),(0,0,0,0)); d=ImageDraw.Draw(im)
    if stubble:
        for i in range(500):
            import random; random.seed(i)
            x=random.randint(60,196); y=random.randint(170,240)
            if (x-128)**2/70**2+(y-200)**2/45**2<1: d.point((x,y),fill=(60,50,45,140))
    if cheeks:
        for cx in (62,194): d.ellipse([cx-24,150,cx+24,182], fill=(230,80,80,120))
    ey=118
    for cx in (88,168):
        if eyes=="open":
            d.ellipse([cx-17,ey-20,cx+17,ey+20], fill=(255,255,255,255))
            d.ellipse([cx-9,ey-10,cx+9,ey+10], fill=(25,22,20,255))
            d.ellipse([cx-3,ey-7,cx+2,ey-2], fill=(255,255,255,230))
        elif eyes=="half":
            d.chord([cx-17,ey-20,cx+17,ey+20], 0, 180, fill=(255,255,255,255))
            d.chord([cx-9,ey-6,cx+9,ey+12], 0, 180, fill=(25,22,20,255))
            d.line([cx-19,ey,cx+19,ey], fill=(70,40,35,255), width=6)
        elif eyes=="closed":
            d.arc([cx-16,ey-8,cx+16,ey+14], 10, 170, fill=(40,30,28,255), width=6)
        if lashes and eyes!="closed":
            for k in range(3): d.line([cx-12+k*12,ey-20,cx-16+k*14,ey-30], fill=(30,25,25,255), width=4)
    by=82
    for side,cx in ((-1,88),(1,168)):
        if brows=="flat": d.line([cx-20,by,cx+20,by], fill=(60,40,30,255), width=9)
        elif brows=="angry": d.line([cx-20,by-10*side*-1,cx+20,by+10*side*-1], fill=(50,35,25,255), width=11)
        elif brows=="up": d.arc([cx-22,by-6,cx+22,by+18],200,340, fill=(60,40,30,255), width=8)
    my=190
    col=(150,40,45,255) if lips else (70,35,30,255)
    if mouth=="flat": d.line([100,my,156,my], fill=col, width=8)
    elif mouth=="smile": d.arc([92,my-30,164,my+14], 20, 160, fill=col, width=8)
    elif mouth=="frown": d.arc([96,my-2,160,my+30], 200, 340, fill=col, width=8)
    elif mouth=="drunk":
        pts=[(96,my),(112,my+8),(128,my-2),(144,my+10),(160,my+2)]; d.line(pts, fill=col, width=8, joint="curve")
    elif mouth=="o": d.ellipse([116,my-12,140,my+14], fill=col)
    if mustache:
        d.chord([84,my-36,128,my-4], 180, 360, fill=(70,50,35,255)); d.chord([128,my-36,172,my-4], 180, 360, fill=(70,50,35,255))
        d.rectangle([90,my-22,166,my-14], fill=(70,50,35,255))
    im.save(OUT+"faces/"+name+".png")
face("neutral"); face("smile", mouth="smile"); face("drunk", eyes="half", mouth="drunk", cheeks=True)
face("sleep", eyes="closed", mouth="o", cheeks=True); face("guard", brows="angry", mouth="frown", stubble=True)
face("guard_sleep", eyes="closed", brows="flat", mouth="o", stubble=True)
face("trader", mouth="smile", mustache=True, brows="up"); face("trader_drunk", eyes="half", mouth="drunk", cheeks=True, mustache=True)
face("trader_sleep", eyes="closed", mouth="o", cheeks=True, mustache=True)
face("cashier", lashes=True, lips=True, mouth="flat", brows="up")
face("angry", brows="angry", mouth="frown"); face("player_b", stubble=True, mouth="smile")

def label(name, text, bg, fg=(255,255,255), sub="", stripe=None, w=512, h=160):
    im=Image.new("RGB",(w,h),bg); d=ImageDraw.Draw(im)
    if stripe: d.rectangle([0,h*0.72,w,h], fill=stripe); d.rectangle([0,0,w,h*0.12], fill=stripe)
    size=52
    while d.textlength(text,font=font(size))>w/2*0.86: size-=2
    f=font(size)
    tw=d.textlength(text,font=f); d.text(((w/2-tw)/2, h*0.22), text, font=f, fill=fg)
    d.text(((w/2-tw)/2+w/2, h*0.22), text, font=f, fill=fg)
    if sub:
        f2=font(22); sw=d.textlength(sub,font=f2)
        for o in (0,w/2): d.text(((w/2-sw)/2+o, h*0.56), sub, font=f2, fill=fg)
    im.save(OUT+"labels/"+name+".png")
label("beer","ПОПЛАВОК",(220,170,40),(60,30,10),"пиво светлое",(40,90,160))
label("strong_beer","КАРАСЬ",(90,40,20),(250,220,120),"крепкое 8%",(200,150,40))
label("cider","ЯБЛОЧКО",(120,180,60),(255,255,255),"сидр",(200,40,40))
label("port","ТРИ ЧЕРВЯ",(240,230,210),(120,20,30),"портвейн 777",(120,20,30))
label("wine","ШАТО КАМЫШ",(60,20,40),(230,200,150),"вино столовое",(180,150,90))
label("vodka","ГЛУБИНА",(240,245,250),(20,60,140),"водка 40%",(20,60,140))
label("cognac","БЕРЕЖОК",(30,20,15),(220,170,70),"коньяк ***",(160,110,40))
label("noodles","БОМЖ-ПАКЕТ",(230,40,30),(255,240,60),"лапша",(255,240,60))
label("crackers","СУХАРИКИ",(250,200,30),(120,30,20),"с хреном",(120,30,20))
label("worms","ЧЕРВИ",(90,60,40),(250,220,180),"живые!",(200,120,60))
label("maggots","ОПАРЫШ",(230,230,220),(80,60,40),"отборный",(160,40,40))
label("dough","ТЕСТО",(250,240,200),(140,90,30),"ароматное",(200,120,40))
label("corn","КУКУРУЗА",(250,210,40),(30,100,40),"сладкая",(30,100,40))

def sign(name, text, bg, fg, w=1024, h=220, stripe=None, logo=None):
    im=Image.new("RGB",(w,h),bg); d=ImageDraw.Draw(im)
    if stripe: d.rectangle([0,h-36,w,h], fill=stripe); d.rectangle([0,0,w,14], fill=stripe)
    x0=40
    if logo:
        d.ellipse([30,30,190,190], fill=(255,255,255)); f=font(130); d.text((70,22), logo, font=f, fill=bg); x0=220
    size=130
    while d.textlength(text,font=font(size))>(w-x0)*0.92: size-=4
    f=font(size); tw=d.textlength(text,font=f)
    d.text((x0+(w-x0-tw)/2, (h-36-130)/2+8), text, font=f, fill=fg)
    im.save(OUT+"textures/"+name+".png")
sign("sign_shop","ШЕСТЁРОЧКА",(205,30,35),(255,255,255),stripe=(40,150,60),logo="6")
sign("sign_market","РЫНОК",(40,90,170),(255,255,255),stripe=(240,200,40))

def icon(name, draw):
    im=Image.new("RGBA",(64,64),(0,0,0,0)); d=ImageDraw.Draw(im); draw(d); im.save(OUT+"ui/"+name+".png")
def heart(d):
    d.ellipse([8,12,34,38], fill=(235,70,70)); d.ellipse([30,12,56,38], fill=(235,70,70)); d.polygon([(9,30),(55,30),(32,56)], fill=(235,70,70))
def food(d):
    d.ellipse([10,10,44,44], fill=(200,120,60)); d.rectangle([38,38,48,58], fill=(240,230,210)); d.ellipse([42,52,54,62], fill=(240,230,210))
def toilet(d):
    d.polygon([(32,6),(14,36),(50,36)], fill=(240,200,60)); d.ellipse([14,22,50,58], fill=(240,200,60))
def drunk(d):
    d.rectangle([24,24,40,58], fill=(120,80,30)); d.rectangle([28,8,36,26], fill=(120,80,30)); d.rectangle([24,34,40,46], fill=(240,200,80))
def coin(d):
    d.ellipse([8,8,56,56], fill=(240,190,50)); d.ellipse([16,16,48,48], outline=(190,140,30), width=4)
for n,f in [("heart",heart),("food",food),("toilet",toilet),("drunk",drunk),("coin",coin)]: icon(n,f)
print("art ok")
