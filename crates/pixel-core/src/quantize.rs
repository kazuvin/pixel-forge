use image::{Rgba, RgbaImage};

use crate::{DitherMode, palette::Rgb};

pub(crate) fn quantize(image: &RgbaImage, palette: &[Rgb], mode: DitherMode) -> RgbaImage {
    match mode {
        DitherMode::None => without_dither(image, palette),
        DitherMode::Bayer4x4 => bayer_4x4(image, palette),
        DitherMode::FloydSteinberg => floyd_steinberg(image, palette),
    }
}

fn without_dither(image: &RgbaImage, palette: &[Rgb]) -> RgbaImage {
    RgbaImage::from_fn(image.width(), image.height(), |x, y| {
        quantized_pixel(*image.get_pixel(x, y), palette, 0.0)
    })
}

fn bayer_4x4(image: &RgbaImage, palette: &[Rgb]) -> RgbaImage {
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
fn floyd_steinberg(image: &RgbaImage, palette: &[Rgb]) -> RgbaImage {
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
fn quantized_pixel(pixel: Rgba<u8>, palette: &[Rgb], adjustment: f32) -> Rgba<u8> {
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

fn nearest_palette(color: Rgb, palette: &[Rgb]) -> Rgb {
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn every_strategy_emits_only_palette_colors_and_preserves_alpha() {
        let image = RgbaImage::from_fn(5, 4, |x, y| {
            Rgba([
                u8::try_from(x * 45).expect("fixture red is in range"),
                u8::try_from(y * 55).expect("fixture green is in range"),
                100,
                if x == 0 && y == 0 { 0 } else { 173 },
            ])
        });
        let palette = [[0, 0, 0], [120, 80, 100], [255, 255, 255]];

        for mode in [
            DitherMode::None,
            DitherMode::Bayer4x4,
            DitherMode::FloydSteinberg,
        ] {
            let result = quantize(&image, &palette, mode);
            for (source, output) in image.pixels().zip(result.pixels()) {
                assert_eq!(output[3], source[3]);
                if output[3] == 0 {
                    assert_eq!(*output, Rgba([0, 0, 0, 0]));
                } else {
                    assert!(palette.contains(&[output[0], output[1], output[2]]));
                }
            }
        }
    }

    #[test]
    fn palette_ties_use_the_first_color() {
        assert_eq!(
            nearest_palette([10, 10, 10], &[[0, 10, 10], [20, 10, 10]]),
            [0, 10, 10]
        );
    }

    #[test]
    fn bayer_uses_a_repeatable_four_by_four_threshold() {
        let image = RgbaImage::from_pixel(8, 4, Rgba([128, 128, 128, 255]));
        let result = quantize(&image, &[[0, 0, 0], [255, 255, 255]], DitherMode::Bayer4x4);

        for y in 0..4 {
            for x in 0..4 {
                assert_eq!(result.get_pixel(x, y), result.get_pixel(x + 4, y));
            }
        }
        assert!(result.pixels().any(|pixel| pixel[0] == 0));
        assert!(result.pixels().any(|pixel| pixel[0] == 255));
    }
}
