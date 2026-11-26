"""Conservative ribbed-hem evidence, not a trained sweater classifier."""
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

def rib_evidence(image,binary,crop):
    x,y,w,h=[int(round(crop[k]*n)) for k,n in [('x',image.width),('y',image.height),('w',image.width),('h',image.height)]]
    def patch(a,b):
        box=(x+int(w*.20),y+int(h*a),x+int(w*.80),y+int(h*b))
        valid=binary[box[1]:box[3],box[0]:box[2]]
        if not valid.size or valid.mean()<.97:return None
        return np.asarray(image.convert('L').crop(box).resize((256,48),Image.Resampling.BILINEAR),dtype=float)
    bottom=patch(.82,.95);body=patch(.42,.55)
    if bottom is None or body is None:return {'ribbed':False,'reason':'hem_not_visible'}
    def measure(a):
        high=ndi.gaussian_filter1d(a,.6,axis=1)-ndi.gaussian_filter1d(a,4,axis=1)
        line=high.mean(0);power=abs(np.fft.rfft(line))**2;power[:13]=0;power[85:]=0
        return float(line.std()),float(line.std()/max(.1,high.std())),float(power.max()/max(.1,power.sum()))
    amplitude,coherence,peak=measure(bottom);baseline=measure(body)[0]
    ribbed=amplitude>2.5 and amplitude/max(.8,baseline)>2.2 and coherence>.55 and peak>.08
    return {'ribbed':bool(ribbed),'amplitude':round(amplitude,3),'body_amplitude':round(baseline,3),
        'vertical_coherence':round(coherence,3),'spectral_peak_fraction':round(peak,3)}

def resolve_style(requested,evidence):
    if requested not in {'auto','tee','sweater'}:raise ValueError('Invalid long-sleeve style')
    if requested!='auto':return {'requested':requested,'resolved':requested,'source':'user','uncertain':False,'evidence':evidence}
    supported=len(evidence)==2 and all(e['ribbed'] for e in evidence.values())
    return {'requested':'auto','resolved':'sweater' if supported else 'tee',
        'source':'photo_rib_evidence' if supported else 'default_plain_hem','uncertain':not supported,'evidence':evidence}
