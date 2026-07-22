use serde::{Deserialize, Serialize};

use crate::error::{PixelError, SettingsError};

pub const MAX_INPUT_PIXELS: u64 = 80_000_000;
pub const MAX_TARGET_SIDE: u32 = 1_024;
pub const MAX_OUTPUT_SIDE: u32 = 16_384;
pub const MIN_COLOR_COUNT: u8 = 2;
pub const MAX_COLOR_COUNT: u8 = 64;
pub const MIN_UPSCALE: u32 = 1;
pub const MAX_UPSCALE: u32 = 32;

#[derive(Clone, Copy, Debug, Default, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "kebab-case")]
pub enum DitherMode {
    #[default]
    None,
    Bayer4x4,
    FloydSteinberg,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PixelSettings {
    pub target_width: u32,
    pub target_height: u32,
    pub color_count: u8,
    pub dither: DitherMode,
    pub upscale: u32,
}

impl Default for PixelSettings {
    fn default() -> Self {
        Self {
            target_width: 64,
            target_height: 64,
            color_count: 12,
            dither: DitherMode::Bayer4x4,
            upscale: 8,
        }
    }
}

impl PixelSettings {
    /// Validates bounds that keep rendering and output allocation predictable.
    ///
    /// # Errors
    ///
    /// Returns [`PixelError::InvalidSettings`] when a value is outside the supported range.
    pub fn validate(self) -> Result<Self, PixelError> {
        ValidatedSettings::try_from(self).map(|validated| validated.inner)
    }
}

#[derive(Clone, Copy, Debug)]
pub(crate) struct ValidatedSettings {
    inner: PixelSettings,
    output_width: u32,
    output_height: u32,
}

impl ValidatedSettings {
    pub(crate) const fn settings(self) -> PixelSettings {
        self.inner
    }

    pub(crate) const fn output_dimensions(self) -> (u32, u32) {
        (self.output_width, self.output_height)
    }
}

impl TryFrom<PixelSettings> for ValidatedSettings {
    type Error = PixelError;

    fn try_from(settings: PixelSettings) -> Result<Self, Self::Error> {
        if settings.target_width == 0 || settings.target_height == 0 {
            return Err(SettingsError::ZeroTargetDimension.into());
        }
        if settings.target_width > MAX_TARGET_SIDE || settings.target_height > MAX_TARGET_SIDE {
            return Err(SettingsError::TargetTooLarge {
                width: settings.target_width,
                height: settings.target_height,
                max_side: MAX_TARGET_SIDE,
            }
            .into());
        }
        if !(MIN_COLOR_COUNT..=MAX_COLOR_COUNT).contains(&settings.color_count) {
            return Err(SettingsError::ColorCountOutOfRange {
                provided: settings.color_count,
                minimum: MIN_COLOR_COUNT,
                maximum: MAX_COLOR_COUNT,
            }
            .into());
        }
        if !(MIN_UPSCALE..=MAX_UPSCALE).contains(&settings.upscale) {
            return Err(SettingsError::UpscaleOutOfRange {
                provided: settings.upscale,
                minimum: MIN_UPSCALE,
                maximum: MAX_UPSCALE,
            }
            .into());
        }

        let output_width = settings.target_width.checked_mul(settings.upscale).ok_or(
            SettingsError::OutputTooLarge {
                width: u32::MAX,
                height: settings.target_height,
                max_side: MAX_OUTPUT_SIDE,
            },
        )?;
        let output_height = settings.target_height.checked_mul(settings.upscale).ok_or(
            SettingsError::OutputTooLarge {
                width: output_width,
                height: u32::MAX,
                max_side: MAX_OUTPUT_SIDE,
            },
        )?;
        if output_width > MAX_OUTPUT_SIDE || output_height > MAX_OUTPUT_SIDE {
            return Err(SettingsError::OutputTooLarge {
                width: output_width,
                height: output_height,
                max_side: MAX_OUTPUT_SIDE,
            }
            .into());
        }

        Ok(Self {
            inner: settings,
            output_width,
            output_height,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepts_values_at_every_boundary() {
        for settings in [
            PixelSettings {
                target_width: 1,
                target_height: 1,
                color_count: MIN_COLOR_COUNT,
                dither: DitherMode::None,
                upscale: MIN_UPSCALE,
            },
            PixelSettings {
                target_width: MAX_TARGET_SIDE,
                target_height: MAX_TARGET_SIDE,
                color_count: MAX_COLOR_COUNT,
                dither: DitherMode::FloydSteinberg,
                upscale: MAX_OUTPUT_SIDE / MAX_TARGET_SIDE,
            },
        ] {
            assert!(ValidatedSettings::try_from(settings).is_ok());
        }
    }

    #[test]
    fn reports_the_specific_invalid_setting() {
        let cases = [
            (
                PixelSettings {
                    target_width: 0,
                    ..PixelSettings::default()
                },
                SettingsError::ZeroTargetDimension,
            ),
            (
                PixelSettings {
                    target_width: MAX_TARGET_SIDE + 1,
                    ..PixelSettings::default()
                },
                SettingsError::TargetTooLarge {
                    width: MAX_TARGET_SIDE + 1,
                    height: 64,
                    max_side: MAX_TARGET_SIDE,
                },
            ),
            (
                PixelSettings {
                    color_count: MIN_COLOR_COUNT - 1,
                    ..PixelSettings::default()
                },
                SettingsError::ColorCountOutOfRange {
                    provided: MIN_COLOR_COUNT - 1,
                    minimum: MIN_COLOR_COUNT,
                    maximum: MAX_COLOR_COUNT,
                },
            ),
            (
                PixelSettings {
                    upscale: MAX_UPSCALE + 1,
                    ..PixelSettings::default()
                },
                SettingsError::UpscaleOutOfRange {
                    provided: MAX_UPSCALE + 1,
                    minimum: MIN_UPSCALE,
                    maximum: MAX_UPSCALE,
                },
            ),
            (
                PixelSettings {
                    target_width: MAX_TARGET_SIDE,
                    target_height: MAX_TARGET_SIDE,
                    upscale: MAX_UPSCALE,
                    ..PixelSettings::default()
                },
                SettingsError::OutputTooLarge {
                    width: MAX_TARGET_SIDE * MAX_UPSCALE,
                    height: MAX_TARGET_SIDE * MAX_UPSCALE,
                    max_side: MAX_OUTPUT_SIDE,
                },
            ),
        ];

        for (settings, expected) in cases {
            let error = ValidatedSettings::try_from(settings).expect_err("settings should fail");
            assert!(matches!(error, PixelError::InvalidSettings(actual) if actual == expected));
        }
    }
}
