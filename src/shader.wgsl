@group(0) @binding(0) var input_buffer: texture_2d<f32>;
@group(0) @binding(1) var<storage, read_write> output_buffer: array<u32>;

@compute @workgroup_size(16,16)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    let coords = vec2<i32>(global_id.xy);
    let dims = textureDimensions(input_buffer);

    if (coords.x >= i32(dims.x) || coords.y >= i32(dims.y)) {
        return;
    }

    let pixel = textureLoad(input_buffer,coords,0);

    let packed = pack4x8unorm(pixel);
    let index = u32(coords.y) * dims.x + u32(coords.x);
    output_buffer[index] = packed;
} 
