// Projection calibrated to the supplied tshirtm.glb mesh's LOCAL coordinates.
// Node transforms stay untouched, preserving the exported avatar fit.
export const TEMPLATE_SHA256 = '520b39f5e4ba332a65726be488c6417df34f4bf23be1bcefb1c21c0ea8d2ad0e';
export const TEMPLATE_VERSION = 'male_tshirt_photo_projection_v1';
const X0 = -252.23594665527344, X1 = 261.69287109375;
const Z0 = -1633.0225830078125, Z1 = -904.7359008789062;
const clamp = (x, lo = 0, hi = 1) => Math.min(hi, Math.max(lo, x));

export function validCrop(crop) {
  return crop && ['x', 'y', 'w', 'h'].every(k => Number.isFinite(crop[k])) &&
    crop.x >= 0 && crop.y >= 0 && crop.w >= .02 && crop.h >= .02 &&
    crop.x + crop.w <= 1.00001 && crop.y + crop.h <= 1.00001;
}
export function cropFromPoints(a, b) {
  const x = clamp(Math.min(a.x, b.x)), y = clamp(Math.min(a.y, b.y));
  return {x, y, w: clamp(Math.max(a.x, b.x)) - x,
    h: clamp(Math.max(a.y, b.y)) - y};
}
// Input must be non-indexed triangles. Splitting prevents front/back UV seams
// sharing a vertex. +local Y faces the camera in this exported template.
export function projectionUV(positions, normals, sleeves = false) {
  if (positions.length !== normals.length || positions.length % 9 !== 0)
    throw new Error('Expected complete non-indexed position/normal triangles.');
  const uv = new Float32Array(positions.length / 3 * 2);
  for (let t = 0; t < positions.length; t += 9) {
    const front = normals[t + 1] + normals[t + 4] + normals[t + 7] >= 0;
    for (let v = 0; v < 3; v++) {
      const p = t + v * 3, out = p / 3 * 2;
      const x = clamp((positions[p] - X0) / (X1 - X0));
      const y = clamp((positions[p + 2] - Z0) / (Z1 - Z0));
      // A small inset avoids colour bleeding across the atlas seam.
      uv[out] = ((front ? 0 : 1) + .002 + (front ? x : 1 - x) * .996) / 2;
      uv[out + 1] = sleeves ? .752 + y * .246 : .002 + y * .746;
    }
  }
  return uv;
}

export function drawAtlas(canvas, front, back, frontCrop, backCrop) {
  if (!validCrop(frontCrop) || !validCrop(backCrop)) throw new Error('Select both shirt-body rectangles first.');
  canvas.width = 2048; canvas.height = 2048;
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = '#c8c8c8'; ctx.fillRect(0, 0, 2048, 2048);
  for (const [side, image, crop] of [[0, front, frontCrop], [1, back, backCrop]]) {
    const x = crop.x * image.width, y = crop.y * image.height;
    const w = crop.w * image.width, h = crop.h * image.height;
    // Composite transparent cutouts onto cloth colour, never cut holes in mesh.
    const sample = document.createElement('canvas'); sample.width = sample.height = 1;
    const sctx = sample.getContext('2d');
    sctx.drawImage(image, x + w * .1, y + h * .35, w * .15, h * .2, 0, 0, 1, 1);
    const rgb = sctx.getImageData(0, 0, 1, 1).data;
    ctx.fillStyle = rgb[3] > 32 ? `rgb(${rgb[0]},${rgb[1]},${rgb[2]})` : '#c8c8c8';
    ctx.fillRect(side * 1024, 0, 1024, 2048);
    ctx.drawImage(image, x, y, w, h, side * 1024, 0, 1024, 1536);
    // Sleeve detail is a sampled fabric patch, not reconstructed sleeve artwork.
    ctx.drawImage(image, x + w * .05, y + h * .3, w * .16, h * .25,
      side * 1024, 1536, 1024, 512);
  }
  return canvas;
}
