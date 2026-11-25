import numpy as np, math
from PIL import Image
WY=-0.4
C=(0.0,-31.0); SX=1.35
def smooth(a,b,x):
    t=np.clip((x-a)/(b-a),0,1); return t*t*(3-2*t)
def lake_d(x,z):
    dx=(x-C[0])/SX; dz=z-C[1]
    th=np.arctan2(dz,dx); dist=np.sqrt(dx*dx+dz*dz)
    r=19+2.6*np.sin(2*th+0.5)+2.0*np.sin(3*th+1.7)+1.2*np.sin(5*th+0.3)
    d1=dist-r
    # залив на запад
    bx=(x+27)/1.6; bz=(z+21)
    d2=np.sqrt(bx*bx+bz*bz)-(7+1.2*np.sin(np.arctan2(bz,bx)*3))
    k=4.0
    hh=np.clip(0.5+0.5*(d2-d1)/k,0,1)
    d=d2*(1-hh)+d1*hh-k*hh*(1-hh)
    return d, th
def height(x,z):
    d,th=lake_d(x,z)
    w=2.2+4.5*(0.5+0.5*np.sin(th*2+2.2))
    inside=-3.4*smooth(0,w,-d) - 1.6*smooth(w,w+9,-d)
    hills=(0.55*np.sin(x*0.07)*np.cos(z*0.06)+0.3*np.sin(x*0.13+z*0.11)+0.2*np.cos(x*0.21-z*0.17)+1.05)*0.6
    hills*=smooth(2,12,d)
    lip=0.18*np.exp(-(d/2.5)**2)
    h=np.where(d<0, inside, hills+lip)
    di=np.sqrt((x-7)**2+(z+35)**2)
    h=np.where(di<5.5, np.maximum(h, 0.5-0.75*np.maximum(di-2.5,0)**1.25), h)
    # flat zones
    def rect(cx,cz,hx,hz,m=4):
        ax=np.abs(x-cx)-hx; az=np.abs(z-cz)-hz
        dd=np.maximum(ax,az); return 1-smooth(0,m,dd)
    flat=np.maximum.reduce([rect(13,-4,9,6.5), rect(-10,-3,4.5,3.5), rect(0,6,6,5)])
    return h*(1-flat)
xs=np.arange(-80,81); X,Z=np.meshgrid(xs,xs)
H=height(X.astype(float),Z.astype(float))
img=np.zeros((161,161,3),np.uint8)
img[...,1]=np.where(H>=WY,np.clip(120+H*60,0,255),0)
img[...,2]=np.where(H<WY,np.clip(255+H*40,40,255),0)
img[...,0]=np.where((H<WY+0.15)&(H>WY-0.3),200,0)
# mark shop/market
for (cx,cz,hx,hz) in [(13,-4,8,5.5),(-10,-3,1.5,0.6),(0,-14,1.5,4)]:
    for x in range(int(cx-hx),int(cx+hx)+1):
        for z in (int(cz-hz),int(cz+hz)): img[z+80,x+80]=(255,0,0)
Image.fromarray(img).resize((644,644),Image.NEAREST).save("/tmp/claude-0/-home-claude/f4aac306-6047-5165-93c4-345786c6e3e8/scratchpad/lake.png")
for xx in [0]:
    col=[(z,round(float(height(0.0,float(z))),2)) for z in range(-6,-20,-1)]
    print("x=0 profile", col)
print("depth min", H.min())
# slope stats along shore
