use std::sync::Arc;

use pixel_core::{
    ColorMode, CropRect, CropRegion, DitherMode, OutlineMode, OutlineSettings, Palette,
    PaletteApplication, PixelSession, PixelSettings, RenderSettings, RgbColor, TonePreservation,
};
use thiserror::Error;

uniffi::setup_scaffolding!();

#[derive(Clone, Copy, Debug, uniffi::Enum)]
pub enum FfiDitherMode {
    None,
    Bayer4x4,
    FloydSteinberg,
}

#[derive(Clone, Copy, Debug, uniffi::Record)]
pub struct FfiPixelSettings {
    pub target_width: u32,
    pub target_height: u32,
    pub color_count: u8,
    pub dither: FfiDitherMode,
    pub upscale: u32,
}

#[derive(Clone, Copy, Debug, uniffi::Record)]
pub struct FfiRgbColor {
    pub red: u8,
    pub green: u8,
    pub blue: u8,
}

#[derive(Clone, Copy, Debug, uniffi::Record)]
pub struct FfiCropRect {
    pub x: u32,
    pub y: u32,
    pub width: u32,
    pub height: u32,
}

#[derive(Clone, Copy, Debug, uniffi::Enum)]
pub enum FfiCropRegion {
    Full,
    Rectangle { rect: FfiCropRect },
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiPalette {
    pub name: String,
    pub colors: Vec<FfiRgbColor>,
}

#[derive(Clone, Copy, Debug, uniffi::Enum)]
pub enum FfiPaletteApplication {
    Exact,
    PreserveTone { saturation: u8, lightness: u8 },
}

#[derive(Clone, Debug, uniffi::Enum)]
pub enum FfiColorMode {
    Source,
    Palette {
        palette: FfiPalette,
        application: FfiPaletteApplication,
    },
}

#[derive(Clone, Copy, Debug, uniffi::Enum)]
pub enum FfiOutlineMode {
    None,
    Black,
    Adaptive,
}

#[derive(Clone, Copy, Debug, uniffi::Record)]
pub struct FfiOutlineSettings {
    pub mode: FfiOutlineMode,
    pub threshold: u8,
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiRenderSettings {
    pub long_side: u32,
    pub upscale: u32,
    pub crop: FfiCropRegion,
    pub color_mode: FfiColorMode,
    pub outline: FfiOutlineSettings,
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiPixelResult {
    pub png_bytes: Vec<u8>,
    pub width: u32,
    pub height: u32,
    pub palette: Vec<String>,
    pub recipe_json: String,
}

#[derive(Clone, Copy, Debug, uniffi::Record)]
pub struct FfiImageDimensions {
    pub width: u32,
    pub height: u32,
}

#[derive(Debug, Error, uniffi::Error)]
pub enum PixelFfiError {
    #[error("pixel processing failed: {message}")]
    Processing { message: String },
}

#[derive(uniffi::Object)]
pub struct PixelEngine {
    session: PixelSession,
}

#[uniffi::export]
impl PixelEngine {
    #[uniffi::constructor]
    /// Creates an engine that keeps the decoded source image in Rust.
    ///
    /// # Errors
    ///
    /// Returns [`PixelFfiError`] when the source bytes cannot be decoded.
    #[allow(clippy::needless_pass_by_value)]
    pub fn new(image_bytes: Vec<u8>) -> Result<Arc<Self>, PixelFfiError> {
        let session = PixelSession::new(&image_bytes).map_err(PixelFfiError::from)?;
        Ok(Arc::new(Self { session }))
    }

    /// Renders a recipe through `pixel-core`.
    ///
    /// # Errors
    ///
    /// Returns [`PixelFfiError`] when settings or image encoding fail.
    pub fn render(&self, settings: FfiPixelSettings) -> Result<FfiPixelResult, PixelFfiError> {
        let result = self
            .session
            .render(PixelSettings {
                target_width: settings.target_width,
                target_height: settings.target_height,
                color_count: settings.color_count,
                dither: settings.dither.into(),
                upscale: settings.upscale,
            })
            .map_err(PixelFfiError::from)?;
        Ok(FfiPixelResult {
            png_bytes: result.png_bytes,
            width: result.width,
            height: result.height,
            palette: result.palette,
            recipe_json: result.recipe_json,
        })
    }

    /// Converts an image through the canonical v1 contract.
    ///
    /// # Errors
    ///
    /// Returns [`PixelFfiError`] when settings or image encoding fail.
    pub fn convert(&self, settings: FfiRenderSettings) -> Result<FfiPixelResult, PixelFfiError> {
        let result = self
            .session
            .convert(settings.into())
            .map_err(PixelFfiError::from)?;
        Ok(FfiPixelResult {
            png_bytes: result.png_bytes,
            width: result.width,
            height: result.height,
            palette: result.palette,
            recipe_json: result.recipe_json,
        })
    }

    #[must_use]
    pub fn source_dimensions(&self) -> FfiImageDimensions {
        let (width, height) = self.session.source_dimensions();
        FfiImageDimensions { width, height }
    }
}

#[uniffi::export]
#[must_use]
pub fn algorithm_version() -> String {
    pixel_core::ALGORITHM_VERSION.into()
}

impl From<FfiDitherMode> for DitherMode {
    fn from(value: FfiDitherMode) -> Self {
        match value {
            FfiDitherMode::None => Self::None,
            FfiDitherMode::Bayer4x4 => Self::Bayer4x4,
            FfiDitherMode::FloydSteinberg => Self::FloydSteinberg,
        }
    }
}

impl From<FfiCropRegion> for CropRegion {
    fn from(value: FfiCropRegion) -> Self {
        match value {
            FfiCropRegion::Full => Self::Full,
            FfiCropRegion::Rectangle { rect } => Self::Rectangle { rect: rect.into() },
        }
    }
}

impl From<FfiCropRect> for CropRect {
    fn from(value: FfiCropRect) -> Self {
        Self {
            x: value.x,
            y: value.y,
            width: value.width,
            height: value.height,
        }
    }
}

impl From<FfiRgbColor> for RgbColor {
    fn from(value: FfiRgbColor) -> Self {
        Self::new(value.red, value.green, value.blue)
    }
}

impl From<FfiPalette> for Palette {
    fn from(value: FfiPalette) -> Self {
        Self {
            name: value.name,
            colors: value.colors.into_iter().map(Into::into).collect(),
        }
    }
}

impl From<FfiPaletteApplication> for PaletteApplication {
    fn from(value: FfiPaletteApplication) -> Self {
        match value {
            FfiPaletteApplication::Exact => Self::Exact,
            FfiPaletteApplication::PreserveTone {
                saturation,
                lightness,
            } => Self::PreserveTone {
                preservation: TonePreservation {
                    saturation,
                    lightness,
                },
            },
        }
    }
}

impl From<FfiColorMode> for ColorMode {
    fn from(value: FfiColorMode) -> Self {
        match value {
            FfiColorMode::Source => Self::Source,
            FfiColorMode::Palette {
                palette,
                application,
            } => Self::Palette {
                palette: palette.into(),
                application: application.into(),
            },
        }
    }
}

impl From<FfiOutlineMode> for OutlineMode {
    fn from(value: FfiOutlineMode) -> Self {
        match value {
            FfiOutlineMode::None => Self::None,
            FfiOutlineMode::Black => Self::Black,
            FfiOutlineMode::Adaptive => Self::Adaptive,
        }
    }
}

impl From<FfiOutlineSettings> for OutlineSettings {
    fn from(value: FfiOutlineSettings) -> Self {
        Self {
            mode: value.mode.into(),
            threshold: value.threshold,
        }
    }
}

impl From<FfiRenderSettings> for RenderSettings {
    fn from(value: FfiRenderSettings) -> Self {
        Self {
            long_side: value.long_side,
            upscale: value.upscale,
            crop: value.crop.into(),
            color_mode: value.color_mode.into(),
            outline: value.outline.into(),
        }
    }
}

impl From<pixel_core::PixelError> for PixelFfiError {
    fn from(value: pixel_core::PixelError) -> Self {
        Self::Processing {
            message: value.to_string(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn convert_exposes_the_v1_recipe_contract() {
        let engine = PixelEngine::new(
            b"P3\n3 2\n255\n255 0 0 0 255 0 0 0 255 255 255 255 0 0 0 128 128 128\n".to_vec(),
        )
        .expect("fixture should decode");

        let result = engine
            .convert(FfiRenderSettings {
                long_side: 3,
                upscale: 2,
                crop: FfiCropRegion::Full,
                color_mode: FfiColorMode::Source,
                outline: FfiOutlineSettings {
                    mode: FfiOutlineMode::None,
                    threshold: 15,
                },
            })
            .expect("v1 conversion should succeed");

        assert_eq!((result.width, result.height), (6, 4));
        assert_eq!(
            (
                engine.source_dimensions().width,
                engine.source_dimensions().height
            ),
            (3, 2)
        );
        assert!(result.recipe_json.contains("\"schemaVersion\": 2"));
        assert!(
            result
                .recipe_json
                .contains("\"algorithmVersion\": \"1.2.0\"")
        );
    }
}
