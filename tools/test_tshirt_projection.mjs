import assert from 'node:assert/strict';
import fs from 'node:fs';
import {projectionUV,validCrop,cropFromPoints,TEMPLATE_SHA256} from '../web/tshirt_texture_core.js';
import {createHash} from 'node:crypto';
const bytes=fs.readFileSync(new URL('../web/templates/tshirtm.glb',import.meta.url));
assert.equal(createHash('sha256').update(bytes).digest('hex'),TEMPLATE_SHA256);
const n=bytes.readUInt32LE(12),json=JSON.parse(bytes.subarray(20,20+n).toString()),binOffset=28+n;
const dims={VEC3:3,VEC2:2,SCALAR:1};
function accessor(i){const a=json.accessors[i],v=json.bufferViews[a.bufferView],at=binOffset+(v.byteOffset||0)+(a.byteOffset||0),count=a.count*dims[a.type];const ctor={5126:Float32Array,5123:Uint16Array,5125:Uint32Array}[a.componentType];return new ctor(bytes.buffer,bytes.byteOffset+at,count)}
let triangles=0;
for(const primitive of json.meshes[0].primitives){
 const p=accessor(primitive.attributes.POSITION),normal=accessor(primitive.attributes.NORMAL),indices=accessor(primitive.indices);
 const positions=new Float32Array(indices.length*3),normals=new Float32Array(indices.length*3);
 for(let i=0;i<indices.length;i++)for(let axis=0;axis<3;axis++){positions[i*3+axis]=p[indices[i]*3+axis];normals[i*3+axis]=normal[indices[i]*3+axis]}
 const sleeve=json.materials[primitive.material].name.startsWith('Photographed sleeve projection');
 const uv=projectionUV(positions,normals,sleeve);
 assert.equal(uv.length,indices.length*2);assert.ok(uv.every(Number.isFinite));
 for(let t=0;t<normals.length;t+=9){const front=normals[t+1]+normals[t+4]+normals[t+7]>=0;for(let v=0;v<3;v++){const at=(t/3+v)*2;assert.ok(front?uv[at]<.5:uv[at]>.5);assert.ok(uv[at+1]>=(sleeve?.75:0)&&uv[at+1]<=(sleeve?1:.75))}}
 triangles+=indices.length/3;
}
const f=projectionUV(new Float32Array([-252.23595,0,-1633.0226,261.69287,0,-1633.0226,0,0,-904.7359]),new Float32Array([0,1,0,0,1,0,0,1,0]));
const b=projectionUV(new Float32Array([-252.23595,0,-1633.0226,261.69287,0,-1633.0226,0,0,-904.7359]),new Float32Array([0,-1,0,0,-1,0,0,-1,0]));
assert.ok(f[0]<f[2]);assert.ok(b[0]>b[2]);assert.ok(f[1]<f[5]);
assert.deepEqual(cropFromPoints({x:.9,y:.8},{x:.1,y:.2}),{x:.1,y:.2,w:.8,h:.6000000000000001});
for(const c of [{x:0,y:0,w:0,h:1},{x:-1,y:0,w:1,h:1},{x:0,y:0,w:NaN,h:1},{x:.9,y:0,w:.2,h:1}])assert.equal(validCrop(c),false);
assert.equal(validCrop({x:0,y:0,w:1,h:1}),true);
assert.throws(()=>projectionUV(new Float32Array(3),new Float32Array(3)));
console.log(`Passed UV, seam, orientation, crop and template-identity checks on ${triangles} triangles.`);
