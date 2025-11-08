from dataclasses import dataclass
from typing import Tuple, Dict, Any, List
import numpy as np, cv2

@dataclass
class Circles:
    center: Tuple[int,int]
    r_pupil: int
    r_iris: int

def _hough_best_circle(gray: np.ndarray, min_r: int, max_r: int):
    g = cv2.GaussianBlur(gray, (9,9), 2)
    edges = cv2.Canny(g, 30, 90)
    circles = cv2.HoughCircles(edges, cv2.HOUGH_GRADIENT, dp=1.2, minDist=30,
                               param1=120, param2=20, minRadius=min_r, maxRadius=max_r)
    if circles is None:
        h,w = gray.shape[:2]; cx,cy = w//2,h//2; r = int(0.25*min(h,w))
        return (cx,cy), r
    c = np.round(circles[0]).astype(int)
    h,w = gray.shape[:2]; cx,cy = w//2,h//2
    idx = np.argmin((c[:,0]-cx)**2 + (c[:,1]-cy)**2)
    x,y,r = c[idx]
    return (int(x),int(y)), int(r)

def detect_circles(bgr: np.ndarray) -> Circles:
    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
    h,w = gray.shape[:2]
    (cx1,cy1), r_p = _hough_best_circle(gray, int(0.06*min(h,w)), int(0.18*min(h,w)))
    (cx2,cy2), r_i = _hough_best_circle(gray, int(0.28*min(h,w)), int(0.46*min(h,w)))
    cx,cy = int((cx1+cx2)/2), int((cy1+cy2)/2)
    r_p = max(8, min(r_p, int(0.9*r_i)))
    return Circles(center=(cx,cy), r_pupil=r_p, r_iris=r_i)

def unwrap_iris(bgr: np.ndarray, circles: Circles, angles: int=360, radii: int=96) -> np.ndarray:
    (cx,cy), r_in, r_out = circles.center, circles.r_pupil, circles.r_iris
    theta = np.linspace(0, 2*np.pi, angles, endpoint=False)
    rr    = np.linspace(r_in, r_out, radii)
    cos_t, sin_t = np.cos(theta), np.sin(theta)
    x = np.outer(rr, cos_t) + cx
    y = np.outer(rr, sin_t) + cy
    return cv2.remap(bgr, x.astype(np.float32), y.astype(np.float32),
                     interpolation=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT101)

def sharpness_lapvar(gray: np.ndarray) -> float:
    lap = cv2.Laplacian(gray, cv2.CV_32F)
    return float(lap.var())

def glare_ratio(gray: np.ndarray) -> float:
    return float((gray >= 245).mean())

def mean_brightness(gray: np.ndarray) -> float:
    return float(gray.mean()/255.0)

def sector_grid(angles: int=360, radii: int=96, n_ang: int=24, n_rad: int=5):
    blocks = []
    ang_step = angles//n_ang
    rad_step = radii//n_rad
    for ia in range(n_ang):
        for ir in range(n_rad):
            blocks.append((slice(ir*rad_step, (ir+1)*rad_step),
                           slice(ia*ang_step, (ia+1)*ang_step)))
    return blocks

def _block_features(strip_bgr, block):
    sub = strip_bgr[block[0], block[1]]
    g   = cv2.cvtColor(sub, cv2.COLOR_BGR2GRAY)
    mean = float(g.mean())/255.0
    std  = float(g.std())/255.0
    lapv = sharpness_lapvar(g)
    edges = cv2.Canny(g, 40, 120)
    edge_density = float(edges.mean()/255.0)
    return {"mean": mean, "std": std, "lapvar": lapv, "edge_density": edge_density}

def _normalize_scores(vals: np.ndarray) -> np.ndarray:
    # Мин-макс по снимку, защита от нулевого диапазона
    vmin, vmax = float(vals.min()), float(vals.max())
    if vmax - vmin < 1e-9:
        return np.zeros_like(vals, dtype=np.float32)
    return ((vals - vmin) / (vmax - vmin)).astype(np.float32)

def summarize_eye(bgr: np.ndarray, n_ang: int=24, n_rad: int=5):
    circ  = detect_circles(bgr)
    strip = unwrap_iris(bgr, circ, angles=360, radii=96)
    g = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
    quality = {
        "brightness": mean_brightness(g),
        "glare": glare_ratio(g),
        "sharp_lapvar": sharpness_lapvar(g),
        "r_pupil": circ.r_pupil,
        "r_iris": circ.r_iris
    }
    blocks = sector_grid(360, 96, n_ang, n_rad)

    feats = []
    # собираем признаки для нормировки
    tmp = []
    for ia in range(n_ang):
        for ir in range(n_rad):
            f = _block_features(strip, blocks[ia*n_rad+ir])
            feats.append({"angle_sector": ia, "ring": ir, **f})
            tmp.append([f["std"], f["edge_density"], 1.0 - abs(0.5 - f["mean"]), f["lapvar"]])
    tmp = np.array(tmp, dtype=np.float32)  # [N,4]

    # весовая модель v1: std(0.4) + edge(0.4) + centered_mean(0.2) + lapvar(подмешиваем после нормировки)
    s_std   = _normalize_scores(tmp[:,0])
    s_edge  = _normalize_scores(tmp[:,1])
    s_cmean = _normalize_scores(tmp[:,2])
    s_lap   = _normalize_scores(tmp[:,3])
    score   = 0.4*s_std + 0.4*s_edge + 0.2*s_cmean + 0.2*s_lap

    # собираем теплокарту [n_ang x n_rad]
    score_map = score.reshape(n_ang, n_rad).tolist()

    return {"quality": quality, "features": feats, "score_map": score_map}
