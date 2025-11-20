requires readonly_and_readwrite_storage_textures;
@group(0) @binding(0) var input_texture: texture_2d<f32>;
@group(0) @binding(1) var rw_texture0: texture_storage_2d<rgba8unorm, read_write>;
@group(0) @binding(2) var<storage, read_write> output_buffer: array<u32>;

@compute @workgroup_size(16,16)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    let coords = vec2<i32>(global_id.xy);
    let dims = textureDimensions(input_texture);

    if coords.x >= i32(dims.x) || coords.y >= i32(dims.y) {
        return;
    }
    if coords.x % 8 != 0 || coords.y % 8 != 0 {
        return;
    }
    let ox = coords.x / 8;
    let oy = coords.y / 8;
    let x = i32(floor(f32(dims.x) / 8f));
    let pixel = textureLoad(input_texture, coords, 0);
    textureStore(rw_texture0, vec2<i32>(ox, oy), pixel);
}
@compute @workgroup_size(16,16)
fn main2(@builtin(global_invocation_id)global_id: vec3<u32>) {
    let coords = vec2<i32>(global_id.xy);
    let dims = textureDimensions(rw_texture0);

    if coords.x >= i32(dims.x) || coords.y >= i32(dims.y) {
        return;
    }
    let pixel = textureLoad(rw_texture0, coords);
    for (var y = 0; y < 8; y = y + 1) {
        for (var x = 0; x < 8; x = x + 1) {

            let ox = coords.x * 8 + x;
            let oy = coords.y * 8 + y;
            let test = i32(dims.x) * 8;
            let index = oy * test + ox;
            output_buffer[index] = pack4x8unorm(pixel);
        }
    }
}
