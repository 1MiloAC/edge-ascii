@group(0) @binding(0) var<storage, read> input_buffer: array<u32>;
@group(0) @binding(1) var<storage, read_write> output_buffer: array<u32>;

@compute @workgroup_size(64)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    let index = global_id.x;

    let packed_color = input_buffer[index];

    let a = (packed_color >> 24u) & 0xFFu;
    let r = (packed_color >> 16u) & 0xFFu;
    let g = (packed_color >> 8u)  & 0xFFu;
    let b = packed_color          & 0xFFu;

    let vR = linearize(f32(r)/255f);
    let vG = linearize(f32(g)/255f);
    let vB = linearize(f32(b)/255f);
    let lum = vR * 0.2126 + vG * 0.7152 + vB * 0.0722;
    let constrained = round(srgbize(lum) * 9) / 9;

    let ulum = u32(clamp(constrained * 255f,0f,255f));

    let output_packed_color =
        (a << 24u) |         
        (ulum << 16u) |
        (ulum << 8u) | 
        ulum;

    output_buffer[index] = output_packed_color;
}
fn linearize(c: f32) -> f32 {

    if (c <= 0.04045) {
        return c / 12.92;
    } else {
        return pow((c + 0.055)/1.055, 2.4);
    }
}
fn srgbize(c: f32) -> f32 {
    if (c <= 0.0031308) {
        return c * 12.92;
    } else {
        return pow(c, 1.0 / 2.4) - 0.055;
    }
}
