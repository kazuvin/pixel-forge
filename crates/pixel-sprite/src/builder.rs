use image::{
    ColorType, ImageEncoder, Rgba, RgbaImage, codecs::png::PngEncoder, imageops::FilterType,
};
use pixel_core::{PixelSession, PixelSettings};
use serde::Serialize;
use sha2::{Digest, Sha256};

use crate::{Offset, PartSpec, SpriteError, SpriteManifest};

const SPRITE_ALGORITHM_VERSION: &str = "0.1.0";
const SPRITE_RECIPE_SCHEMA_VERSION: u32 = 1;
const SPRITE_METADATA_SCHEMA_VERSION: u32 = 1;

#[derive(Clone, Debug)]
pub struct PartAsset {
    pub id: String,
    pub png_bytes: Vec<u8>,
}

#[derive(Clone, Debug)]
pub struct SpriteBuildResult {
    pub logical_sheet_png: Vec<u8>,
    pub scaled_sheet_png: Vec<u8>,
    pub metadata_json: String,
    pub recipe_json: String,
    pub parts: Vec<PartAsset>,
    pub frame_width: u32,
    pub frame_height: u32,
    pub frame_count: u32,
    pub fps: u32,
    pub warnings: Vec<String>,
}

pub struct SpriteBuilder {
    encoded_source: Vec<u8>,
    source: RgbaImage,
}

impl SpriteBuilder {
    /// Decodes a transparent parts sheet for repeatable sprite builds.
    ///
    /// # Errors
    ///
    /// Returns an error if the image cannot be decoded.
    pub fn new(encoded_source: &[u8]) -> Result<Self, SpriteError> {
        Ok(Self {
            encoded_source: encoded_source.to_vec(),
            source: image::load_from_memory(encoded_source)?.to_rgba8(),
        })
    }

    /// Pixelizes the entire parts sheet with one shared palette, composes every frame, and packs
    /// the frames horizontally.
    ///
    /// # Errors
    ///
    /// Returns an error for an invalid manifest, opaque source, empty part cell, core conversion
    /// failure, or output encoding failure.
    pub fn build(&self, manifest: &SpriteManifest) -> Result<SpriteBuildResult, SpriteError> {
        manifest.validate()?;
        if self.source.pixels().all(|pixel| pixel[3] == u8::MAX) {
            return Err(SpriteError::SourceHasNoTransparency);
        }

        let logical_size = manifest.logical_sheet_size();
        let session = PixelSession::new(&self.encoded_source)?;
        let pixelized = session.render(PixelSettings {
            target_width: logical_size.width,
            target_height: logical_size.height,
            color_count: manifest.render.color_count,
            dither: manifest.render.dither,
            upscale: 1,
        })?;
        let logical_parts_sheet = image::load_from_memory(&pixelized.png_bytes)?.to_rgba8();
        let mut parts = extract_parts(&logical_parts_sheet, manifest)?;
        parts.sort_by_key(|part| (part.spec.z_index, part.manifest_index));
        let logical_sheet = compose_sheet(&parts, manifest);
        let scaled_sheet = image::imageops::resize(
            &logical_sheet,
            logical_sheet.width() * manifest.render.preview_scale,
            logical_sheet.height() * manifest.render.preview_scale,
            FilterType::Nearest,
        );
        let part_assets = parts
            .iter()
            .map(|part| {
                Ok(PartAsset {
                    id: part.spec.id.clone(),
                    png_bytes: encode_png(&part.image)?,
                })
            })
            .collect::<Result<Vec<_>, SpriteError>>()?;
        let warnings = parts
            .iter()
            .filter(|part| touches_edge(&part.image))
            .map(|part| {
                format!(
                    "part {} touches its cell boundary; regenerate with more padding if it clips",
                    part.spec.id
                )
            })
            .collect::<Vec<_>>();
        let metadata_json = serde_json::to_string_pretty(&SpriteMetadata::new(manifest))?;
        let recipe_json = serde_json::to_string_pretty(&SpriteRecipe {
            schema_version: SPRITE_RECIPE_SCHEMA_VERSION,
            algorithm_version: SPRITE_ALGORITHM_VERSION,
            input_sha256: format!("{:x}", Sha256::digest(&self.encoded_source)),
            core_recipe: serde_json::from_str(&pixelized.recipe_json)?,
            manifest: manifest.clone(),
        })?;

        Ok(SpriteBuildResult {
            logical_sheet_png: encode_png(&logical_sheet)?,
            scaled_sheet_png: encode_png(&scaled_sheet)?,
            metadata_json,
            recipe_json,
            parts: part_assets,
            frame_width: manifest.canvas.width,
            frame_height: manifest.canvas.height,
            frame_count: manifest.animation.frames,
            fps: manifest.animation.fps,
            warnings,
        })
    }
}

