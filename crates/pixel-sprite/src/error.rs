use thiserror::Error;

#[derive(Clone, Debug, Eq, Error, PartialEq)]
pub enum SpriteManifestError {
    #[error("sprite manifest schema version {provided} is unsupported; expected {supported}")]
    UnsupportedSchemaVersion { provided: u32, supported: u32 },
    #[error("{kind} identifier must use lowercase ASCII letters, digits, and hyphens: {value}")]
    InvalidIdentifier { kind: &'static str, value: String },
    #[error("generation field {0} must not be empty")]
    EmptyGenerationField(&'static str),
    #[error("generation chroma key must be a six-digit hex color: {0}")]
    InvalidChromaKey(String),
    #[error("grid columns, rows, and logical cell dimensions must be greater than zero")]
    EmptyGrid,
    #[error("logical parts sheet dimensions overflow")]
    LogicalSheetTooLarge,
    #[error("logical parts sheet {width}x{height} exceeds the maximum side {maximum}")]
    LogicalSheetOutsideBounds {
        width: u32,
        height: u32,
        maximum: u32,
    },
    #[error("sprite canvas width and height must be greater than zero")]
    EmptyCanvas,
    #[error("sprite canvas {width}x{height} exceeds the maximum side {maximum}")]
    CanvasOutsideBounds {
        width: u32,
        height: u32,
        maximum: u32,
    },
    #[error("animation frame count {provided} is outside 1..={maximum}")]
    FrameCountOutsideBounds { provided: u32, maximum: u32 },
    #[error("animation fps {provided} is outside 1..={maximum}")]
    FpsOutsideBounds { provided: u32, maximum: u32 },
    #[error("render color count {provided} is outside {minimum}..={maximum}")]
    ColorCountOutsideBounds {
        provided: u8,
        minimum: u8,
        maximum: u8,
    },
    #[error("preview scale {provided} is outside 1..={maximum}")]
    PreviewScaleOutsideBounds { provided: u32, maximum: u32 },
    #[error("output sprite sheet dimensions overflow")]
    OutputSheetTooLarge,
    #[error("output sprite sheet {width}x{height} exceeds the maximum side {maximum}")]
    OutputSheetOutsideBounds {
        width: u32,
        height: u32,
        maximum: u32,
    },
    #[error("sprite manifest must contain at least one part")]
    NoParts,
    #[error("part identifier is duplicated: {0}")]
    DuplicatePartId(String),
    #[error("multiple parts use grid cell {column},{row}")]
    DuplicatePartCell { column: u32, row: u32 },
    #[error("part {id} uses grid cell {column},{row} outside the configured grid")]
    PartCellOutsideGrid { id: String, column: u32, row: u32 },
    #[error("part {id} anchor {x},{y} is outside its logical cell")]
    PartAnchorOutsideCell { id: String, x: i32, y: i32 },
    #[error("part {id} contains {provided} offsets; expected {expected}")]
    PartFrameCountMismatch {
        id: String,
        provided: usize,
        expected: u32,
    },
}

#[derive(Debug, Error)]
pub enum SpriteError {
    #[error("sprite manifest is invalid: {0}")]
    InvalidManifest(#[from] SpriteManifestError),
    #[error("parts sheet could not be decoded: {0}")]
    Decode(#[from] image::ImageError),
    #[error("parts sheet could not be pixelized: {0}")]
    Pixelize(#[from] pixel_core::PixelError),
    #[error(
        "parts sheet has no transparent pixels; generate on chroma key and remove the background first"
    )]
    SourceHasNoTransparency,
    #[error("part {0} is empty after pixelization")]
    EmptyPart(String),
    #[error("sprite JSON could not be encoded: {0}")]
    Json(#[from] serde_json::Error),
}
