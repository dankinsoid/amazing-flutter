# @ai-generated(solo)
# Floor irradiance under the glass profile, ray-traced in the 2D cross-section along
# the light azimuth. Floor at z=0, drop = region below h(x). Usage:
#   python3 tools/floor_trace.py <height px> <light elevation deg>
# The result is the basis of floorLight() in shaders/liquid_glass.frag.
import sys
import numpy as np
R, W, H = 70.0, 28.0, float(sys.argv[1])
N_IDX = 1.33                          # water
ELEV = np.deg2rad(float(sys.argv[2]))

def h(x):
    t = np.clip((R - np.abs(x)) / W, 0, 1)
    return H * (1 - (1 - t)**4)**0.25 * (np.abs(x) <= R)

def hprime(x, eps=1e-3):
    return (h(x + eps) - h(x - eps)) / (2 * eps)

def fresnel_T(cos_i, n1, n2):
    s = n1 / n2 * np.sqrt(max(0.0, 1 - cos_i**2))
    if s >= 1: return 0.0
    cos_t = np.sqrt(1 - s*s)
    rs = ((n1*cos_i - n2*cos_t) / (n1*cos_i + n2*cos_t))**2
    rp = ((n1*cos_t - n2*cos_i) / (n1*cos_t + n2*cos_i))**2
    return 1 - 0.5*(rs + rp)

def refract(d, n, eta):
    # d incoming unit dir, n unit normal against d, eta = n1/n2
    cos_i = -np.dot(n, d)
    k = 1 - eta*eta*(1 - cos_i*cos_i)
    if k < 0: return None
    return eta*d + (eta*cos_i - np.sqrt(k))*n

d0 = np.array([np.cos(ELEV), -np.sin(ELEV)])  # travelling +x and down
X = np.arange(-160, 160, 0.5)
E = np.zeros_like(X)
def bin_add(xf, w):
    i = int(round((xf - X[0]) / 0.5))
    if 0 <= i < len(X): E[i] += w

# launch rays uniformly by floor landing point (unobstructed) so each carries weight 1
for x0 in np.arange(-200, 200, 0.05):
    # ray: p(t) = (x0, 0) - d0 * t for t>0 going back up; find first hit with surface from above
    # march from far above downward
    ts = np.arange(400, 0, -0.05)
    px = x0 - d0[0]*ts; pz = -d0[1]*ts
    inside = pz < h(px)
    hit = np.argmax(inside) if inside.any() else None
    if hit is None or not inside[hit]:
        bin_add(x0, 0.05/0.5); continue
    xs, zs = px[hit], pz[hit]
    slope = hprime(xs); n = np.array([-slope, 1.0]); n /= np.linalg.norm(n)
    T = fresnel_T(-np.dot(n, d0), 1.0, N_IDX)
    d1 = refract(d0, n, 1.0/N_IDX)
    # travel inside until floor or surface exit
    p = np.array([xs, zs]); step = 0.05; w = T
    for _ in range(20000):
        p = p + d1*step
        if p[1] <= 0: bin_add(p[0], w*0.05/0.5); break
        if p[1] > h(p[0]):   # exited through the surface
            slope = hprime(p[0]); n2 = np.array([slope, -1.0]); n2 /= np.linalg.norm(n2)  # normal pointing into the drop
            d2 = refract(d1, n2, N_IDX)
            if d2 is None: w = 0; break     # TIR: dropped
            w *= fresnel_T(-np.dot(n2, d1), N_IDX, 1.0)
            # continue in air to the floor
            if d2[1] >= 0: w = 0; break
            t = -p[1]/d2[1]; bin_add(p[0] + d2[0]*t, w*0.05/0.5); break

# smooth 2px and print the profile relative to 1
k = np.ones(4)/4; Es = np.convolve(E, k, 'same')
for x, e in zip(X, Es):
    if -110 <= x <= 130 and abs(round(x*2)) % 8 == 0:
        bar = '#' * int(max(0, min(60, e*20)))
        print(f"{x:7.1f} {'IN ' if abs(x)<=R else 'out'} {e:5.2f} {bar}")
