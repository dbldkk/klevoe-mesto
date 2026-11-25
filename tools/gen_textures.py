import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
OUT="/home/claude/game-fish/art/"
rng=np.random.default_rng(7)
def noise(n, falloff=1.6, lo=1):
    w = rng.normal(size=(n,n))
    F = np.fft.fft2(w)
    fy = np.fft.fftfreq(n)[:,None]; fx = np.fft.fftfreq(n)[None,:]
    f = np.sqrt(fx**2+fy**2); f[0,0]=1
    F *= 1/(f**falloff); F[0,0]=0
    r = np.real(np.fft.ifft2(F)); r=(r-r.min())/(r.max()-r.min()); return r
def col(a, c1, c2):
    a=a[...,None]; return c1*(1-a)+c2*a
def save(arr, name):
    Image.fromarray(np.clip(arr,0,255).astype(np.uint8)).save(OUT+name)
N=512
# grass
n1=noise(N,1.4); n2=noise(N,0.6)
g=col(n1, np.array([72,128,40.]), np.array([128,182,62.]))
g*= (0.85+0.3*n2[...,None])
img=Image.fromarray(np.clip(g,0,255).astype(np.uint8)); d=ImageDraw.Draw(img)
for _ in range(9000):
    x,y=rng.integers(0,N,2); l=rng.integers(4,11); c=tuple(int(v) for v in (rng.integers(80,160), rng.integers(140,215), rng.integers(35,80)))
    dx=rng.integers(-2,3)
    for ox in (0,-N,N):
        for oy in (0,-N,N):
            d.line([(x+ox,y+oy),(x+ox+dx,y+oy-l)], fill=c, width=1)
img.save(OUT+"textures/grass.png")
# sand
s=col(noise(N,1.2), np.array([206,184,132.]), np.array([240,222,170.]))
s+= rng.normal(0,7,(N,N,1)); save(s,"textures/sand.png")
# dirt / lake bottom
dd=col(noise(N,1.3), np.array([70,58,40.]), np.array([118,98,68.]))
dd*=(0.8+0.35*noise(N,0.5)[...,None]); dd+=rng.normal(0,6,(N,N,1)); save(dd,"textures/dirt.png")
# planks (horizontal boards along x)
p=np.zeros((N,N,3)); boards=8; h=N//boards
grain=noise(N,0.9)
for b in range(boards):
    base=np.array([132,92,56.])*(0.82+0.3*rng.random())
    y0=b*h
    stripe=np.sin(np.linspace(0,40,N)[None,:]+ grain[y0:y0+h,:]*12 + rng.random()*6)*0.5+0.5
    blk=base*(0.85+0.25*stripe[...,None])
    blk[:2]*=0.45; blk[-1:]*=0.6
    off=rng.integers(0,N); blk[:, off:off+3]*=0.5
    p[y0:y0+h]=blk
save(p,"textures/planks.png")
# floor tiles
t=np.zeros((N,N,3)); ts=64
for i in range(N//ts):
    for j in range(N//ts):
        c=np.array([232,222,200.]) if (i+j)%2==0 else np.array([196,120,96.])
        t[i*ts:(i+1)*ts, j*ts:(j+1)*ts]=c*(0.95+0.08*rng.random())
t*=(0.92+0.1*noise(N,1.0)[...,None])
t[::ts]=90; t[:, ::ts]=90; save(t,"textures/tiles.png")
# plaster
pl=col(noise(N,1.1), np.array([214,208,196.]), np.array([238,234,224.])); pl+=rng.normal(0,4,(N,N,1)); save(pl,"textures/plaster.png")
# roof corrugated
r=np.zeros((N,N,3)); wave=(np.sin(np.linspace(0,2*np.pi*16,N))*0.5+0.5)[None,:]
r[:]=np.array([60,120,70.]); r*= (0.7+0.4*wave[...,None]); r*=(0.9+0.15*noise(N,1.0)[...,None]); save(r,"textures/roof.png")
# bark
bk=np.zeros((N,N,3)); vert=noise(N,0.8); vs=np.sin(np.linspace(0,60,N)[None,:]+vert*20)*0.5+0.5
bk[:]=np.array([92,64,42.]); bk*=(0.6+0.6*vs[...,None]); save(bk,"textures/bark.png")
# needles / leaves
lv=col(noise(N,0.7), np.array([34,92,38.]), np.array([96,160,62.])); lv*=(0.7+0.5*noise(N,0.4)[...,None]); save(lv,"textures/leaves.png")
# reeds
rd=np.zeros((256,256,3)); rd[:]=np.array([110,130,60.]); rd*= (0.8+0.3*noise(256,1.0)[...,None]); save(rd,"textures/reeds.png")
# asphalt-ish path
a=col(noise(N,1.0), np.array([88,86,82.]), np.array([120,116,108.])); a+=rng.normal(0,9,(N,N,1)); save(a,"textures/asphalt.png")
print("textures ok")
