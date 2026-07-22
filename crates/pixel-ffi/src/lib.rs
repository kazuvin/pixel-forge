use std::sync::Arc;

use pixel_core::{DitherMode, PixelSession, PixelSettings};
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

#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiPixelResult {
    pub png_bytes: Vec<u8>,
    pub width: u32,
    pub height: u32,
    pub palette: Vec<String>,
    pub recipe_json: String,
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
}

#[uniffi::export]
#[must_use]
pub fn algorithm_version() -> String {
    pixel_core::LEGACY_ALGORITHM_VERSION.into()
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

impl From<pixel_core::PixelError> for PixelFfiError {
    fn from(value: pixel_core::PixelError) -> Self {
        Self::Processing {
            message: value.to_string(),
        }
    }
}
