mod prompt;

use std::{
    fs,
    path::{Path, PathBuf},
};

use anyhow::{Context, Result};
use clap::{Args, Parser, Subcommand, ValueEnum};
use pixel_core::{DitherMode, PixelSession, PixelSettings};
use pixel_sprite::{SpriteBuilder, SpriteManifest};

#[derive(Debug, Parser)]
#[command(
    name = "pixel-forge",
    version,
    about = "画像を再現可能なピクセルアートとゲームアセットへ変換します"
)]
struct Arguments {
    #[command(subcommand)]
    command: Command,
}

#[derive(Debug, Subcommand)]
enum Command {
    /// 1枚の画像をピクセルアートPNGへ変換します
    Convert(ConvertArguments),
    /// AIパーツシートからアニメーション`Sprite Asset`を生成します
    Sprite {
        #[command(subcommand)]
        command: SpriteCommand,
    },
}

#[derive(Debug, Args)]
struct ConvertArguments {
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

#[derive(Debug, Subcommand)]
enum SpriteCommand {
    /// manifestからCodex imagegen用プロンプトを生成します
    Prompt {
        /// sprite manifest JSON
        manifest: PathBuf,
        /// imagegenへ渡すMarkdown prompt
        #[arg(short, long)]
        output: PathBuf,
    },
    /// source画像を読まずにmanifestを検証します
    Validate {
        /// sprite manifest JSON
        manifest: PathBuf,
    },
    /// 透過parts sheetから8-frame sprite assetを生成します
    Build {
        /// sprite manifest JSON
        manifest: PathBuf,
        /// chroma-key除去済みの透過PNG parts sheet
        #[arg(short, long)]
        source: PathBuf,
        /// asset出力directory
        #[arg(short, long)]
        output: PathBuf,
    },
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
    match Arguments::parse().command {
        Command::Convert(arguments) => convert(arguments),
        Command::Sprite { command } => sprite(command),
    }
}

fn convert(arguments: ConvertArguments) -> Result<()> {
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

    write_file(&arguments.output, &result.png_bytes)?;
    let recipe_path = arguments
        .recipe
        .unwrap_or_else(|| arguments.output.with_extension("recipe.json"));
    write_file(&recipe_path, result.recipe_json.as_bytes())?;

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

fn sprite(command: SpriteCommand) -> Result<()> {
    match command {
        SpriteCommand::Prompt { manifest, output } => {
            let manifest = read_manifest(&manifest)?;
            manifest.validate().context("sprite manifest is invalid")?;
            let rendered = prompt::render_imagegen_prompt(&manifest);
            write_file(&output, rendered.as_bytes())?;
            println!("wrote imagegen prompt {}", output.display());
        }
        SpriteCommand::Validate { manifest } => {
            let manifest = read_manifest(&manifest)?;
            manifest.validate().context("sprite manifest is invalid")?;
            println!(
                "{} is valid ({} parts, {} frames at {} fps)",
                manifest.id,
                manifest.parts.len(),
                manifest.animation.frames,
                manifest.animation.fps
            );
        }
        SpriteCommand::Build {
            manifest,
            source,
            output,
        } => {
            build_sprite(&manifest, &source, &output)?;
        }
    }
    Ok(())
}

fn build_sprite(manifest_path: &Path, source_path: &Path, output: &Path) -> Result<()> {
    let manifest = read_manifest(manifest_path)?;
    let source = fs::read(source_path)
        .with_context(|| format!("failed to read {}", source_path.display()))?;
    let result = SpriteBuilder::new(&source)
        .context("failed to decode sprite parts sheet")?
        .build(&manifest)
        .context("failed to build sprite assets")?;

    let animation = &manifest.animation.name;
    write_file(
        &output.join(format!("{animation}.png")),
        &result.logical_sheet_png,
    )?;
    write_file(
        &output.join(format!(
            "{animation}@{}x.png",
            manifest.render.preview_scale
        )),
        &result.scaled_sheet_png,
    )?;
    write_file(
        &output.join(format!("{animation}.json")),
        result.metadata_json.as_bytes(),
    )?;
    write_file(
        &output.join("sprite.recipe.json"),
        result.recipe_json.as_bytes(),
    )?;
    for part in &result.parts {
        write_file(
            &output.join("parts").join(format!("{}.png", part.id)),
            &part.png_bytes,
        )?;
    }
    for warning in &result.warnings {
        eprintln!("warning: {warning}");
    }
    println!(
        "wrote {} frames to {} ({}x{} logical pixels, {} fps)",
        result.frame_count,
        output.display(),
        result.frame_width,
        result.frame_height,
        result.fps
    );
    Ok(())
}

fn read_manifest(path: &Path) -> Result<SpriteManifest> {
    let bytes = fs::read(path).with_context(|| format!("failed to read {}", path.display()))?;
    serde_json::from_slice(&bytes)
        .with_context(|| format!("failed to decode sprite manifest {}", path.display()))
}

fn write_file(path: &Path, bytes: &[u8]) -> Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)
            .with_context(|| format!("failed to create {}", parent.display()))?;
    }
    fs::write(path, bytes).with_context(|| format!("failed to write {}", path.display()))
}
