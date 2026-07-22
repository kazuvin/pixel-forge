use serde::{Deserialize, Serialize};

use crate::{
    PixelError,
    error::RenderSettingsError,
    settings::{MAX_OUTPUT_SIDE, MAX_TARGET_SIDE, MAX_UPSCALE, MIN_UPSCALE},
};

pub const MAX_PALETTE_COLORS: usize = 256;

#[derive(Clone, Copy, Debug, Deserialize, Eq, Hash, Ord, PartialEq, PartialOrd, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct RgbColor {
    pub red: u8,
    pub green: u8,
    pub blue: u8,
}

impl RgbColor {
    #[must_use]
    pub const fn new(red: u8, green: u8, blue: u8) -> Self {
        Self { red, green, blue }
    }

    pub(crate) const fn channels(self) -> [u8; 3] {
        [self.red, self.green, self.blue]
    }
}

impl From<[u8; 3]> for RgbColor {
    fn from([red, green, blue]: [u8; 3]) -> Self {
        Self::new(red, green, blue)
    }
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CropRect {
    pub x: u32,
    pub y: u32,
    pub width: u32,
    pub height: u32,
}

#[derive(Clone, Copy, Debug, Default, Deserialize, Eq, PartialEq, Serialize)]
#[serde(tag = "mode", rename_all = "kebab-case")]
pub enum CropRegion {
    #[default]
    Full,
    Rectangle {
        rect: CropRect,
    },
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Palette {
    pub name: String,
    pub colors: Vec<RgbColor>,
}

#[derive(Clone, Copy, Debug, Default, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct TonePreservation {
    pub saturation: u8,
    pub lightness: u8,
}

#[derive(Clone, Copy, Debug, Default, Deserialize, Eq, PartialEq, Serialize)]
#[serde(tag = "mode", rename_all = "kebab-case")]
pub enum PaletteApplication {
    #[default]
    Exact,
    PreserveTone {
        preservation: TonePreservation,
    },
}

#[derive(Clone, Debug, Default, Deserialize, Eq, PartialEq, Serialize)]
#[serde(tag = "mode", rename_all = "kebab-case")]
pub enum ColorMode {
    #[default]
    Source,
    Palette {
        palette: Palette,
        application: PaletteApplication,
    },
}

#[derive(Clone, Copy, Debug, Default, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "kebab-case")]
pub enum OutlineMode {
    #[default]
    None,
    Black,
    Adaptive,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct OutlineSettings {
    pub mode: OutlineMode,
    /// Minimum perceptual color difference, from 0 (sensitive) to 100 (strong edges only).
    pub threshold: u8,
}

impl Default for OutlineSettings {
    fn default() -> Self {
        Self {
            mode: OutlineMode::None,
            threshold: 15,
        }
    }
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct RenderSettings {
    pub long_side: u32,
    pub upscale: u32,
    pub crop: CropRegion,
    pub color_mode: ColorMode,
    pub outline: OutlineSettings,
}

impl Default for RenderSettings {
    fn default() -> Self {
        Self {
            long_side: 64,
            upscale: 8,
            crop: CropRegion::Full,
            color_mode: ColorMode::Source,
            outline: OutlineSettings::default(),
        }
    }
}

#[derive(Clone, Copy, Debug)]
pub(crate) struct RenderGeometry {
    pub(crate) crop: CropRect,
    pub(crate) target_width: u32,
    pub(crate) target_height: u32,
    pub(crate) output_width: u32,
    pub(crate) output_height: u32,
}

impl RenderSettings {
    pub(crate) fn validate(
        &self,
        source_width: u32,
        source_height: u32,
    ) -> Result<RenderGeometry, PixelError> {
        if self.long_side == 0 || self.long_side > MAX_TARGET_SIDE {
            return Err(RenderSettingsError::LongSideOutOfRange {
                provided: self.long_side,
                minimum: 1,
                maximum: MAX_TARGET_SIDE,
            }
            .into());
        }
        if !(MIN_UPSCALE..=MAX_UPSCALE).contains(&self.upscale) {
            return Err(RenderSettingsError::UpscaleOutOfRange {
                provided: self.upscale,
                minimum: MIN_UPSCALE,
                maximum: MAX_UPSCALE,
            }
            .into());
        }
        if self.outline.threshold > 100 {
            return Err(RenderSettingsError::OutlineThresholdOutOfRange {
                provided: self.outline.threshold,
            }
            .into());
        }
        validate_color_mode(&self.color_mode)?;

        let crop = match self.crop {
            CropRegion::Full => CropRect {
                x: 0,
                y: 0,
                width: source_width,
                height: source_height,
            },
            CropRegion::Rectangle { rect } => validate_crop(rect, source_width, source_height)?,
        };
        let (target_width, target_height) = target_dimensions(crop, self.long_side);
        let output_width =
            target_width
                .checked_mul(self.upscale)
                .ok_or(RenderSettingsError::OutputTooLarge {
                    width: u32::MAX,
                    height: target_height,
                    max_side: MAX_OUTPUT_SIDE,
                })?;
        let output_height =
            target_height
                .checked_mul(self.upscale)
                .ok_or(RenderSettingsError::OutputTooLarge {
                    width: output_width,
                    height: u32::MAX,
                    max_side: MAX_OUTPUT_SIDE,
                })?;
        if output_width > MAX_OUTPUT_SIDE || output_height > MAX_OUTPUT_SIDE {
            return Err(RenderSettingsError::OutputTooLarge {
                width: output_width,
                height: output_height,
                max_side: MAX_OUTPUT_SIDE,
            }
            .into());
        }

        Ok(RenderGeometry {
            crop,
            target_width,
            target_height,
            output_width,
            output_height,
        })
    }
}

fn validate_color_mode(color_mode: &ColorMode) -> Result<(), PixelError> {
    let ColorMode::Palette {
        palette,
        application,
    } = color_mode
    else {
        return Ok(());
    };
    if palette.name.trim().is_empty() {
        return Err(RenderSettingsError::EmptyPaletteName.into());
    }
    if palette.colors.is_empty() {
        return Err(RenderSettingsError::EmptyPalette.into());
    }
    if palette.colors.len() > MAX_PALETTE_COLORS {
        return Err(RenderSettingsError::TooManyPaletteColors {
            provided: palette.colors.len(),
            maximum: MAX_PALETTE_COLORS,
        }
        .into());
    }
    if let PaletteApplication::PreserveTone { preservation } = application
        && (preservation.saturation > 100 || preservation.lightness > 100)
    {
        return Err(RenderSettingsError::TonePreservationOutOfRange {
            saturation: preservation.saturation,
            lightness: preservation.lightness,
        }
        .into());
    }
    Ok(())
}

fn validate_crop(
    crop: CropRect,
    source_width: u32,
    source_height: u32,
) -> Result<CropRect, PixelError> {
    if crop.width == 0 || crop.height == 0 {
        return Err(RenderSettingsError::EmptyCrop.into());
    }
    let right = crop.x.checked_add(crop.width);
    let bottom = crop.y.checked_add(crop.height);
    if right.is_none_or(|right| right > source_width)
        || bottom.is_none_or(|bottom| bottom > source_height)
    {
        return Err(RenderSettingsError::CropOutsideImage {
            x: crop.x,
            y: crop.y,
            width: crop.width,
            height: crop.height,
            source_width,
            source_height,
        }
        .into());
    }
    Ok(crop)
}

fn target_dimensions(crop: CropRect, long_side: u32) -> (u32, u32) {
    match crop.width.cmp(&crop.height) {
        std::cmp::Ordering::Greater => (
            long_side,
            scaled_short_side(crop.height, long_side, crop.width),
        ),
        std::cmp::Ordering::Less => (
            scaled_short_side(crop.width, long_side, crop.height),
            long_side,
        ),
        std::cmp::Ordering::Equal => (long_side, long_side),
    }
}

fn scaled_short_side(short_side: u32, target_long_side: u32, source_long_side: u32) -> u32 {
    let scaled = u64::from(short_side) * u64::from(target_long_side);
    u32::try_from((scaled + u64::from(source_long_side) / 2) / u64::from(source_long_side))
        .expect("source and target bounds keep the short side in the u32 range")
        .max(1)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::PixelError;

    #[test]
    fn derives_short_side_from_crop_aspect_ratio() {
        let settings = RenderSettings {
            long_side: 100,
            crop: CropRegion::Rectangle {
                rect: CropRect {
                    x: 10,
                    y: 20,
                    width: 400,
                    height: 200,
                },
            },
            upscale: 3,
            ..RenderSettings::default()
        };

        let geometry = settings
            .validate(500, 300)
            .expect("settings should be valid");

        assert_eq!((geometry.target_width, geometry.target_height), (100, 50));
        assert_eq!((geometry.output_width, geometry.output_height), (300, 150));
    }

    #[test]
    fn rejects_crop_outside_the_source() {
        let settings = RenderSettings {
            crop: CropRegion::Rectangle {
                rect: CropRect {
                    x: 90,
                    y: 0,
                    width: 20,
                    height: 50,
                },
            },
            ..RenderSettings::default()
        };

        let error = settings.validate(100, 100).expect_err("crop should fail");

        assert!(matches!(
            error,
            PixelError::InvalidRenderSettings(RenderSettingsError::CropOutsideImage { .. })
        ));
    }

    #[test]
    fn validates_palette_and_adjustment_ranges() {
        let settings = RenderSettings {
            color_mode: ColorMode::Palette {
                palette: Palette {
                    name: "custom".into(),
                    colors: vec![RgbColor::new(1, 2, 3)],
                },
                application: PaletteApplication::PreserveTone {
                    preservation: TonePreservation {
                        saturation: 101,
                        lightness: 0,
                    },
                },
            },
            ..RenderSettings::default()
        };

        let error = settings
            .validate(100, 100)
            .expect_err("percentage should fail");

        assert!(matches!(
            error,
            PixelError::InvalidRenderSettings(
                RenderSettingsError::TonePreservationOutOfRange { .. }
            )
        ));
    }

    #[test]
    fn rejects_render_and_output_bounds() {
        let cases = [
            RenderSettings {
                long_side: 0,
                ..RenderSettings::default()
            },
            RenderSettings {
                upscale: 0,
                ..RenderSettings::default()
            },
            RenderSettings {
                outline: OutlineSettings {
                    mode: OutlineMode::Black,
                    threshold: 101,
                },
                ..RenderSettings::default()
            },
            RenderSettings {
                long_side: MAX_TARGET_SIDE,
                upscale: MAX_UPSCALE,
                ..RenderSettings::default()
            },
        ];

        for settings in cases {
            assert!(settings.validate(100, 100).is_err());
        }
    }

    #[test]
    fn rejects_empty_crop_and_palette_metadata() {
        let empty_crop = RenderSettings {
            crop: CropRegion::Rectangle {
                rect: CropRect {
                    x: 0,
                    y: 0,
                    width: 0,
                    height: 10,
                },
            },
            ..RenderSettings::default()
        };
        let unnamed_palette = RenderSettings {
            color_mode: ColorMode::Palette {
                palette: Palette {
                    name: "  ".into(),
                    colors: vec![RgbColor::new(0, 0, 0)],
                },
                application: PaletteApplication::Exact,
            },
            ..RenderSettings::default()
        };
        let empty_palette = RenderSettings {
            color_mode: ColorMode::Palette {
                palette: Palette {
                    name: "empty".into(),
                    colors: Vec::new(),
                },
                application: PaletteApplication::Exact,
            },
            ..RenderSettings::default()
        };

        assert!(matches!(
            empty_crop.validate(100, 100),
            Err(PixelError::InvalidRenderSettings(
                RenderSettingsError::EmptyCrop
            ))
        ));
        assert!(matches!(
            unnamed_palette.validate(100, 100),
            Err(PixelError::InvalidRenderSettings(
                RenderSettingsError::EmptyPaletteName
            ))
        ));
        assert!(matches!(
            empty_palette.validate(100, 100),
            Err(PixelError::InvalidRenderSettings(
                RenderSettingsError::EmptyPalette
            ))
        ));
    }
}
