@group(0) @binding(0) var input_texture: texture_2d<f32>;
@group(0) @binding(1) var<storage, read_write> output_buffer: array<u32>;

@compute @workgroup_size(16,16)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    let coords = vec2<i32>(global_id.xy);
    let dims = textureDimensions(input_texture);

    if coords.x >= i32(dims.x) || coords.y >= i32(dims.y) {
        return;
    }
    let pixel = textureLoad(input_texture, coords, 0);

    let linear_r = linearize(pixel.r);
    let linear_g = linearize(pixel.g);
    let linear_b = linearize(pixel.b);

    let pixel_l = vec3<f32>(linear_r, linear_g, linear_b);
    let lum_weight = vec3<f32>(0.2126, 0.7152, 0.0722);
    let linear = dot(pixel_l, lum_weight);

    let srgb_packed = vec4<f32>(
        linear,
        linear,
        linear,
        pixel.a
    );
    let packed = pack4x8unorm(srgb_packed);
    let index = u32(coords.y) * dims.x + u32(coords.x);
    output_buffer[index] = packed;
}
fn linearize(c: f32) -> f32 {
    if c <= 0.04045 {
        return c / 12.92;
    } else {
        return pow(((c + 0.055) / 1.055), 2.4);
    }
}

