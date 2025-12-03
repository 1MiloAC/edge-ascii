use anyhow;
use bytemuck::from_bytes;
use image::{GenericImage, GenericImageView, ImageBuffer, Rgba, open};
use std::sync::mpsc::channel;
use wgpu::{
    self, BindingType,
    util::{BufferInitDescriptor, DeviceExt},
    wgc::id::markers::BindGroupLayout,
};

pub async fn setup(img: ImageBuffer<Rgba<u8>, Vec<u8>>) -> anyhow::Result<()> {
    for y in 0..img.height() {
        if y % 16 == 0 {
            for x in 0..img.width() {
                if x % 16 == 0 {
                    let b = (u16::from(img[(x, y)].0[0]) * 9) / 255;
                    match b {
                        0 => print!(" "),
                        1 => print!("."),
                        2 => print!("o"),
                        3 => print!("x"),
                        4 => print!("%"),
                        5 => print!("X"),
                        6 => print!("&"),
                        7 => print!("@"),
                        8 => print!("#"),
                        9 => print!("M"),
                        _ => print!(""),
                    }
                }
            }
            println!()
        }
    }

    Ok(())
}
