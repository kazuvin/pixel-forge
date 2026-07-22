use std::collections::BTreeMap;

use image::{
    ColorType, DynamicImage, ImageEncoder, Rgba, RgbaImage, codecs::png::PngEncoder,
    imageops::FilterType,
};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use thiserror::Error;

pub const ALGORITHM_VERSION: &str = "0.1.0";
const MAX_INPUT_PIXELS: u64 = 80_000_000;
const MAX_TARGET_SIDE: u32 = 1_024;
const MAX_OUTPUT_SIDE: u32 = 16_384;

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
        if self.target_width == 0 || self.target_height == 0 {
            return Err(PixelError::InvalidSettings(
                "target width and height must be greater than zero".into(),
            ));
        }
        if self.target_width > MAX_TARGET_SIDE || self.target_height > MAX_TARGET_SIDE {
            return Err(PixelError::InvalidSettings(format!(
                "target width and height must not exceed {MAX_TARGET_SIDE}"
            )));
        }
        if !(2..=64).contains(&self.color_count) {
            return Err(PixelError::InvalidSettings(
                "color count must be between 2 and 64".into(),
            ));
        }
        if !(1..=32).contains(&self.upscale) {
            return Err(PixelError::InvalidSettings(
                "upscale must be between 1 and 32".into(),
            ));
        }

        let output_width = self.target_width.saturating_mul(self.upscale);
        let output_height = self.target_height.saturating_mul(self.upscale);
        if output_width > MAX_OUTPUT_SIDE || output_height > MAX_OUTPUT_SIDE {
            return Err(PixelError::InvalidSettings(format!(
                "upscaled width and height must not exceed {MAX_OUTPUT_SIDE}"
            )));
        }

        Ok(self)
    }
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PixelRecipe {
    pub algorithm_version: String,
    pub input_sha256: String,
    pub target_width: u32,
    pub target_height: u32,
    pub output_width: u32,
    pub output_height: u32,
    pub color_count: u8,
    pub dither: DitherMode,
    pub upscale: u32,
    pub crop: String,
    pub palette: Vec<String>,
}

#[derive(Clone, Debug)]
pub struct PixelResult {
    pub png_bytes: Vec<u8>,
    pub width: u32,
    pub height: u32,
    pub palette: Vec<String>,
    pub recipe_json: String,
}

