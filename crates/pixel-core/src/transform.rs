use std::cmp::Ordering;

use image::{RgbaImage, imageops::FilterType};

use crate::CropRect;

pub(crate) fn crop_and_resize(
    source: &RgbaImage,
    crop: CropRect,
    target_width: u32,
    target_height: u32,
) -> RgbaImage {
    let cropped =
        image::imageops::crop_imm(source, crop.x, crop.y, crop.width, crop.height).to_image();
    if cropped.width() == target_width && cropped.height() == target_height {
        cropped
    } else {
        image::imageops::resize(&cropped, target_width, target_height, FilterType::Triangle)
    }
}

pub(crate) fn center_crop_and_resize(
    source: &RgbaImage,
    target_width: u32,
    target_height: u32,
) -> RgbaImage {
    let source_width = source.width();
    let source_height = source.height();
    let source_ratio = u64::from(source_width) * u64::from(target_height);
    let target_ratio = u64::from(source_height) * u64::from(target_width);

    let (x, y, crop_width, crop_height) = match source_ratio.cmp(&target_ratio) {
        Ordering::Greater => {
            let crop_width =
                rounded_ratio(source_height, target_width, target_height).clamp(1, source_width);
            (
                (source_width - crop_width) / 2,
                0,
                crop_width,
                source_height,
            )
        }
        Ordering::Less => {
            let crop_height =
                rounded_ratio(source_width, target_height, target_width).clamp(1, source_height);
            (
                0,
                (source_height - crop_height) / 2,
                source_width,
                crop_height,
            )
        }
        Ordering::Equal => (0, 0, source_width, source_height),
    };

    let cropped = image::imageops::crop_imm(source, x, y, crop_width, crop_height).to_image();
    if cropped.width() == target_width && cropped.height() == target_height {
        cropped
    } else {
        image::imageops::resize(&cropped, target_width, target_height, FilterType::Triangle)
    }
}

pub(crate) fn upscale_nearest(
    image: RgbaImage,
    output_width: u32,
    output_height: u32,
) -> RgbaImage {
    if image.width() == output_width && image.height() == output_height {
        image
    } else {
        image::imageops::resize(&image, output_width, output_height, FilterType::Nearest)
    }
}

fn rounded_ratio(value: u32, numerator: u32, denominator: u32) -> u32 {
    let scaled = u64::from(value) * u64::from(numerator);
    u32::try_from((scaled + u64::from(denominator) / 2) / u64::from(denominator))
        .expect("validated image and target dimensions keep the ratio in the u32 range")
}

#[cfg(test)]
mod tests {
    use image::Rgba;

    use super::*;

    #[test]
    fn center_crop_removes_both_sides_evenly() {
        let source = RgbaImage::from_fn(6, 2, |x, _| {
            let value = u8::try_from(x * 40).expect("fixture channel is in range");
            Rgba([value, 0, 0, u8::MAX])
        });

        let result = center_crop_and_resize(&source, 2, 2);

        assert_eq!(result.get_pixel(0, 0), &Rgba([80, 0, 0, u8::MAX]));
        assert_eq!(result.get_pixel(1, 0), &Rgba([120, 0, 0, u8::MAX]));
    }

    #[test]
    fn center_crop_removes_top_and_bottom_evenly() {
        let source = RgbaImage::from_fn(2, 6, |_, y| {
            let value = u8::try_from(y * 40).expect("fixture channel is in range");
            Rgba([0, value, 0, u8::MAX])
        });

        let result = center_crop_and_resize(&source, 2, 2);

        assert_eq!(result.get_pixel(0, 0), &Rgba([0, 80, 0, u8::MAX]));
        assert_eq!(result.get_pixel(0, 1), &Rgba([0, 120, 0, u8::MAX]));
    }

    #[test]
    fn nearest_upscale_repeats_pixels_without_interpolation() {
        let source = RgbaImage::from_fn(2, 1, |x, _| {
            if x == 0 {
                Rgba([255, 0, 0, 255])
            } else {
                Rgba([0, 0, 255, 255])
            }
        });

        let result = upscale_nearest(source, 6, 3);

        for y in 0..3 {
            assert_eq!(result.get_pixel(0, y), &Rgba([255, 0, 0, 255]));
            assert_eq!(result.get_pixel(2, y), &Rgba([255, 0, 0, 255]));
            assert_eq!(result.get_pixel(3, y), &Rgba([0, 0, 255, 255]));
            assert_eq!(result.get_pixel(5, y), &Rgba([0, 0, 255, 255]));
        }
    }
}
