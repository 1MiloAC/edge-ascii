use image::{GenericImage, GenericImageView, ImageBuffer, open};
use pollster::FutureExt as _;
use std::error::Error;
use wgpu::{self, util::BufferInitDescriptor};

pub mod resize;
pub mod sample_mod;

pub struct State {
    adapter: wgpu::Adapter,
    device: wgpu::Device,
    queue: wgpu::Queue,
}
fn main() -> Result<(), Box<dyn Error>> {
    let img = open("test.png").unwrap().into_rgb8();
    img.as_raw();
    img.save("test.jpg")?;
    pollster::block_on(sample_mod::setup());
    pollster::block_on(resize::setup());
    Ok(())
}
