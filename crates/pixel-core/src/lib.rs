mod color;
mod converter_settings;
mod decode;
mod error;
mod outline;
mod palette;
mod quantize;
mod recipe;
mod session;
mod settings;
mod transform;

pub use converter_settings::{
    ColorMode, CropRect, CropRegion, MAX_PALETTE_COLORS, OutlineMode, OutlineSettings, Palette,
    PaletteApplication, RenderSettings, RgbColor, TonePreservation,
};
pub use error::{PixelError, RenderSettingsError, SettingsError};
pub use recipe::{
    ALGORITHM_VERSION, CropMode, LEGACY_ALGORITHM_VERSION, PixelRecipe, RECIPE_SCHEMA_VERSION,
    RENDER_RECIPE_SCHEMA_VERSION, RenderRecipe,
};
pub use session::{PixelResult, PixelSession};
pub use settings::{
    DitherMode, MAX_COLOR_COUNT, MAX_INPUT_PIXELS, MAX_OUTPUT_SIDE, MAX_TARGET_SIDE, MAX_UPSCALE,
    MIN_COLOR_COUNT, MIN_UPSCALE, PixelSettings,
};
