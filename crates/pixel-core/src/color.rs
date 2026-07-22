use image::{Rgba, RgbaImage};

use crate::{ColorMode, PaletteApplication, RgbColor, TonePreservation};

#[derive(Clone, Copy, Debug)]
struct Oklab {
    lightness: f32,
    a: f32,
    b: f32,
}

#[derive(Clone, Copy, Debug)]
struct Hsl {
    hue: f32,
    saturation: f32,
    lightness: f32,
}

pub(crate) fn flatten_alpha_onto_white(image: &RgbaImage) -> RgbaImage {
    RgbaImage::from_fn(image.width(), image.height(), |x, y| {
        let source = image.get_pixel(x, y);
        let alpha = u32::from(source[3]);
        let blend = |channel: u8| {
            let foreground = u32::from(channel) * alpha;
            let background = u32::from(u8::MAX) * (u32::from(u8::MAX) - alpha);
            u8::try_from((foreground + background + 127) / 255)
                .expect("alpha compositing stays in the u8 range")
        };
        Rgba([
            blend(source[0]),
            blend(source[1]),
            blend(source[2]),
            u8::MAX,
        ])
    })
}

pub(crate) fn apply_color_mode(image: &RgbaImage, color_mode: &ColorMode) -> RgbaImage {
    let ColorMode::Palette {
        palette,
        application,
    } = color_mode
    else {
        return image.clone();
    };

    let prepared = palette
        .colors
        .iter()
        .copied()
        .map(|color| (color, to_oklab(color)))
        .collect::<Vec<_>>();
    RgbaImage::from_fn(image.width(), image.height(), |x, y| {
        let source = RgbColor::new(
            image.get_pixel(x, y)[0],
            image.get_pixel(x, y)[1],
            image.get_pixel(x, y)[2],
        );
        let base = nearest_palette_color(source, &prepared);
        let output = match application {
            PaletteApplication::Exact => base,
            PaletteApplication::PreserveTone { preservation } => {
                preserve_tone(source, base, *preservation)
            }
        };
        Rgba([output.red, output.green, output.blue, u8::MAX])
    })
}

pub(crate) fn perceptual_distance_squared(left: RgbColor, right: RgbColor) -> f32 {
    let left = to_oklab(left);
    let right = to_oklab(right);
    (left.lightness - right.lightness).powi(2)
        + (left.a - right.a).powi(2)
        + (left.b - right.b).powi(2)
}

pub(crate) fn perceptual_lightness(color: RgbColor) -> f32 {
    to_oklab(color).lightness
}

pub(crate) fn darken_preserving_hue(color: RgbColor) -> RgbColor {
    let mut hsl = to_hsl(color);
    hsl.lightness *= 0.42;
    from_hsl(hsl)
}

fn nearest_palette_color(source: RgbColor, palette: &[(RgbColor, Oklab)]) -> RgbColor {
    let source_lab = to_oklab(source);
    let mut nearest = palette[0].0;
    let mut nearest_distance = oklab_distance_squared(source_lab, palette[0].1);
    for &(candidate, candidate_lab) in &palette[1..] {
        let distance = oklab_distance_squared(source_lab, candidate_lab);
        if distance < nearest_distance {
            nearest = candidate;
            nearest_distance = distance;
        }
    }
    nearest
}

fn preserve_tone(source: RgbColor, base: RgbColor, preservation: TonePreservation) -> RgbColor {
    if preservation.saturation == 0 && preservation.lightness == 0 {
        return base;
    }
    let source_hsl = to_hsl(source);
    let base_hsl = to_hsl(base);
    let saturation_weight = f32::from(preservation.saturation) / 100.0;
    let lightness_weight = f32::from(preservation.lightness) / 100.0;
    let hue = if base_hsl.saturation <= f32::EPSILON {
        source_hsl.hue
    } else {
        base_hsl.hue
    };
    from_hsl(Hsl {
        hue,
        saturation: lerp(
            base_hsl.saturation,
            source_hsl.saturation,
            saturation_weight,
        ),
        lightness: lerp(base_hsl.lightness, source_hsl.lightness, lightness_weight),
    })
}

fn to_oklab(color: RgbColor) -> Oklab {
    let [red, green, blue] = color.channels().map(srgb_to_linear);
    let l = 0.412_221_46 * red + 0.536_332_55 * green + 0.051_445_995 * blue;
    let m = 0.211_903_5 * red + 0.680_699_5 * green + 0.107_396_96 * blue;
    let s = 0.088_302_46 * red + 0.281_718_85 * green + 0.629_978_7 * blue;
    let l_root = l.cbrt();
    let m_root = m.cbrt();
    let s_root = s.cbrt();
    Oklab {
        lightness: 0.210_454_26 * l_root + 0.793_617_8 * m_root - 0.004_072_047 * s_root,
        a: 1.977_998_5 * l_root - 2.428_592_2 * m_root + 0.450_593_7 * s_root,
        b: 0.025_904_037 * l_root + 0.782_771_77 * m_root - 0.808_675_77 * s_root,
    }
}

