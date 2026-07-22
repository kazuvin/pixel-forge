use image::{ColorType, ImageEncoder, RgbaImage, codecs::png::PngEncoder};
use sha2::{Digest, Sha256};

use crate::{
    ColorMode, PixelError, PixelRecipe, PixelSettings, RenderRecipe, RenderSettings,
    color::{apply_color_mode, flatten_alpha_onto_white},
    decode::decode_source,
    outline::apply_outline,
    palette::{Rgb, median_cut_palette},
    quantize::quantize,
    recipe::to_hex,
    settings::ValidatedSettings,
    transform::{center_crop_and_resize, crop_and_resize, upscale_nearest},
};

#[derive(Clone, Debug)]
pub struct PixelResult {
    pub png_bytes: Vec<u8>,
    pub logical_width: u32,
    pub logical_height: u32,
    pub width: u32,
    pub height: u32,
    pub palette: Vec<String>,
    pub recipe_json: String,
}

pub struct PixelSession {
    source: RgbaImage,
    input_sha256: String,
}

impl PixelSession {
    /// Decodes an image once so multiple recipes can reuse the same source.
    ///
    /// Only PNG, JPEG, and PPM inputs are accepted. Dimensions are inspected before decoding the
    /// full raster so oversized input is rejected before its main allocation.
    ///
    /// # Errors
    ///
    /// Returns an error when the bytes are not a supported image or exceed the input limit.
    pub fn new(encoded_image: &[u8]) -> Result<Self, PixelError> {
        let source = decode_source(encoded_image)?;
        Ok(Self {
            source,
            input_sha256: format!("{:x}", Sha256::digest(encoded_image)),
        })
    }

    #[must_use]
    pub fn source_dimensions(&self) -> (u32, u32) {
        self.source.dimensions()
    }

    /// Runs center crop, downscaling, palette reduction, dithering, nearest-neighbor scaling, and
    /// PNG/recipe encoding.
    ///
    /// # Errors
    ///
    /// Returns an error when settings are invalid or the PNG/recipe cannot be encoded.
    pub fn render(&self, settings: PixelSettings) -> Result<PixelResult, PixelError> {
        let settings = ValidatedSettings::try_from(settings)?;
        let pixel_settings = settings.settings();
        let rendered = RenderPipeline::new(&self.source, settings).execute();
        let palette = rendered.palette.iter().copied().map(to_hex).collect();
        let recipe = PixelRecipe::new(self.input_sha256.clone(), settings, palette);
        let recipe_json = serde_json::to_string_pretty(&recipe)?;
        let width = rendered.image.width();
        let height = rendered.image.height();
        let png_bytes = encode_png(&rendered.image)?;

        Ok(PixelResult {
            png_bytes,
            logical_width: pixel_settings.target_width,
            logical_height: pixel_settings.target_height,
            width,
            height,
            palette: recipe.palette,
            recipe_json,
        })
    }

    /// Converts the source using the initial product specification.
    ///
    /// The crop rectangle is non-destructive, the logical short side is derived from its aspect
    /// ratio, palette matching uses a perceptual color space, and output scaling is nearest-neighbor.
    ///
    /// # Errors
    ///
    /// Returns an error when the crop, palette, adjustment values, or output bounds are invalid,
    /// or when the PNG/recipe cannot be encoded.
    pub fn convert(&self, settings: RenderSettings) -> Result<PixelResult, PixelError> {
        let geometry = settings.validate(self.source.width(), self.source.height())?;
        let opaque_source = flatten_alpha_onto_white(&self.source);
        let reduced = crop_and_resize(
            &opaque_source,
            geometry.crop,
            geometry.target_width,
            geometry.target_height,
        );
        let colorized = apply_color_mode(&reduced, &settings.color_mode);
        let outlined = apply_outline(colorized, &reduced, settings.outline);
        let output = upscale_nearest(outlined, geometry.output_width, geometry.output_height);
        let palette = render_palette(&settings.color_mode);
        let recipe = RenderRecipe::new(
            self.input_sha256.clone(),
            settings,
            geometry,
            palette.clone(),
        );

        Ok(PixelResult {
            logical_width: geometry.target_width,
            logical_height: geometry.target_height,
            width: output.width(),
            height: output.height(),
            png_bytes: encode_png(&output)?,
            palette,
            recipe_json: serde_json::to_string_pretty(&recipe)?,
        })
    }
}

