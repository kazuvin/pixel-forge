use serde::{Deserialize, Serialize};

use crate::{
    DitherMode, RenderSettings, converter_settings::RenderGeometry, settings::ValidatedSettings,
};

pub const ALGORITHM_VERSION: &str = "1.2.0";
pub const LEGACY_ALGORITHM_VERSION: &str = "0.2.0";
pub const RECIPE_SCHEMA_VERSION: u32 = 1;
pub const RENDER_RECIPE_SCHEMA_VERSION: u32 = 2;

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "kebab-case")]
pub enum CropMode {
    CenterCover,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PixelRecipe {
    pub schema_version: u32,
    pub algorithm_version: String,
    pub input_sha256: String,
    pub target_width: u32,
    pub target_height: u32,
    pub output_width: u32,
    pub output_height: u32,
    pub color_count: u8,
    pub dither: DitherMode,
    pub upscale: u32,
    pub crop: CropMode,
    pub palette: Vec<String>,
}

impl PixelRecipe {
    pub(crate) fn new(
        input_sha256: String,
        settings: ValidatedSettings,
        palette: Vec<String>,
    ) -> Self {
        let pixel_settings = settings.settings();
        let (output_width, output_height) = settings.output_dimensions();
        Self {
            schema_version: RECIPE_SCHEMA_VERSION,
            algorithm_version: LEGACY_ALGORITHM_VERSION.into(),
            input_sha256,
            target_width: pixel_settings.target_width,
            target_height: pixel_settings.target_height,
            output_width,
            output_height,
            color_count: pixel_settings.color_count,
            dither: pixel_settings.dither,
            upscale: pixel_settings.upscale,
            crop: CropMode::CenterCover,
            palette,
        }
    }
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct RenderRecipe {
    pub schema_version: u32,
    pub algorithm_version: String,
    pub input_sha256: String,
    pub settings: RenderSettings,
    pub logical_width: u32,
    pub logical_height: u32,
    pub output_width: u32,
    pub output_height: u32,
    pub palette: Vec<String>,
}

impl RenderRecipe {
    pub(crate) fn new(
        input_sha256: String,
        settings: RenderSettings,
        geometry: RenderGeometry,
        palette: Vec<String>,
    ) -> Self {
        Self {
            schema_version: RENDER_RECIPE_SCHEMA_VERSION,
            algorithm_version: ALGORITHM_VERSION.into(),
            input_sha256,
            settings,
            logical_width: geometry.target_width,
            logical_height: geometry.target_height,
            output_width: geometry.output_width,
            output_height: geometry.output_height,
            palette,
        }
    }
}

pub(crate) fn to_hex(color: [u8; 3]) -> String {
    format!("#{:02X}{:02X}{:02X}", color[0], color[1], color[2])
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::PixelSettings;

    #[test]
    fn serializes_stable_external_names() {
        let settings = ValidatedSettings::try_from(PixelSettings {
            target_width: 2,
            target_height: 3,
            color_count: 4,
            dither: DitherMode::FloydSteinberg,
            upscale: 5,
        })
        .expect("fixture settings should be valid");
        let recipe = PixelRecipe::new(
            "abc".into(),
            settings,
            vec!["#000000".into(), "#FFFFFF".into()],
        );

        let value = serde_json::to_value(recipe).expect("recipe should serialize");

        assert_eq!(value["schemaVersion"], RECIPE_SCHEMA_VERSION);
        assert_eq!(value["algorithmVersion"], LEGACY_ALGORITHM_VERSION);
        assert_eq!(value["dither"], "floyd-steinberg");
        assert_eq!(value["crop"], "center-cover");
        assert_eq!(value["outputWidth"], 10);
        assert_eq!(value["outputHeight"], 15);
    }
}
