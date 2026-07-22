use thiserror::Error;

#[derive(Clone, Debug, Eq, Error, PartialEq)]
pub enum SettingsError {
    #[error("target width and height must be greater than zero")]
    ZeroTargetDimension,
    #[error("target dimensions {width}x{height} exceed the maximum side length of {max_side}")]
    TargetTooLarge {
        width: u32,
        height: u32,
        max_side: u32,
    },
    #[error("color count {provided} is outside the supported range {minimum}..={maximum}")]
    ColorCountOutOfRange {
        provided: u8,
        minimum: u8,
        maximum: u8,
    },
    #[error("upscale {provided} is outside the supported range {minimum}..={maximum}")]
    UpscaleOutOfRange {
        provided: u32,
        minimum: u32,
        maximum: u32,
    },
    #[error("output dimensions {width}x{height} exceed the maximum side length of {max_side}")]
    OutputTooLarge {
        width: u32,
        height: u32,
        max_side: u32,
    },
}

#[derive(Clone, Debug, Eq, Error, PartialEq)]
pub enum RenderSettingsError {
    #[error("long side {provided} is outside the supported range {minimum}..={maximum}")]
    LongSideOutOfRange {
        provided: u32,
        minimum: u32,
        maximum: u32,
    },
    #[error("upscale {provided} is outside the supported range {minimum}..={maximum}")]
    UpscaleOutOfRange {
        provided: u32,
        minimum: u32,
        maximum: u32,
    },
    #[error("crop width and height must be greater than zero")]
    EmptyCrop,
    #[error(
        "crop {x},{y} {width}x{height} is outside the source image {source_width}x{source_height}"
    )]
    CropOutsideImage {
        x: u32,
        y: u32,
        width: u32,
        height: u32,
        source_width: u32,
        source_height: u32,
    },
    #[error("palette name must not be empty")]
    EmptyPaletteName,
    #[error("palette must contain at least one color")]
    EmptyPalette,
    #[error("palette contains {provided} colors; maximum is {maximum}")]
    TooManyPaletteColors { provided: usize, maximum: usize },
    #[error(
        "tone preservation must be between 0 and 100 (saturation {saturation}, lightness {lightness})"
    )]
    TonePreservationOutOfRange { saturation: u8, lightness: u8 },
    #[error("outline threshold {provided} is outside the supported range 0..=100")]
    OutlineThresholdOutOfRange { provided: u8 },
    #[error("output dimensions {width}x{height} exceed the maximum side length of {max_side}")]
    OutputTooLarge {
        width: u32,
        height: u32,
        max_side: u32,
    },
}

#[derive(Debug, Error)]
pub enum PixelError {
    #[error("image could not be decoded: {0}")]
    Decode(#[from] image::ImageError),
    #[error("unsupported image format; expected PNG, JPEG, or PPM")]
    UnsupportedFormat,
    #[error("image is too large: {width}x{height} ({pixels} pixels; maximum is {maximum})")]
    InputTooLarge {
        width: u32,
        height: u32,
        pixels: u64,
        maximum: u64,
    },
    #[error("invalid settings: {0}")]
    InvalidSettings(#[from] SettingsError),
    #[error("invalid render settings: {0}")]
    InvalidRenderSettings(#[from] RenderSettingsError),
    #[error("recipe could not be encoded: {0}")]
    Recipe(#[from] serde_json::Error),
}
