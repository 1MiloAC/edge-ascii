@group(0) @binding(0)
var<storage, read> input_buffer: array<u32>;

@group(0) @binding(0)
var<storage, read_write> output_buffer: array<u32>;

@compute @workgroup_size(64)
fn main(@builtin(global_invocation_id) id: vec3<u32>) {
    let i = id.x;
    if (i < arrayLength(&input_buffer)) {
        output_buffer[i] = 255u - input_buffer[i];
    }
}