#[derive(Debug, Error)]
pub enum PixelError {
    #[error("image could not be decoded: {0}")]
    Decode(#[from] image::ImageError),
    #[error("image is too large: {width}x{height}")]
    InputTooLarge { width: u32, height: u32 },
    #[error("invalid settings: {0}")]
    InvalidSettings(String),
    #[error("recipe could not be encoded: {0}")]
    Recipe(#[from] serde_json::Error),
}

pub struct PixelSession {
    source: DynamicImage,
    input_sha256: String,
}

impl PixelSession {
    /// Decodes an image once so multiple recipes can reuse the same source.
    ///
    /// # Errors
    ///
    /// Returns an error when the bytes are not a supported image or exceed the input limit.
    pub fn new(encoded_image: &[u8]) -> Result<Self, PixelError> {
        let source = image::load_from_memory(encoded_image)?;
        let input_pixels = u64::from(source.width()) * u64::from(source.height());
        if input_pixels > MAX_INPUT_PIXELS {
            return Err(PixelError::InputTooLarge {
                width: source.width(),
                height: source.height(),
            });
        }

        Ok(Self {
            source,
            input_sha256: format!("{:x}", Sha256::digest(encoded_image)),
        })
    }

    /// Runs center crop, palette reduction, dithering, scaling, and PNG encoding.
    ///
    /// # Errors
    ///
    /// Returns an error when settings are invalid or the PNG/recipe cannot be encoded.
    pub fn render(&self, settings: PixelSettings) -> Result<PixelResult, PixelError> {
        let settings = settings.validate()?;
        let reduced = self
            .source
            .resize_to_fill(
                settings.target_width,
                settings.target_height,
                FilterType::Triangle,
            )
            .to_rgba8();
        let palette = median_cut_palette(&reduced, usize::from(settings.color_count));
        let quantized = match settings.dither {
            DitherMode::None => quantize_without_dither(&reduced, &palette),
            DitherMode::Bayer4x4 => quantize_bayer(&reduced, &palette),
            DitherMode::FloydSteinberg => quantize_floyd_steinberg(&reduced, &palette),
        };
        let output = if settings.upscale == 1 {
            quantized
        } else {
            image::imageops::resize(
                &quantized,
                settings.target_width * settings.upscale,
                settings.target_height * settings.upscale,
                FilterType::Nearest,
            )
        };
        let palette_hex = palette
            .iter()
            .map(|color| to_hex(*color))
            .collect::<Vec<_>>();
        let recipe = PixelRecipe {
            algorithm_version: ALGORITHM_VERSION.into(),
            input_sha256: self.input_sha256.clone(),
            target_width: settings.target_width,
            target_height: settings.target_height,
            output_width: output.width(),
            output_height: output.height(),
            color_count: settings.color_count,
            dither: settings.dither,
            upscale: settings.upscale,
            crop: "center-cover".into(),
            palette: palette_hex.clone(),
        };

        Ok(PixelResult {
            png_bytes: encode_png(&output)?,
            width: output.width(),
            height: output.height(),
            palette: palette_hex,
            recipe_json: serde_json::to_string_pretty(&recipe)?,
        })
    }
}

#[derive(Clone, Debug)]
struct WeightedColor {
    rgb: [u8; 3],
    count: u32,
}

fn median_cut_palette(image: &RgbaImage, limit: usize) -> Vec<[u8; 3]> {
    let mut histogram = BTreeMap::<[u8; 3], u32>::new();
    for pixel in image.pixels().filter(|pixel| pixel[3] > 0) {
        *histogram.entry([pixel[0], pixel[1], pixel[2]]).or_default() += 1;
    }

    if histogram.is_empty() {
        return vec![[0, 0, 0]];
    }

    let colors = histogram
        .into_iter()
        .map(|(rgb, count)| WeightedColor { rgb, count })
        .collect::<Vec<_>>();
    let mut boxes = vec![colors];

    while boxes.len() < limit {
        let Some(index) = best_box_to_split(&boxes) else {
            break;
        };
        let colors = boxes.remove(index);
        let Some((left, right)) = split_box(colors) else {
            break;
        };
        boxes.insert(index, right);
        boxes.insert(index, left);
    }

    let mut palette = boxes
        .iter()
        .map(|colors| average_color(colors))
        .collect::<Vec<_>>();
    palette.sort_by_key(|rgb| {
        (
            u32::from(rgb[0]) * 2126 + u32::from(rgb[1]) * 7152 + u32::from(rgb[2]) * 722,
            *rgb,
        )
    });
    palette
}

fn best_box_to_split(boxes: &[Vec<WeightedColor>]) -> Option<usize> {
    let mut best = None;
    let mut best_score = 0_u64;
    for (index, colors) in boxes.iter().enumerate() {
        if colors.len() < 2 {
            continue;
        }
        let ranges = channel_ranges(colors);
        let range = u64::from(*ranges.iter().max().unwrap_or(&0));
        let population = colors
            .iter()
            .map(|color| u64::from(color.count))
            .sum::<u64>();
        let score = range * population;
        if best.is_none() || score > best_score {
            best = Some(index);
            best_score = score;
        }
    }
    best
}

fn split_box(mut colors: Vec<WeightedColor>) -> Option<(Vec<WeightedColor>, Vec<WeightedColor>)> {
    if colors.len() < 2 {
        return None;
    }
    let ranges = channel_ranges(&colors);
    let channel = if ranges[1] > ranges[0] && ranges[1] >= ranges[2] {
        1
    } else if ranges[2] > ranges[0] && ranges[2] > ranges[1] {
        2
    } else {
        0
    };
    colors.sort_by_key(|color| {
        (
            color.rgb[channel],
            color.rgb[(channel + 1) % 3],
            color.rgb[(channel + 2) % 3],
        )
    });

    let total = colors
        .iter()
        .map(|color| u64::from(color.count))
        .sum::<u64>();
    let mut accumulated = 0_u64;
    let mut split_index = 1;
    for (index, color) in colors.iter().enumerate().take(colors.len() - 1) {
        accumulated += u64::from(color.count);
        split_index = index + 1;
        if accumulated * 2 >= total {
            break;
        }
    }
    let right = colors.split_off(split_index);
    Some((colors, right))
}

fn channel_ranges(colors: &[WeightedColor]) -> [u8; 3] {
    let mut minimum = [u8::MAX; 3];
    let mut maximum = [u8::MIN; 3];
    for color in colors {
        for channel in 0..3 {
            minimum[channel] = minimum[channel].min(color.rgb[channel]);
            maximum[channel] = maximum[channel].max(color.rgb[channel]);
        }
    }
    [
        maximum[0] - minimum[0],
        maximum[1] - minimum[1],
        maximum[2] - minimum[2],
    ]
}

fn average_color(colors: &[WeightedColor]) -> [u8; 3] {
    let total = colors
        .iter()
        .map(|color| u64::from(color.count))
        .sum::<u64>();
    let mut channels = [0_u64; 3];
    for color in colors {
        for (channel, value) in channels.iter_mut().enumerate() {
            *value += u64::from(color.rgb[channel]) * u64::from(color.count);
        }
    }
    [
        u8::try_from(channels[0] / total).expect("weighted average stays in the u8 range"),
        u8::try_from(channels[1] / total).expect("weighted average stays in the u8 range"),
        u8::try_from(channels[2] / total).expect("weighted average stays in the u8 range"),
    ]
}

fn quantize_without_dither(image: &RgbaImage, palette: &[[u8; 3]]) -> RgbaImage {
    RgbaImage::from_fn(image.width(), image.height(), |x, y| {
        quantized_pixel(*image.get_pixel(x, y), palette, 0.0)
    })
}

fn quantize_bayer(image: &RgbaImage, palette: &[[u8; 3]]) -> RgbaImage {
    const BAYER_4X4: [[f32; 4]; 4] = [
        [0.0, 8.0, 2.0, 10.0],
        [12.0, 4.0, 14.0, 6.0],
        [3.0, 11.0, 1.0, 9.0],
        [15.0, 7.0, 13.0, 5.0],
    ];
    RgbaImage::from_fn(image.width(), image.height(), |x, y| {
        let threshold = (BAYER_4X4[y as usize % 4][x as usize % 4] - 7.5) * 3.0;
        quantized_pixel(*image.get_pixel(x, y), palette, threshold)
    })
}

#[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
fn quantize_floyd_steinberg(image: &RgbaImage, palette: &[[u8; 3]]) -> RgbaImage {
    let width = image.width() as usize;
    let height = image.height() as usize;
    let mut working = image
        .pixels()
        .map(|pixel| {
            [
                f32::from(pixel[0]),
                f32::from(pixel[1]),
                f32::from(pixel[2]),
            ]
        })
        .collect::<Vec<_>>();
    let mut output = RgbaImage::new(image.width(), image.height());

    for y in 0..height {
        for x in 0..width {
            let index = y * width + x;
            let source = image.get_pixel(x as u32, y as u32);
            if source[3] == 0 {
                output.put_pixel(x as u32, y as u32, Rgba([0, 0, 0, 0]));
                continue;
            }
            let old = working[index].map(|value| value.clamp(0.0, 255.0));
            let nearest = nearest_palette([old[0] as u8, old[1] as u8, old[2] as u8], palette);
            output.put_pixel(
                x as u32,
                y as u32,
                Rgba([nearest[0], nearest[1], nearest[2], source[3]]),
            );
            let error = [
                old[0] - f32::from(nearest[0]),
                old[1] - f32::from(nearest[1]),
                old[2] - f32::from(nearest[2]),
            ];
            diffuse_error(&mut working, width, height, x + 1, y, error, 7.0 / 16.0);
            if x > 0 {
                diffuse_error(&mut working, width, height, x - 1, y + 1, error, 3.0 / 16.0);
            }
            diffuse_error(&mut working, width, height, x, y + 1, error, 5.0 / 16.0);
            diffuse_error(&mut working, width, height, x + 1, y + 1, error, 1.0 / 16.0);
        }
    }
    output
}

fn diffuse_error(
    working: &mut [[f32; 3]],
    width: usize,
    height: usize,
    x: usize,
    y: usize,
    error: [f32; 3],
    factor: f32,
) {
    if x >= width || y >= height {
        return;
    }
    let destination = &mut working[y * width + x];
    for channel in 0..3 {
        destination[channel] += error[channel] * factor;
    }
}

#[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
fn quantized_pixel(pixel: Rgba<u8>, palette: &[[u8; 3]], adjustment: f32) -> Rgba<u8> {
    if pixel[3] == 0 {
        return Rgba([0, 0, 0, 0]);
    }
    let adjusted = [
        (f32::from(pixel[0]) + adjustment).clamp(0.0, 255.0) as u8,
        (f32::from(pixel[1]) + adjustment).clamp(0.0, 255.0) as u8,
        (f32::from(pixel[2]) + adjustment).clamp(0.0, 255.0) as u8,
    ];
    let nearest = nearest_palette(adjusted, palette);
    Rgba([nearest[0], nearest[1], nearest[2], pixel[3]])
}

fn nearest_palette(color: [u8; 3], palette: &[[u8; 3]]) -> [u8; 3] {
    palette
        .iter()
        .copied()
        .min_by_key(|candidate| {
            let red = i32::from(color[0]) - i32::from(candidate[0]);
            let green = i32::from(color[1]) - i32::from(candidate[1]);
            let blue = i32::from(color[2]) - i32::from(candidate[2]);
            red * red + green * green + blue * blue
        })
        .unwrap_or([0, 0, 0])
}

fn encode_png(image: &RgbaImage) -> Result<Vec<u8>, PixelError> {
    let mut bytes = Vec::new();
    PngEncoder::new(&mut bytes).write_image(
        image.as_raw(),
        image.width(),
        image.height(),
        ColorType::Rgba8.into(),
    )?;
    Ok(bytes)
}

fn to_hex(color: [u8; 3]) -> String {
    format!("#{:02X}{:02X}{:02X}", color[0], color[1], color[2])
}

#[cfg(test)]
mod tests {
    use std::io::Cursor;

    use image::{DynamicImage, ImageFormat};

    use super::*;

    #[test]
    fn same_image_and_recipe_produce_identical_pixels() {
        let input = fixture_png();
        let session = PixelSession::new(&input).expect("fixture should decode");
        let settings = PixelSettings {
            target_width: 4,
            target_height: 4,
            color_count: 4,
            dither: DitherMode::Bayer4x4,
            upscale: 2,
        };

        let first = session
            .render(settings)
            .expect("first render should succeed");
        let second = session
            .render(settings)
            .expect("second render should succeed");

        assert_eq!(
            decoded_rgba(&first.png_bytes),
            decoded_rgba(&second.png_bytes)
        );
        assert_eq!(first.recipe_json, second.recipe_json);
    }

    #[test]
    fn recipe_records_dimensions_palette_and_algorithm_version() {
        let session = PixelSession::new(&fixture_png()).expect("fixture should decode");
        let settings = PixelSettings {
            target_width: 3,
            target_height: 5,
            color_count: 3,
            dither: DitherMode::None,
            upscale: 4,
        };

        let result = session.render(settings).expect("render should succeed");
        let recipe: PixelRecipe =
            serde_json::from_str(&result.recipe_json).expect("recipe should decode");

        assert_eq!((result.width, result.height), (12, 20));
        assert_eq!(recipe.algorithm_version, ALGORITHM_VERSION);
        assert_eq!(recipe.output_width, 12);
        assert_eq!(recipe.output_height, 20);
        assert!(recipe.palette.len() <= 3);
    }

    #[test]
    fn invalid_settings_fail_before_rendering() {
        let session = PixelSession::new(&fixture_png()).expect("fixture should decode");
        let settings = PixelSettings {
            color_count: 1,
            ..PixelSettings::default()
        };

        let error = session
            .render(settings)
            .expect_err("invalid palette should fail");

        assert!(error.to_string().contains("color count"));
    }

    fn fixture_png() -> Vec<u8> {
        let image = RgbaImage::from_fn(8, 6, |x, y| {
            Rgba([
                u8::try_from(x * 31).expect("fixture red channel stays in range"),
                u8::try_from(y * 43).expect("fixture green channel stays in range"),
                u8::try_from((x + y) * 17).expect("fixture blue channel stays in range"),
                u8::MAX,
            ])
        });
        let mut bytes = Cursor::new(Vec::new());
        DynamicImage::ImageRgba8(image)
            .write_to(&mut bytes, ImageFormat::Png)
            .expect("fixture should encode");
        bytes.into_inner()
    }

    fn decoded_rgba(bytes: &[u8]) -> Vec<u8> {
        image::load_from_memory(bytes)
            .expect("result should decode")
            .to_rgba8()
            .into_raw()
    }
}