fn srgb_to_linear(channel: u8) -> f32 {
    let channel = f32::from(channel) / 255.0;
    if channel <= 0.040_45 {
        channel / 12.92
    } else {
        ((channel + 0.055) / 1.055).powf(2.4)
    }
}

fn oklab_distance_squared(left: Oklab, right: Oklab) -> f32 {
    (left.lightness - right.lightness).powi(2)
        + (left.a - right.a).powi(2)
        + (left.b - right.b).powi(2)
}

fn to_hsl(color: RgbColor) -> Hsl {
    let red = f32::from(color.red) / 255.0;
    let green = f32::from(color.green) / 255.0;
    let blue = f32::from(color.blue) / 255.0;
    let maximum = red.max(green).max(blue);
    let minimum = red.min(green).min(blue);
    let delta = maximum - minimum;
    let lightness = f32::midpoint(maximum, minimum);
    if delta <= f32::EPSILON {
        return Hsl {
            hue: 0.0,
            saturation: 0.0,
            lightness,
        };
    }
    let saturation = delta / (1.0 - (2.0 * lightness - 1.0).abs());
    let maximum_channel = color.red.max(color.green).max(color.blue);
    let hue_sector = if maximum_channel == color.red {
        ((green - blue) / delta).rem_euclid(6.0)
    } else if maximum_channel == color.green {
        (blue - red) / delta + 2.0
    } else {
        (red - green) / delta + 4.0
    };
    Hsl {
        hue: hue_sector / 6.0,
        saturation,
        lightness,
    }
}

#[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
fn from_hsl(hsl: Hsl) -> RgbColor {
    let chroma = (1.0 - (2.0 * hsl.lightness - 1.0).abs()) * hsl.saturation;
    let sector = hsl.hue.rem_euclid(1.0) * 6.0;
    let intermediate = chroma * (1.0 - (sector.rem_euclid(2.0) - 1.0).abs());
    let (red, green, blue) = match sector {
        value if value < 1.0 => (chroma, intermediate, 0.0),
        value if value < 2.0 => (intermediate, chroma, 0.0),
        value if value < 3.0 => (0.0, chroma, intermediate),
        value if value < 4.0 => (0.0, intermediate, chroma),
        value if value < 5.0 => (intermediate, 0.0, chroma),
        _ => (chroma, 0.0, intermediate),
    };
    let offset = hsl.lightness - chroma / 2.0;
    let encode = |channel: f32| ((channel + offset).clamp(0.0, 1.0) * 255.0).round() as u8;
    RgbColor::new(encode(red), encode(green), encode(blue))
}

fn lerp(from: f32, to: f32, amount: f32) -> f32 {
    from + (to - from) * amount
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::Palette;

    #[test]
    fn alpha_is_composited_onto_white_and_removed() {
        let image = RgbaImage::from_raw(2, 1, vec![10, 20, 30, 0, 0, 0, 0, 128])
            .expect("fixture dimensions should match");

        let flattened = flatten_alpha_onto_white(&image);

        assert_eq!(flattened.get_pixel(0, 0), &Rgba([255, 255, 255, 255]));
        assert_eq!(flattened.get_pixel(1, 0), &Rgba([127, 127, 127, 255]));
    }

    #[test]
    fn exact_palette_mapping_uses_perceptual_nearest_color() {
        let image = RgbaImage::from_pixel(1, 1, Rgba([240, 40, 30, 255]));
        let mode = ColorMode::Palette {
            palette: Palette {
                name: "test".into(),
                colors: vec![RgbColor::new(0, 0, 255), RgbColor::new(255, 0, 0)],
            },
            application: PaletteApplication::Exact,
        };

        let result = apply_color_mode(&image, &mode);

        assert_eq!(result.get_pixel(0, 0), &Rgba([255, 0, 0, 255]));
    }

    #[test]
    fn zero_tone_preservation_is_identical_to_exact_palette_mapping() {
        let source = RgbColor::new(50, 180, 220);
        let base = RgbColor::new(180, 40, 80);

        assert_eq!(
            preserve_tone(source, base, TonePreservation::default()),
            base
        );
    }

    #[test]
    fn full_tone_preservation_uses_palette_hue_and_source_tone() {
        let source = RgbColor::new(70, 210, 140);
        let base = RgbColor::new(200, 50, 70);
        let output = preserve_tone(
            source,
            base,
            TonePreservation {
                saturation: 100,
                lightness: 100,
            },
        );
        let source_hsl = to_hsl(source);
        let base_hsl = to_hsl(base);
        let output_hsl = to_hsl(output);

        assert!((output_hsl.hue - base_hsl.hue).abs() < 0.01);
        assert!((output_hsl.saturation - source_hsl.saturation).abs() < 0.01);
        assert!((output_hsl.lightness - source_hsl.lightness).abs() < 0.01);
    }
}