fn render_palette(color_mode: &ColorMode) -> Vec<String> {
    match color_mode {
        ColorMode::Source => Vec::new(),
        ColorMode::Palette { palette, .. } => palette
            .colors
            .iter()
            .map(|color| to_hex(color.channels()))
            .collect(),
    }
}

struct RenderPipeline<'source> {
    source: &'source RgbaImage,
    settings: ValidatedSettings,
}

impl<'source> RenderPipeline<'source> {
    const fn new(source: &'source RgbaImage, settings: ValidatedSettings) -> Self {
        Self { source, settings }
    }

    fn execute(self) -> RenderedPixels {
        let settings = self.settings.settings();
        let reduced =
            center_crop_and_resize(self.source, settings.target_width, settings.target_height);
        let palette = median_cut_palette(&reduced, usize::from(settings.color_count));
        let quantized = quantize(&reduced, &palette, settings.dither);
        let (output_width, output_height) = self.settings.output_dimensions();
        let image = upscale_nearest(quantized, output_width, output_height);
        RenderedPixels { image, palette }
    }
}

struct RenderedPixels {
    image: RgbaImage,
    palette: Vec<Rgb>,
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

#[cfg(test)]
mod tests {
    use std::io::Cursor;

    use image::{DynamicImage, ImageFormat, Rgba};

    use super::*;
    use crate::{
        ALGORITHM_VERSION, ColorMode, CropMode, CropRect, CropRegion, DitherMode,
        LEGACY_ALGORITHM_VERSION, OutlineMode, OutlineSettings, Palette, PaletteApplication,
        RECIPE_SCHEMA_VERSION, RENDER_RECIPE_SCHEMA_VERSION, RenderRecipe, RgbColor, SettingsError,
    };

