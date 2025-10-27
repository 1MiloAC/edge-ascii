use image::{GenericImage, GenericImageView, ImageBuffer, open};
use wgpu::{self, util::BufferInitDescriptor};

pub async fn setup() {
    env_logger::init();
    let img = open("test.png").unwrap().into_rgb8();
    let (width, height) = img.dimensions();

    let instance = wgpu::Instance::new(&Default::default());
    let adapter = instance.request_adapter(&Default::default()).await.unwrap();
    let (device, queue) = adapter.request_device(&Default::default()).await.unwrap();
    let shader = device.create_shader_module(wgpu::include_wgsl!("shader.wgsl"));
    let bindgroup = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
        label: Some("Bind group 1"),
        entries: &[
            wgpu::BindGroupLayoutEntry {
                binding: 0,
                visibility: wgpu::ShaderStages::COMPUTE,
                ty: wgpu::BindingType::Texture {
                    sample_type: wgpu::TextureSampleType::Float { filterable: false },
                    view_dimension: wgpu::TextureViewDimension::D2,
                    multisampled: false,
                },
                count: None,
            },
            wgpu::BindGroupLayoutEntry {
                binding: 1,
                visibility: wgpu::ShaderStages::COMPUTE,
                ty: wgpu::BindingType::StorageTexture {
                    access: wgpu::StorageTextureAccess::WriteOnly,
                    format: wgpu::TextureFormat::Rgba8Unorm,
                    view_dimension: wgpu::TextureViewDimension::D2,
                },
                count: None,
            },
        ],
    });
    let pipeline_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
        label: Some("Pipeline Layout"),
        bind_group_layouts: &[&bindgroup],
        push_constant_ranges: &[],
    });

    let pipeline = device.create_compute_pipeline(&wgpu::ComputePipelineDescriptor {
        label: Some("Start"),
        layout: Some(&pipeline_layout),
        module: &shader,
        entry_point: Some("main"),
        compilation_options: Default::default(),
        cache: Default::default(),
    });
    let input_buffer = device.create_buffer_init(&BufferInitDescriptor {
        lavel: Some("Input"),
        contents: bytemuck::cast
    })
    let texture_size = wgpu::Extent3d {
        width: width,
        height: height,
        depth_or_array_layers: 1,
    };
    let input_texture = device.create_texture(&wgpu::TextureDescriptor {
        size: texture_size,
        label: Some("input Texture"),
        mip_level_count: 1,
        sample_count: 1,
        dimension: wgpu::TextureDimension::D2,
        format: wgpu::TextureFormat::Rgba8Unorm,
        usage: wgpu::TextureUsages::STORAGE_BINDING | wgpu::TextureUsages::TEXTURE_BINDING,
        view_formats: &[],
    });
    let input_texture_view = input_texture.create_view(&Default::default());
    let encoder = device.create_command_encoder(&wgpu::CommandEncoderDescriptor{
        label: None,
    });
}
