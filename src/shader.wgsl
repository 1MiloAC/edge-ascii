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

    let inverted_r = 255u - r;
    let inverted_g = 255u - g;
    let inverted_b = 255u - b;

    let output_packed_color =
        (a << 24u) |         
        (inverted_r << 16u) |
        (inverted_g << 8u) | inverted_b;

    output_buffer[index] = output_packed_color;
}
