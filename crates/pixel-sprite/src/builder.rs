use image::{
    ColorType, ImageEncoder, Rgba, RgbaImage, codecs::png::PngEncoder, imageops::FilterType,
};
use pixel_core::{MAX_TARGET_SIDE, PixelSession, PixelSettings};
use serde::Serialize;
use sha2::{Digest, Sha256};

use crate::{PartSpec, ResizeAnchor, SpriteError, SpriteManifest};

const SPRITE_ALGORITHM_VERSION: &str = "0.2.0";
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
        let logical_sheet = compose_sheet(&parts, manifest)?;
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
    opaque_bounds: OpaqueBounds,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
struct OpaqueBounds {
    left: u32,
    top: u32,
    width: u32,
    height: u32,
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
            let opaque_bounds =
                find_opaque_bounds(&image).expect("empty part was rejected before measuring");
            Ok(PreparedPart {
                manifest_index,
                spec: part,
                image,
                opaque_bounds,
            })
        })
        .collect()
}

fn compose_sheet(
    parts: &[PreparedPart<'_>],
    manifest: &SpriteManifest,
) -> Result<RgbaImage, SpriteError> {
    let mut sheet = RgbaImage::new(
        manifest.canvas.width * manifest.animation.frames,
        manifest.canvas.height,
    );
    for frame in 0..manifest.animation.frames {
        let frame_x = frame * manifest.canvas.width;
        let mut frame_parts = parts.iter().collect::<Vec<_>>();
        frame_parts.sort_by_key(|part| {
            (
                part.spec.effective_z_index(frame as usize),
                part.manifest_index,
            )
        });
        for part in frame_parts {
            let transformed = transform_part(part, frame)?;
            composite_part(
                &mut sheet,
                &transformed.image,
                frame_x,
                manifest.canvas.width,
                manifest.canvas.height,
                transformed.left,
                transformed.top,
            );
        }
    }
    Ok(sheet)
}

struct TransformedPart {
    image: RgbaImage,
    left: i32,
    top: i32,
}

fn transform_part(part: &PreparedPart<'_>, frame: u32) -> Result<TransformedPart, SpriteError> {
    let offset = part.spec.offsets[frame as usize];
    let size_delta = part.spec.size_delta(frame as usize);
    let bounds = part.opaque_bounds;
    let target_width = i64::from(bounds.width) + i64::from(size_delta.width);
    let target_height = i64::from(bounds.height) + i64::from(size_delta.height);
    if !(1..=i64::from(MAX_TARGET_SIDE)).contains(&target_width)
        || !(1..=i64::from(MAX_TARGET_SIDE)).contains(&target_height)
    {
        return Err(SpriteError::PartResizeOutsideBounds {
            id: part.spec.id.clone(),
            frame,
            width: target_width,
            height: target_height,
            maximum: MAX_TARGET_SIDE,
        });
    }
    let target_width = u32::try_from(target_width).expect("validated resize width fits in u32");
    let target_height = u32::try_from(target_height).expect("validated resize height fits in u32");
    let content = image::imageops::crop_imm(
        &part.image,
        bounds.left,
        bounds.top,
        bounds.width,
        bounds.height,
    )
    .to_image();
    let image = if target_width == bounds.width && target_height == bounds.height {
        content
    } else {
        image::imageops::resize(&content, target_width, target_height, FilterType::Nearest)
    };
    let (source_pivot_x, source_pivot_y) =
        pivot_offsets(bounds.width, bounds.height, part.spec.resize_anchor);
    let (target_pivot_x, target_pivot_y) =
        pivot_offsets(target_width, target_height, part.spec.resize_anchor);
    let cell_left =
        i64::from(part.spec.position.x) + i64::from(offset.x) - i64::from(part.spec.anchor.x);
    let cell_top =
        i64::from(part.spec.position.y) + i64::from(offset.y) - i64::from(part.spec.anchor.y);
    let left =
        cell_left + i64::from(bounds.left) + i64::from(source_pivot_x) - i64::from(target_pivot_x);
    let top =
        cell_top + i64::from(bounds.top) + i64::from(source_pivot_y) - i64::from(target_pivot_y);

    Ok(TransformedPart {
        image,
        left: clamp_i64_to_i32(left),
        top: clamp_i64_to_i32(top),
    })
}

fn pivot_offsets(width: u32, height: u32, anchor: ResizeAnchor) -> (u32, u32) {
    let x = match anchor {
        ResizeAnchor::TopLeft | ResizeAnchor::CenterLeft | ResizeAnchor::BottomLeft => 0,
        ResizeAnchor::TopCenter | ResizeAnchor::Center | ResizeAnchor::BottomCenter => width / 2,
        ResizeAnchor::TopRight | ResizeAnchor::CenterRight | ResizeAnchor::BottomRight => width,
    };
    let y = match anchor {
        ResizeAnchor::TopLeft | ResizeAnchor::TopCenter | ResizeAnchor::TopRight => 0,
        ResizeAnchor::CenterLeft | ResizeAnchor::Center | ResizeAnchor::CenterRight => height / 2,
        ResizeAnchor::BottomLeft | ResizeAnchor::BottomCenter | ResizeAnchor::BottomRight => height,
    };
    (x, y)
}

fn clamp_i64_to_i32(value: i64) -> i32 {
    i32::try_from(value.clamp(i64::from(i32::MIN), i64::from(i32::MAX)))
        .expect("clamped coordinate fits in i32")
}

fn composite_part(
    sheet: &mut RgbaImage,
    part: &RgbaImage,
    frame_x: u32,
    frame_width: u32,
    frame_height: u32,
    left: i32,
    top: i32,
) {
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

fn find_opaque_bounds(image: &RgbaImage) -> Option<OpaqueBounds> {
    let mut left = image.width();
    let mut top = image.height();
    let mut right = 0;
    let mut bottom = 0;
    let mut found = false;
    for (x, y, pixel) in image.enumerate_pixels() {
        if pixel[3] == 0 {
            continue;
        }
        found = true;
        left = left.min(x);
        top = top.min(y);
        right = right.max(x);
        bottom = bottom.max(y);
    }
    found.then_some(OpaqueBounds {
        left,
        top,
        width: right - left + 1,
        height: bottom - top + 1,
    })
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
        AnimationSpec, Cell, GenerationSpec, GridSpec, Offset, Point, RenderSpec, ResizeAnchor,
        Size, SizeDelta, SpriteManifest,
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
                    size_deltas: vec![],
                    z_index_deltas: vec![],
                    resize_anchor: ResizeAnchor::Center,
                },
                PartSpec {
                    id: "head".into(),
                    cell: Cell { column: 1, row: 0 },
                    anchor: Point { x: 2, y: 2 },
                    position: Point { x: 4, y: 2 },
                    z_index: 2,
                    offsets: vec![Offset::default()],
                    size_deltas: vec![],
                    z_index_deltas: vec![],
                    resize_anchor: ResizeAnchor::Center,
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

    #[test]
    fn bottom_anchored_resize_keeps_the_opaque_footprint_grounded() {
        let mut image = RgbaImage::new(6, 6);
        let colors = [
            Rgba([220, 80, 40, 255]),
            Rgba([180, 60, 30, 255]),
            Rgba([140, 40, 20, 255]),
            Rgba([100, 20, 10, 255]),
        ];
        for (row, color) in colors.into_iter().enumerate() {
            let y = u32::try_from(row).expect("fixture row fits in u32") + 1;
            image.put_pixel(2, y, color);
            image.put_pixel(3, y, color);
        }
        let spec = PartSpec {
            id: "leg".into(),
            cell: Cell { column: 0, row: 0 },
            anchor: Point { x: 0, y: 0 },
            position: Point { x: 0, y: 0 },
            z_index: 0,
            offsets: vec![Offset::default()],
            size_deltas: vec![SizeDelta {
                width: 0,
                height: -2,
            }],
            z_index_deltas: vec![0],
            resize_anchor: ResizeAnchor::BottomCenter,
        };
        let prepared = PreparedPart {
            manifest_index: 0,
            spec: &spec,
            opaque_bounds: find_opaque_bounds(&image).expect("fixture has opaque pixels"),
            image,
        };

        let transformed = transform_part(&prepared, 0).expect("resize should succeed");

        assert_eq!(transformed.image.dimensions(), (2, 2));
        assert_eq!((transformed.left, transformed.top), (2, 3));
        assert_eq!(
            transformed.top
                + i32::try_from(transformed.image.height()).expect("fixture height fits in i32"),
            5
        );
        assert!(
            transformed
                .image
                .pixels()
                .all(|pixel| colors.contains(pixel))
        );
    }

    #[test]
    fn frame_z_delta_can_move_a_part_in_front_without_changing_base_order() {
        let mut manifest = fixture_manifest();
        manifest.schema_version = 2;
        manifest.animation.frames = 2;
        for part in &mut manifest.parts {
            part.anchor = Point { x: 0, y: 0 };
            part.position = Point { x: 4, y: 4 };
            part.offsets = vec![Offset::default(); 2];
            part.size_deltas = vec![SizeDelta::default(); 2];
        }
        manifest.parts[0].z_index_deltas = vec![0, 10];
        manifest.parts[1].z_index_deltas = vec![0, -10];
        let body = RgbaImage::from_pixel(1, 1, Rgba([220, 50, 40, 255]));
        let head = RgbaImage::from_pixel(1, 1, Rgba([40, 80, 220, 255]));
        let parts = vec![
            PreparedPart {
                manifest_index: 0,
                spec: &manifest.parts[0],
                opaque_bounds: find_opaque_bounds(&body).expect("body is opaque"),
                image: body,
            },
            PreparedPart {
                manifest_index: 1,
                spec: &manifest.parts[1],
                opaque_bounds: find_opaque_bounds(&head).expect("head is opaque"),
                image: head,
            },
        ];

        let sheet = compose_sheet(&parts, &manifest).expect("composition should succeed");

        assert_eq!(sheet.get_pixel(4, 4), &Rgba([40, 80, 220, 255]));
        assert_eq!(sheet.get_pixel(12, 4), &Rgba([220, 50, 40, 255]));
    }
}