    #[test]
    fn same_input_and_settings_produce_identical_rgba_and_recipe_for_every_strategy() {
        let input = fixture_png();
        let session = PixelSession::new(&input).expect("fixture should decode");

        for dither in [
            DitherMode::None,
            DitherMode::Bayer4x4,
            DitherMode::FloydSteinberg,
        ] {
            let settings = PixelSettings {
                target_width: 4,
                target_height: 4,
                color_count: 4,
                dither,
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
    }

    #[test]
    fn legacy_algorithm_version_0_2_0_has_stable_rgba_outputs() {
        assert_eq!(LEGACY_ALGORITHM_VERSION, "0.2.0");
        let input = fixture_png();
        let session = PixelSession::new(&input).expect("fixture should decode");
        let actual = [
            DitherMode::None,
            DitherMode::Bayer4x4,
            DitherMode::FloydSteinberg,
        ]
        .map(|dither| {
            let result = session
                .render(PixelSettings {
                    target_width: 4,
                    target_height: 4,
                    color_count: 4,
                    dither,
                    upscale: 2,
                })
                .expect("golden render should succeed");
            format!("{:x}", Sha256::digest(decoded_rgba(&result.png_bytes)))
        });

        assert_eq!(
            actual,
            [
                "a2862e5b24a3b081e54d10b24013752ce6017dec71807c31f399b180ef0ba729",
                "2e0eda142f69b4d60f1afeb246dbb126552c00f767804e6d9e1c6a87ee6cede4",
                "a2862e5b24a3b081e54d10b24013752ce6017dec71807c31f399b180ef0ba729",
            ]
        );
    }

    #[test]
    fn recipe_records_schema_hash_settings_palette_and_dimensions() {
        let input = b"P3\n2 1\n255\n12 34 56 200 210 220\n";
        let session = PixelSession::new(input).expect("fixture should decode");
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
        assert_eq!(recipe.schema_version, RECIPE_SCHEMA_VERSION);
        assert_eq!(recipe.algorithm_version, LEGACY_ALGORITHM_VERSION);
        assert_eq!(
            recipe.input_sha256,
            "d7805c8198e78ba95dd882fb4a5eb3ce3d42e59143d2f7a6927864a4684eae7a"
        );
        assert_eq!(recipe.target_width, settings.target_width);
        assert_eq!(recipe.target_height, settings.target_height);
        assert_eq!(recipe.output_width, 12);
        assert_eq!(recipe.output_height, 20);
        assert_eq!(recipe.color_count, settings.color_count);
        assert_eq!(recipe.dither, settings.dither);
        assert_eq!(recipe.upscale, settings.upscale);
        assert_eq!(recipe.crop, CropMode::CenterCover);
        assert_eq!(recipe.palette, result.palette);
        assert!(recipe.palette.len() <= usize::from(settings.color_count));
    }

    #[test]
    fn png_jpeg_and_ppm_inputs_are_supported() {
        let image = fixture_image();
        for (format, label) in [(ImageFormat::Png, "PNG"), (ImageFormat::Jpeg, "JPEG")] {
            let mut encoded = Cursor::new(Vec::new());
            DynamicImage::ImageRgba8(image.clone())
                .write_to(&mut encoded, format)
                .unwrap_or_else(|error| panic!("{label} fixture should encode: {error}"));

            PixelSession::new(&encoded.into_inner())
                .unwrap_or_else(|error| panic!("{label} fixture should decode: {error}"));
        }
        PixelSession::new(b"P3\n2 1\n255\n255 0 0 0 0 255\n").expect("PPM fixture should decode");
    }

    #[test]
    fn invalid_settings_return_a_structured_error_before_rendering() {
        let session = PixelSession::new(&fixture_png()).expect("fixture should decode");
        let settings = PixelSettings {
            color_count: 1,
            ..PixelSettings::default()
        };

        let error = session
            .render(settings)
            .expect_err("invalid palette should fail");

        assert!(matches!(
            error,
            PixelError::InvalidSettings(SettingsError::ColorCountOutOfRange {
                provided: 1,
                minimum: 2,
                maximum: 64,
            })
        ));
    }

    #[test]
    fn result_is_an_rgba_png_with_the_reported_dimensions() {
        let session = PixelSession::new(&fixture_png()).expect("fixture should decode");
        let result = session
            .render(PixelSettings {
                target_width: 3,
                target_height: 2,
                upscale: 3,
                ..PixelSettings::default()
            })
            .expect("render should succeed");
        let decoded = image::load_from_memory_with_format(&result.png_bytes, ImageFormat::Png)
            .expect("output should be a PNG");

        assert_eq!(decoded.color(), ColorType::Rgba8);
        assert_eq!(
            (decoded.width(), decoded.height()),
            (result.width, result.height)
        );
        assert_eq!((result.width, result.height), (9, 6));
    }

    #[test]
    fn convert_derives_dimensions_from_crop_and_keeps_source_colors() {
        let input = b"P3\n4 2\n255\n255 0 0  0 255 0  0 0 255  255 255 0\n255 0 0  0 255 0  0 0 255  255 255 0\n";
        let session = PixelSession::new(input).expect("fixture should decode");
        let settings = RenderSettings {
            long_side: 4,
            upscale: 2,
            crop: CropRegion::Rectangle {
                rect: CropRect {
                    x: 1,
                    y: 0,
                    width: 2,
                    height: 2,
                },
            },
            color_mode: ColorMode::Source,
            outline: OutlineSettings::default(),
        };

        let result = session
            .convert(settings)
            .expect("conversion should succeed");
        let pixels = decoded_image(&result.png_bytes);

        assert_eq!((result.logical_width, result.logical_height), (4, 4));
        assert_eq!((result.width, result.height), (8, 8));
        assert_eq!(pixels.get_pixel(0, 0), &Rgba([0, 255, 0, 255]));
        assert_eq!(pixels.get_pixel(7, 0), &Rgba([0, 0, 255, 255]));
        assert!(result.palette.is_empty());
    }

    #[test]
    fn convert_applies_explicit_palette_without_generating_colors() {
        let session = PixelSession::new(b"P3\n2 1\n255\n240 30 30  20 30 240\n")
            .expect("fixture should decode");
        let settings = RenderSettings {
            long_side: 2,
            upscale: 1,
            color_mode: ColorMode::Palette {
                palette: Palette {
                    name: "two-color".into(),
                    colors: vec![RgbColor::new(255, 0, 0), RgbColor::new(0, 0, 255)],
                },
                application: PaletteApplication::Exact,
            },
            ..RenderSettings::default()
        };

        let result = session
            .convert(settings)
            .expect("conversion should succeed");
        let pixels = decoded_image(&result.png_bytes);

        assert_eq!(pixels.get_pixel(0, 0), &Rgba([255, 0, 0, 255]));
        assert_eq!(pixels.get_pixel(1, 0), &Rgba([0, 0, 255, 255]));
        assert_eq!(result.palette, ["#FF0000", "#0000FF"]);
    }

    #[test]
    fn convert_adds_region_boundaries_instead_of_grid_lines() {
        let session = PixelSession::new(
            b"P3\n4 2\n255\n20 20 20  20 20 20  240 240 240  240 240 240\n20 20 20  20 20 20  240 240 240  240 240 240\n",
        )
        .expect("fixture should decode");
        let result = session
            .convert(RenderSettings {
                long_side: 4,
                upscale: 1,
                outline: OutlineSettings {
                    mode: OutlineMode::Black,
                    threshold: 10,
                },
                ..RenderSettings::default()
            })
            .expect("conversion should succeed");
        let pixels = decoded_image(&result.png_bytes);

        assert_eq!(pixels.get_pixel(1, 0), &Rgba([0, 0, 0, 255]));
        assert_eq!(pixels.get_pixel(0, 0), &Rgba([20, 20, 20, 255]));
        assert_eq!(pixels.get_pixel(2, 0), &Rgba([240, 240, 240, 255]));
    }

    #[test]
    fn convert_recipe_contains_every_setting_and_actual_dimension() {
        let session =
            PixelSession::new(b"P3\n3 2\n255\n1 2 3  4 5 6  7 8 9\n10 11 12  13 14 15  16 17 18\n")
                .expect("fixture should decode");
        let settings = RenderSettings {
            long_side: 6,
            upscale: 3,
            crop: CropRegion::Full,
            color_mode: ColorMode::Source,
            outline: OutlineSettings {
                mode: OutlineMode::Adaptive,
                threshold: 25,
            },
        };

        let result = session
            .convert(settings.clone())
            .expect("conversion should succeed");
        let recipe: RenderRecipe =
            serde_json::from_str(&result.recipe_json).expect("recipe should decode");

        assert_eq!(recipe.schema_version, RENDER_RECIPE_SCHEMA_VERSION);
        assert_eq!(recipe.algorithm_version, ALGORITHM_VERSION);
        assert_eq!(recipe.settings, settings);
        assert_eq!((recipe.logical_width, recipe.logical_height), (6, 4));
        assert_eq!((recipe.output_width, recipe.output_height), (18, 12));
        assert_eq!((result.width, result.height), (18, 12));
    }

    #[test]
    fn converter_algorithm_version_1_2_0_has_stable_rgba_and_recipe() {
        assert_eq!(ALGORITHM_VERSION, "1.2.0");
        let session = PixelSession::new(&fixture_png()).expect("fixture should decode");
        let settings = RenderSettings {
            long_side: 5,
            upscale: 2,
            crop: CropRegion::Rectangle {
                rect: CropRect {
                    x: 1,
                    y: 1,
                    width: 6,
                    height: 4,
                },
            },
            color_mode: ColorMode::Palette {
                palette: Palette {
                    name: "golden".into(),
                    colors: vec![
                        RgbColor::new(30, 40, 80),
                        RgbColor::new(180, 45, 70),
                        RgbColor::new(230, 200, 120),
                    ],
                },
                application: PaletteApplication::PreserveTone {
                    preservation: crate::TonePreservation {
                        saturation: 35,
                        lightness: 60,
                    },
                },
            },
            outline: OutlineSettings {
                mode: OutlineMode::Adaptive,
                threshold: 12,
            },
        };

        let first = session
            .convert(settings.clone())
            .expect("first conversion should succeed");
        let second = session
            .convert(settings)
            .expect("second conversion should succeed");
        let rgba_hash = format!("{:x}", Sha256::digest(decoded_rgba(&first.png_bytes)));

        assert_eq!(first.recipe_json, second.recipe_json);
        assert_eq!(
            decoded_rgba(&first.png_bytes),
            decoded_rgba(&second.png_bytes)
        );
        assert_eq!(
            rgba_hash,
            "4e45729df2e05d71c2de3b24c91051f91034c2c3b496554a02959dddc29a0e98"
        );
    }

    fn fixture_image() -> RgbaImage {
        RgbaImage::from_fn(8, 6, |x, y| {
            Rgba([
                u8::try_from(x * 31).expect("fixture red channel stays in range"),
                u8::try_from(y * 43).expect("fixture green channel stays in range"),
                u8::try_from((x + y) * 17).expect("fixture blue channel stays in range"),
                u8::MAX,
            ])
        })
    }

    fn fixture_png() -> Vec<u8> {
        let mut bytes = Cursor::new(Vec::new());
        DynamicImage::ImageRgba8(fixture_image())
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

    fn decoded_image(bytes: &[u8]) -> RgbaImage {
        image::load_from_memory(bytes)
            .expect("result should decode")
            .to_rgba8()
    }
}
