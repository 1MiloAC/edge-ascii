\\@group(0) @binding(0) var<storage, read> input_buffer: array<u8>;
\\@group(0) @binding(1) var<storage, read_write> output_buffer: array<u8>;
\\
\\@compute @workgroup_size(8, 8, 1)
\\fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
\\    let index = global_id.x;
\\    
\\    // Make sure we don't go out of bounds
\\    if (index >= arrayLength(&input_buffer)) {
\\        return;
\\    }
\\    
\\    // Simple image processing - invert the color
\\    output_buffer[index] = 255 - input_buffer[index];
\\}
