#!/usr/bin/env python3
"""Compose the requested SANTIAGO D FERNANDEZ engraving from one native text mask.

Original supplied PBR files remain byte-for-byte untouched. Four derived front
maps keep the original resolution and change only the old holder region.
"""
import argparse, hashlib, json
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter, ImageCms

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--resources',type=Path,required=True)
p.add_argument('--mask',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
mask_image=Image.open(a.mask).getchannel('A')
mask=np.asarray(mask_image,dtype=np.float32)/255
assert mask.shape==(1292,2048)
y,x=np.nonzero(mask>.5)
assert 70<=x.min()<120 and 1080<=y.min()<1140 and y.max()<1180,(x.min(),y.min(),y.max())
# The original name occupies x87..611, y1104..1157. An undecorated area on the
# same brushed row supplies the microtexture; feather entirely outside glyphs.
x0,x1,y0,y1=56,680,1080,1184
# Erase only the original name rectangle. A longer replacement extends into
# untouched substrate; never widen the texture-copy patch with the new text.
edit_x1=max(x1,int(x.max())+8)
assert edit_x1<1550, "Holder must not overlap the payment mark"
shift=760
xx=np.minimum(np.arange(x1-x0),np.arange(x1-x0)[::-1])/18
yy=np.minimum(np.arange(y1-y0),np.arange(y1-y0)[::-1])/18
blend=np.minimum(np.clip(xx,0,1)[None,:],np.clip(yy,0,1)[:,None])
blend=(blend*blend*(3-2*blend))[:,:,None]
# Recessed 40 micrometres, as in the supplied small-engraving manifest.
height=np.asarray(mask_image.filter(ImageFilter.GaussianBlur(.65)),dtype=np.float32)/255 * -.04
dy,dx=np.gradient(height,53.98/1292,85.60/2048)
manifest={'holder':'SANTIAGO D FERNANDEZ','mask':'native SF regular 70 px, tracking 2, baseline y1157',
          'size':[2048,1292], 'changed_rect':[x0,y0,edit_x1,y1], 'depth_mm':-.04,
          'normal':'OpenGL +Y up', 'source_unchanged':True, 'files':{}}
for kind in ['basecolor','roughness_rgb','metalness_rgb','normal_opengl']:
    src=a.resources/f'front_{kind}.png'
    original=np.asarray(Image.open(src),dtype=np.float32)
    result=original.copy()
    result[y0:y1,x0:x1]=original[y0:y1,x0:x1]*(1-blend)+original[y0:y1,x0+shift:x1+shift]*blend
    if kind=='basecolor':
        # Subtle material modulation, no black text or baked lighting/shadow.
        result*=1-mask[:,:,None]*.025
    elif kind=='roughness_rgb':
        result=result*(1-mask[:,:,None])+(.43*255)*mask[:,:,None]
    elif kind=='normal_opengl':
        normal=result/255*2-1
        nz=np.maximum(normal[:,:,2],.1)
        nx=normal[:,:,0]/nz-dx
        ny=normal[:,:,1]/nz+dy
        normal=np.stack((nx,ny,np.ones_like(nx)),axis=-1)
        normal/=np.linalg.norm(normal,axis=-1,keepdims=True)
        affected=(np.abs(dx)+np.abs(dy))>1e-8
        result[affected]=(normal[affected]*.5+.5)*255
    encoded=np.round(np.clip(result,0,255)).astype(np.uint8)
    outside=np.ones(mask.shape,dtype=bool);outside[y0:y1,x0:edit_x1]=False
    assert np.array_equal(encoded[outside],original.astype(np.uint8)[outside]),kind
    name=f'front_alex_smith_{kind}.png'
    options={'compress_level':9}
    if kind=='basecolor': options['icc_profile']=ImageCms.ImageCmsProfile(ImageCms.createProfile('sRGB')).tobytes()
    Image.fromarray(encoded).save(a.output/name,**options)
    manifest['files'][name]={'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),
                             'sha256':hashlib.sha256((a.output/name).read_bytes()).hexdigest()}
(a.output/'alex_smith_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Four same-resolution front maps; outside holder region exactly unchanged.')
