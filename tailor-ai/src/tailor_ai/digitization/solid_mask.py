"""Opaque-garment policy: preserve source RGB inside a closed silhouette.

Only background components enclosed by fabric become foreground. Background
connected to any image edge (including diagonal paths) is never filled. This
is not dilation, a convex hull, or a reconstruction of missing outer fabric.
"""
import numpy as np
from scipy import ndimage as ndi
VERSION='opaque-enclosed-interior-v1'

def preserve_interior(mask):
    value=np.asarray(mask)
    if value.ndim!=2 or not np.isfinite(value).all():
        raise ValueError('Invalid garment mask')
    binary=value.astype(bool)
    filled=ndi.binary_fill_holes(binary,structure=np.ones((3,3),dtype=bool))
    return filled, int(np.count_nonzero(filled & ~binary))
