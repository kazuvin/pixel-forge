use std::{fs, path::PathBuf};

use anyhow::{Context, Result};
use clap::{Parser, ValueEnum};
use pixel_core::{DitherMode, PixelSession, PixelSettings};

#[derive(Debug, Parser)]
#[command(
    name = "pixel-forge",
    version,
    about = "写真を再現可能なピクセルアートへ変換します"
)]
struct Arguments {
    /// 入力するPNG、JPEG、PPM
    input: PathBuf,
    /// 出力PNG
    #[arg(short, long)]
    output: PathBuf,
    /// 縮小後の幅
    #[arg(long, default_value_t = 64)]
    width: u32,
    /// 縮小後の高さ
    #[arg(long, default_value_t = 64)]
    height: u32,
    /// paletteの最大色数
    #[arg(long, default_value_t = 12)]
    colors: u8,
    /// ディザリング方式
    #[arg(long, value_enum, default_value_t = CliDither::Bayer4x4)]
    dither: CliDither,
    /// nearest-neighborで拡大する整数倍率
    #[arg(long, default_value_t = 8)]
    scale: u32,
    /// recipe JSONの保存先。省略時は出力PNGと同じ場所に保存します
    #[arg(long)]
    recipe: Option<PathBuf>,
}

#[derive(Clone, Copy, Debug, ValueEnum)]
enum CliDither {
    None,
    Bayer4x4,
    FloydSteinberg,
}

impl From<CliDither> for DitherMode {
    fn from(value: CliDither) -> Self {
        match value {
            CliDither::None => Self::None,
            CliDither::Bayer4x4 => Self::Bayer4x4,
            CliDither::FloydSteinberg => Self::FloydSteinberg,
        }
    }
}

fn main() -> Result<()> {
    let arguments = Arguments::parse();
    let input = fs::read(&arguments.input)
        .with_context(|| format!("failed to read {}", arguments.input.display()))?;
    let session = PixelSession::new(&input).context("failed to decode input image")?;
    let result = session
        .render(PixelSettings {
            target_width: arguments.width,
            target_height: arguments.height,
            color_count: arguments.colors,
            dither: arguments.dither.into(),
            upscale: arguments.scale,
        })
        .context("failed to render pixel art")?;

    if let Some(parent) = arguments.output.parent() {
        fs::create_dir_all(parent)
            .with_context(|| format!("failed to create {}", parent.display()))?;
    }
    fs::write(&arguments.output, result.png_bytes)
        .with_context(|| format!("failed to write {}", arguments.output.display()))?;

    let recipe_path = arguments
        .recipe
        .unwrap_or_else(|| arguments.output.with_extension("recipe.json"));
    if let Some(parent) = recipe_path.parent() {
        fs::create_dir_all(parent)
            .with_context(|| format!("failed to create {}", parent.display()))?;
    }
    fs::write(&recipe_path, result.recipe_json)
        .with_context(|| format!("failed to write {}", recipe_path.display()))?;

    println!(
        "wrote {} ({}x{}, {} colors) and {}",
        arguments.output.display(),
        result.width,
        result.height,
        result.palette.len(),
        recipe_path.display()
    );
    Ok(())
}
