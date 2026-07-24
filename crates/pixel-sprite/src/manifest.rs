use std::collections::BTreeSet;

use pixel_core::{
    DitherMode, MAX_COLOR_COUNT, MAX_OUTPUT_SIDE, MAX_TARGET_SIDE, MAX_UPSCALE, MIN_COLOR_COUNT,
};
use serde::{Deserialize, Serialize};

use crate::SpriteManifestError;

pub const SPRITE_MANIFEST_SCHEMA_VERSION: u32 = 1;
pub const MAX_ANIMATION_FRAMES: u32 = 64;
pub const MAX_ANIMATION_FPS: u32 = 60;

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SpriteManifest {
    pub schema_version: u32,
    pub id: String,
    pub generation: GenerationSpec,
    pub grid: GridSpec,
    pub canvas: Size,
    pub render: RenderSpec,
    pub animation: AnimationSpec,
    pub parts: Vec<PartSpec>,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct GenerationSpec {
    pub description: String,
    pub style: String,
    pub view: String,
    pub palette: String,
    pub chroma_key: String,
    #[serde(default)]
    pub avoid: Vec<String>,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct GridSpec {
    pub columns: u32,
    pub rows: u32,
    pub logical_cell_width: u32,
    pub logical_cell_height: u32,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Size {
    pub width: u32,
    pub height: u32,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct RenderSpec {
    pub color_count: u8,
    pub dither: DitherMode,
    pub preview_scale: u32,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AnimationSpec {
    pub name: String,
    pub frames: u32,
    pub fps: u32,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PartSpec {
    pub id: String,
    pub cell: Cell,
    pub anchor: Point,
    pub position: Point,
    pub z_index: i32,
    pub offsets: Vec<Offset>,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Cell {
    pub column: u32,
    pub row: u32,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Point {
    pub x: i32,
    pub y: i32,
}

#[derive(Clone, Copy, Debug, Default, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Offset {
    pub x: i32,
    pub y: i32,
}

impl SpriteManifest {
    /// Validates the portable sprite recipe before source pixels are processed.
    ///
    /// # Errors
    ///
    /// Returns the first invalid manifest field in a stable order.
    pub fn validate(&self) -> Result<(), SpriteManifestError> {
        if self.schema_version != SPRITE_MANIFEST_SCHEMA_VERSION {
            return Err(SpriteManifestError::UnsupportedSchemaVersion {
                provided: self.schema_version,
                supported: SPRITE_MANIFEST_SCHEMA_VERSION,
            });
        }
        validate_identifier("sprite", &self.id)?;
        if self.generation.description.trim().is_empty() {
            return Err(SpriteManifestError::EmptyGenerationField("description"));
        }
        if self.generation.style.trim().is_empty() {
            return Err(SpriteManifestError::EmptyGenerationField("style"));
        }
        if self.generation.view.trim().is_empty() {
            return Err(SpriteManifestError::EmptyGenerationField("view"));
        }
        if self.generation.palette.trim().is_empty() {
            return Err(SpriteManifestError::EmptyGenerationField("palette"));
        }
        if !is_hex_color(&self.generation.chroma_key) {
            return Err(SpriteManifestError::InvalidChromaKey(
                self.generation.chroma_key.clone(),
            ));
        }
        self.validate_dimensions()?;
        self.validate_animation()?;
        self.validate_parts()
    }

    fn validate_dimensions(&self) -> Result<(), SpriteManifestError> {
        if self.grid.columns == 0
            || self.grid.rows == 0
            || self.grid.logical_cell_width == 0
            || self.grid.logical_cell_height == 0
        {
            return Err(SpriteManifestError::EmptyGrid);
        }
        let logical_width = self
            .grid
            .columns
            .checked_mul(self.grid.logical_cell_width)
            .ok_or(SpriteManifestError::LogicalSheetTooLarge)?;
        let logical_height = self
            .grid
            .rows
            .checked_mul(self.grid.logical_cell_height)
            .ok_or(SpriteManifestError::LogicalSheetTooLarge)?;
        if logical_width > MAX_TARGET_SIDE || logical_height > MAX_TARGET_SIDE {
            return Err(SpriteManifestError::LogicalSheetOutsideBounds {
                width: logical_width,
                height: logical_height,
                maximum: MAX_TARGET_SIDE,
            });
        }
        if self.canvas.width == 0 || self.canvas.height == 0 {
            return Err(SpriteManifestError::EmptyCanvas);
        }
        if self.canvas.width > MAX_TARGET_SIDE || self.canvas.height > MAX_TARGET_SIDE {
            return Err(SpriteManifestError::CanvasOutsideBounds {
                width: self.canvas.width,
                height: self.canvas.height,
                maximum: MAX_TARGET_SIDE,
            });
        }
        Ok(())
    }

    fn validate_animation(&self) -> Result<(), SpriteManifestError> {
        if !(MIN_COLOR_COUNT..=MAX_COLOR_COUNT).contains(&self.render.color_count) {
            return Err(SpriteManifestError::ColorCountOutsideBounds {
                provided: self.render.color_count,
                minimum: MIN_COLOR_COUNT,
                maximum: MAX_COLOR_COUNT,
            });
        }
        if !(1..=MAX_ANIMATION_FRAMES).contains(&self.animation.frames) {
            return Err(SpriteManifestError::FrameCountOutsideBounds {
                provided: self.animation.frames,
                maximum: MAX_ANIMATION_FRAMES,
            });
        }
        if !(1..=MAX_ANIMATION_FPS).contains(&self.animation.fps) {
            return Err(SpriteManifestError::FpsOutsideBounds {
                provided: self.animation.fps,
                maximum: MAX_ANIMATION_FPS,
            });
        }
        validate_identifier("animation", &self.animation.name)?;
        if !(1..=MAX_UPSCALE).contains(&self.render.preview_scale) {
            return Err(SpriteManifestError::PreviewScaleOutsideBounds {
                provided: self.render.preview_scale,
                maximum: MAX_UPSCALE,
            });
        }
        let sheet_width = self
            .canvas
            .width
            .checked_mul(self.animation.frames)
            .and_then(|width| width.checked_mul(self.render.preview_scale))
            .ok_or(SpriteManifestError::OutputSheetTooLarge)?;
        let sheet_height = self
            .canvas
            .height
            .checked_mul(self.render.preview_scale)
            .ok_or(SpriteManifestError::OutputSheetTooLarge)?;
        if sheet_width > MAX_OUTPUT_SIDE || sheet_height > MAX_OUTPUT_SIDE {
            return Err(SpriteManifestError::OutputSheetOutsideBounds {
                width: sheet_width,
                height: sheet_height,
                maximum: MAX_OUTPUT_SIDE,
            });
        }
        Ok(())
    }

    fn validate_parts(&self) -> Result<(), SpriteManifestError> {
        if self.parts.is_empty() {
            return Err(SpriteManifestError::NoParts);
        }

        let mut identifiers = BTreeSet::new();
        let mut cells = BTreeSet::new();
        for part in &self.parts {
            validate_identifier("part", &part.id)?;
            if !identifiers.insert(part.id.as_str()) {
                return Err(SpriteManifestError::DuplicatePartId(part.id.clone()));
            }
            if !cells.insert((part.cell.column, part.cell.row)) {
                return Err(SpriteManifestError::DuplicatePartCell {
                    column: part.cell.column,
                    row: part.cell.row,
                });
            }
            if part.cell.column >= self.grid.columns || part.cell.row >= self.grid.rows {
                return Err(SpriteManifestError::PartCellOutsideGrid {
                    id: part.id.clone(),
                    column: part.cell.column,
                    row: part.cell.row,
                });
            }
            if part.anchor.x < 0
                || part.anchor.y < 0
                || u32::try_from(part.anchor.x).is_ok_and(|x| x > self.grid.logical_cell_width)
                || u32::try_from(part.anchor.y).is_ok_and(|y| y > self.grid.logical_cell_height)
            {
                return Err(SpriteManifestError::PartAnchorOutsideCell {
                    id: part.id.clone(),
                    x: part.anchor.x,
                    y: part.anchor.y,
                });
            }
            if part.offsets.len() != self.animation.frames as usize {
                return Err(SpriteManifestError::PartFrameCountMismatch {
                    id: part.id.clone(),
                    provided: part.offsets.len(),
                    expected: self.animation.frames,
                });
            }
        }
        Ok(())
    }

    #[must_use]
    pub const fn logical_sheet_size(&self) -> Size {
        Size {
            width: self.grid.columns * self.grid.logical_cell_width,
            height: self.grid.rows * self.grid.logical_cell_height,
        }
    }
}

fn validate_identifier(kind: &'static str, value: &str) -> Result<(), SpriteManifestError> {
    if value.is_empty()
        || !value
            .bytes()
            .all(|byte| byte.is_ascii_lowercase() || byte.is_ascii_digit() || byte == b'-')
    {
        return Err(SpriteManifestError::InvalidIdentifier {
            kind,
            value: value.into(),
        });
    }
    Ok(())
}

fn is_hex_color(value: &str) -> bool {
    value.len() == 7
        && value.starts_with('#')
        && value[1..].bytes().all(|byte| byte.is_ascii_hexdigit())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_reused_cells_before_reading_source_pixels() {
        let mut manifest = crate::builder::tests::fixture_manifest();
        manifest.parts[1].cell = manifest.parts[0].cell;

        assert!(matches!(
            manifest.validate(),
            Err(SpriteManifestError::DuplicatePartCell { column: 0, row: 0 })
        ));
    }
}
