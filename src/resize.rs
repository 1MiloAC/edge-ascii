use anyhow;
use bytemuck::from_bytes;
use image::{GenericImage, GenericImageView, ImageBuffer, Rgba, open};
use std::sync::mpsc::channel;
use wgpu::{
    self, BindingType,
    util::{BufferInitDescriptor, DeviceExt},
    wgc::id::markers::BindGroupLayout,
};

pub async fn setup() -> anyhow::Result<()> {
    //env_logger::init();
    let img = open("test.png").unwrap().into_rgba8();
    let (width, height) = img.dimensions();

    let instance = wgpu::Instance::new(&Default::default());
    let adapter = instance.request_adapter(&Default::default()).await.unwrap();
    let features = adapter.features();
    println!("Afeatures: {:?}", features);
    if features.contains(wgpu::Features::TEXTURE_ADAPTER_SPECIFIC_FORMAT_FEATURES) {
        println!("supported")
    }
    let (device, queue) = adapter
        .request_device(&wgpu::DeviceDescriptor {
            label: Some("Device"),
            required_features: wgpu::Features::TEXTURE_ADAPTER_SPECIFIC_FORMAT_FEATURES
                | wgpu::Features::default(),
            required_limits: wgpu::Limits::default(),
            experimental_features: wgpu::ExperimentalFeatures::default(),
            memory_hints: wgpu::MemoryHints::default(),
            trace: wgpu::Trace::default(),
        })
        .await
        .unwrap();
    let shader = device.create_shader_module(wgpu::include_wgsl!("resize.wgsl"));
    let mut encoder = device.create_command_encoder(&wgpu::CommandEncoderDescriptor {
        label: Some("encoder"),
    });
    let bind_group_layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
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
                    access: wgpu::StorageTextureAccess::ReadWrite,
                    format: wgpu::TextureFormat::Rgba8Unorm,
                    view_dimension: wgpu::TextureViewDimension::D2,
                },
                count: None,
            },
            wgpu::BindGroupLayoutEntry {
                binding: 2,
                visibility: wgpu::ShaderStages::COMPUTE,
                ty: wgpu::BindingType::Buffer {
                    ty: wgpu::BufferBindingType::Storage { read_only: false },
                    has_dynamic_offset: false,
                    min_binding_size: None,
                },
                count: None,
            },
        ],
    });
    let dimensions = img.dimensions();
    let input_texture = device.create_texture(&wgpu::TextureDescriptor {
        label: Some("input"),
        size: wgpu::Extent3d {
            width: width,
            height: height,
            depth_or_array_layers: 1,
        },
        mip_level_count: 1,
        sample_count: 1,
        dimension: wgpu::TextureDimension::D2,
        format: wgpu::TextureFormat::Rgba8Unorm,
        usage: wgpu::TextureUsages::TEXTURE_BINDING
            | wgpu::TextureUsages::STORAGE_BINDING
            | wgpu::TextureUsages::COPY_DST,
        view_formats: &[],
    });
    let rw_texture = device.create_texture(&wgpu::TextureDescriptor {
        label: Some("rw"),
        size: wgpu::Extent3d {
            width: (width + 7) / 8,
            height: (height + 7) / 8,
            depth_or_array_layers: 1,
        },
        mip_level_count: 1,
        sample_count: 1,
        dimension: wgpu::TextureDimension::D2,
        format: wgpu::TextureFormat::Rgba8Unorm,
        usage: wgpu::TextureUsages::STORAGE_BINDING | wgpu::TextureUsages::TEXTURE_BINDING,
        view_formats: &[],
    });
    let texture_size = wgpu::Extent3d {
        width: dimensions.0,
        height: dimensions.1,
        depth_or_array_layers: 1,
    };
    let output_buffer = device.create_buffer(&wgpu::BufferDescriptor {
        label: Some("outptu"),
        size: (width * height * 4) as u64,
        usage: wgpu::BufferUsages::COPY_SRC | wgpu::BufferUsages::STORAGE,
        mapped_at_creation: false,
    });
    let temp_buffer = device.create_buffer(&wgpu::BufferDescriptor {
        label: Some("temp"),
        size: (width * height * 4) as u64,
        usage: wgpu::BufferUsages::COPY_DST | wgpu::BufferUsages::MAP_READ,
        mapped_at_creation: false,
    });

    let input_texture_view = input_texture.create_view(&wgpu::TextureViewDescriptor::default());
    let rw_texture_view = rw_texture.create_view(&wgpu::TextureViewDescriptor::default());

    let bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
        label: Some("BG1"),
        layout: &bind_group_layout,
        entries: &[
            wgpu::BindGroupEntry {
                binding: 0,
                resource: wgpu::BindingResource::TextureView(&input_texture_view),
            },
            wgpu::BindGroupEntry {
                binding: 1,
                resource: wgpu::BindingResource::TextureView(&rw_texture_view),
            },
            wgpu::BindGroupEntry {
                binding: 2,
                resource: wgpu::BindingResource::Buffer(wgpu::BufferBinding {
                    buffer: &output_buffer,
                    offset: 0,
                    size: None,
                }),
            },
        ],
    });

    queue.write_texture(
        wgpu::TexelCopyTextureInfo {
            texture: &input_texture,
            mip_level: 0,
            origin: wgpu::Origin3d::ZERO,
            aspect: wgpu::TextureAspect::All,
        },
        &img.as_raw(),
        wgpu::TexelCopyBufferLayout {
            offset: 0,
            bytes_per_row: Some(4 * dimensions.0),
            rows_per_image: Some(dimensions.1),
        },
        texture_size,
    );
    let pipeline_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
        label: Some("Pipeline Layout"),
        bind_group_layouts: &[&bind_group_layout],
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
    let pipeline2 = device.create_compute_pipeline(&wgpu::ComputePipelineDescriptor {
        label: Some("Start"),
        layout: Some(&pipeline_layout),
        module: &shader,
        entry_point: Some("main2"),
        compilation_options: Default::default(),
        cache: Default::default(),
    });
    let wg_size_x = 16;
    let wg_size_y = 16;
    let dx = (width + wg_size_x - 1) / wg_size_x;
    let dy = (height + wg_size_y - 1) / wg_size_y;

    {
        let mut pass = encoder.begin_compute_pass(&Default::default());
        pass.set_pipeline(&pipeline);
        pass.set_bind_group(0, &bind_group, &[]);
        pass.dispatch_workgroups(dx, dy, 1);
    }
    {
        let mut pass = encoder.begin_compute_pass(&Default::default());
        pass.set_pipeline(&pipeline2);
        pass.set_bind_group(0, &bind_group, &[]);
        pass.dispatch_workgroups(dx, dy, 1);
    }
    encoder.copy_buffer_to_buffer(&output_buffer, 0, &temp_buffer, 0, output_buffer.size());
    queue.submit([encoder.finish()]);
    {
        let (tx, rx) = channel();
        temp_buffer.map_async(wgpu::MapMode::Read, .., move |result| {
            tx.send(result).unwrap()
        });
        device.poll(wgpu::PollType::wait_indefinitely())?;
        rx.recv()??;
        let output_data = temp_buffer.get_mapped_range(..);
        let output_img: ImageBuffer<Rgba<u8>, _> =
            ImageBuffer::from_raw(width, height, output_data.to_vec()).expect("error");
        output_img.save("test3.png")?;
        Ok(())
    }
}