struct PreparedPart<'manifest> {
    manifest_index: usize,
    spec: &'manifest PartSpec,
    image: RgbaImage,
}

fn extract_parts<'manifest>(
    sheet: &RgbaImage,
    manifest: &'manifest SpriteManifest,
) -> Result<Vec<PreparedPart<'manifest>>, SpriteError> {
    manifest
        .parts
        .iter()
        .enumerate()
        .map(|(manifest_index, part)| {
            let x = part.cell.column * manifest.grid.logical_cell_width;
            let y = part.cell.row * manifest.grid.logical_cell_height;
            let image = image::imageops::crop_imm(
                sheet,
                x,
                y,
                manifest.grid.logical_cell_width,
                manifest.grid.logical_cell_height,
            )
            .to_image();
            if image.pixels().all(|pixel| pixel[3] == 0) {
                return Err(SpriteError::EmptyPart(part.id.clone()));
            }
            Ok(PreparedPart {
                manifest_index,
                spec: part,
                image,
            })
        })
        .collect()
}

fn compose_sheet(parts: &[PreparedPart<'_>], manifest: &SpriteManifest) -> RgbaImage {
    let mut sheet = RgbaImage::new(
        manifest.canvas.width * manifest.animation.frames,
        manifest.canvas.height,
    );
    for frame in 0..manifest.animation.frames {
        let frame_x = frame * manifest.canvas.width;
        for part in parts {
            composite_part(
                &mut sheet,
                &part.image,
                frame_x,
                manifest.canvas.width,
                manifest.canvas.height,
                part.spec,
                part.spec.offsets[frame as usize],
            );
        }
    }
    sheet
}

fn composite_part(
    sheet: &mut RgbaImage,
    part: &RgbaImage,
    frame_x: u32,
    frame_width: u32,
    frame_height: u32,
    spec: &PartSpec,
    offset: Offset,
) {
    let left = spec.position.x + offset.x - spec.anchor.x;
    let top = spec.position.y + offset.y - spec.anchor.y;
    for (source_x, source_y, source) in part.enumerate_pixels() {
        if source[3] == 0 {
            continue;
        }
        let destination_x = left + i32::try_from(source_x).expect("cell width fits in i32");
        let destination_y = top + i32::try_from(source_y).expect("cell height fits in i32");
        let Ok(destination_x) = u32::try_from(destination_x) else {
            continue;
        };
        let Ok(destination_y) = u32::try_from(destination_y) else {
            continue;
        };
        if destination_x >= frame_width || destination_y >= frame_height {
            continue;
        }
        let destination = sheet.get_pixel_mut(frame_x + destination_x, destination_y);
        *destination = over(*source, *destination);
    }
}

fn over(source: Rgba<u8>, destination: Rgba<u8>) -> Rgba<u8> {
    if source[3] == u8::MAX {
        return source;
    }
    let source_alpha = u32::from(source[3]);
    let destination_alpha = u32::from(destination[3]);
    let inverse_source = u32::from(u8::MAX) - source_alpha;
    let output_alpha = source_alpha + (destination_alpha * inverse_source + 127) / 255;
    if output_alpha == 0 {
        return Rgba([0, 0, 0, 0]);
    }
    let channel = |index: usize| {
        let source_premultiplied = u32::from(source[index]) * source_alpha;
        let destination_premultiplied =
            u32::from(destination[index]) * destination_alpha * inverse_source / 255;
        u8::try_from(
            (source_premultiplied + destination_premultiplied + output_alpha / 2) / output_alpha,
        )
        .expect("alpha compositing channel stays in u8")
    };
    Rgba([
        channel(0),
        channel(1),
        channel(2),
        u8::try_from(output_alpha).expect("alpha compositing alpha stays in u8"),
    ])
}

fn touches_edge(image: &RgbaImage) -> bool {
    (0..image.width())
        .any(|x| image.get_pixel(x, 0)[3] > 0 || image.get_pixel(x, image.height() - 1)[3] > 0)
        || (0..image.height())
            .any(|y| image.get_pixel(0, y)[3] > 0 || image.get_pixel(image.width() - 1, y)[3] > 0)
}

fn encode_png(image: &RgbaImage) -> Result<Vec<u8>, SpriteError> {
    let mut bytes = Vec::new();
    PngEncoder::new(&mut bytes).write_image(
        image.as_raw(),
        image.width(),
        image.height(),
        ColorType::Rgba8.into(),
    )?;
    Ok(bytes)
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct SpriteMetadata {
    schema_version: u32,
    image: String,
    animation: String,
    frame_width: u32,
    frame_height: u32,
    frame_count: u32,
    fps: u32,
    layout: &'static str,
    frames: Vec<FrameMetadata>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct FrameMetadata {
    index: u32,
    x: u32,
    y: u32,
    width: u32,
    height: u32,
}

impl SpriteMetadata {
    fn new(manifest: &SpriteManifest) -> Self {
        Self {
            schema_version: SPRITE_METADATA_SCHEMA_VERSION,
            image: format!("{}.png", manifest.animation.name),
            animation: manifest.animation.name.clone(),
            frame_width: manifest.canvas.width,
            frame_height: manifest.canvas.height,
            frame_count: manifest.animation.frames,
            fps: manifest.animation.fps,
            layout: "horizontal",
            frames: (0..manifest.animation.frames)
                .map(|index| FrameMetadata {
                    index,
                    x: index * manifest.canvas.width,
                    y: 0,
                    width: manifest.canvas.width,
                    height: manifest.canvas.height,
                })
                .collect(),
        }
    }
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct SpriteRecipe {
    schema_version: u32,
    algorithm_version: &'static str,
    input_sha256: String,
    core_recipe: serde_json::Value,
    manifest: SpriteManifest,
}

#[cfg(test)]
pub(crate) mod tests {
    use pixel_core::DitherMode;

    use super::*;
    use crate::{
        AnimationSpec, Cell, GenerationSpec, GridSpec, Point, RenderSpec, Size, SpriteManifest,
    };

    pub(crate) fn fixture_manifest() -> SpriteManifest {
        SpriteManifest {
            schema_version: 1,
            id: "fixture".into(),
            generation: GenerationSpec {
                description: "fixture".into(),
                style: "fixture".into(),
                view: "front".into(),
                palette: "red and blue".into(),
                chroma_key: "#00FF00".into(),
                avoid: vec![],
            },
            grid: GridSpec {
                columns: 2,
                rows: 1,
                logical_cell_width: 4,
                logical_cell_height: 4,
            },
            canvas: Size {
                width: 8,
                height: 8,
            },
            render: RenderSpec {
                color_count: 2,
                dither: DitherMode::None,
                preview_scale: 1,
            },
            animation: AnimationSpec {
                name: "idle".into(),
                frames: 1,
                fps: 8,
            },
            parts: vec![
                PartSpec {
                    id: "body".into(),
                    cell: Cell { column: 0, row: 0 },
                    anchor: Point { x: 2, y: 2 },
                    position: Point { x: 4, y: 4 },
                    z_index: 1,
                    offsets: vec![Offset::default()],
                },
                PartSpec {
                    id: "head".into(),
                    cell: Cell { column: 1, row: 0 },
                    anchor: Point { x: 2, y: 2 },
                    position: Point { x: 4, y: 2 },
                    z_index: 2,
                    offsets: vec![Offset::default()],
                },
            ],
        }
    }

    #[test]
    fn source_over_blending_is_deterministic() {
        assert_eq!(
            over(Rgba([200, 0, 0, 128]), Rgba([0, 0, 200, 255])),
            Rgba([100, 0, 100, 255])
        );
    }
}
