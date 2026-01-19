from PIL import Image
import numpy as np
from io import BytesIO

def load_image(data: bytes):
    return Image.open(BytesIO(data)).convert("RGB")

def analyze_brightness(img):
    arr = np.array(img).astype(float)
    return float(arr.mean() / 255)

def analyze_sharpness(img):
    arr = np.array(img.convert("L"))
    gy, gx = np.gradient(arr)
    return float(np.sqrt(gx**2 + gy**2).mean())
