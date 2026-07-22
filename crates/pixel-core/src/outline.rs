use image::{Rgba, RgbaImage};

use crate::{
    OutlineMode, OutlineSettings, RgbColor,
    color::{darken_preserving_hue, perceptual_distance_squared, perceptual_lightness},
};

pub(crate) fn apply_outline(
    mut image: RgbaImage,
    reference: &RgbaImage,
    settings: OutlineSettings,
) -> RgbaImage {
    if settings.mode == OutlineMode::None {
        return image;
    }
    debug_assert_eq!(image.dimensions(), reference.dimensions());
    let width = reference.width();
    let height = reference.height();
    let mut edges = vec![false; width as usize * height as usize];
    let threshold = f32::from(settings.threshold) / 100.0;
    let threshold_squared = threshold * threshold;

    for y in 0..height {
        for x in 0..width {
            if x + 1 < width {
                mark_darker_edge(reference, &mut edges, (x, y), (x + 1, y), threshold_squared);
            }
            if y + 1 < height {
                mark_darker_edge(reference, &mut edges, (x, y), (x, y + 1), threshold_squared);
            }
        }
    }

    thin_l_shaped_corners(&mut edges, width, height);

    for (index, is_edge) in edges.into_iter().enumerate() {
        if !is_edge {
            continue;
        }
        let index = u32::try_from(index).expect("validated target dimensions fit in u32");
        let x = index % width;
        let y = index / width;
        let output = match settings.mode {
            OutlineMode::None => unreachable!("none mode returns before edge detection"),
            OutlineMode::Black => RgbColor::new(0, 0, 0),
            OutlineMode::Adaptive => darken_preserving_hue(rgb_at(&image, x, y)),
        };
        image.put_pixel(x, y, Rgba([output.red, output.green, output.blue, u8::MAX]));
    }
    image
}

fn mark_darker_edge(
    reference: &RgbaImage,
    edges: &mut [bool],
    first: (u32, u32),
    second: (u32, u32),
    threshold_squared: f32,
) {
    let first_color = rgb_at(reference, first.0, first.1);
    let second_color = rgb_at(reference, second.0, second.1);
    if perceptual_distance_squared(first_color, second_color) <= threshold_squared {
        return;
    }
    let darker = if perceptual_lightness(first_color) <= perceptual_lightness(second_color) {
        first
    } else {
        second
    };
    let index = darker.1 as usize * reference.width() as usize + darker.0 as usize;
    edges[index] = true;
}

fn thin_l_shaped_corners(edges: &mut [bool], width: u32, height: u32) {
    if width < 2 || height < 2 {
        return;
    }
    loop {
        let original = edges.to_vec();
        let mut removals = vec![false; edges.len()];
        for y in 0..height - 1 {
            for x in 0..width - 1 {
                let top_left = edge_at(&original, width, x, y);
                let top_right = edge_at(&original, width, x + 1, y);
                let bottom_left = edge_at(&original, width, x, y + 1);
                let bottom_right = edge_at(&original, width, x + 1, y + 1);
                let elbow = match (top_left, top_right, bottom_left, bottom_right) {
                    (false, true, true, true) => Some((x + 1, y + 1)),
                    (true, false, true, true) => Some((x, y + 1)),
                    (true, true, false, true) => Some((x + 1, y)),
                    (true, true, true, false) => Some((x, y)),
                    _ => None,
                };
                if let Some((elbow_x, elbow_y)) = elbow {
                    let index = elbow_y as usize * width as usize + elbow_x as usize;
                    removals[index] = true;
                }
            }
        }
        if !removals.iter().any(|remove| *remove) {
            break;
        }
        for (edge, remove) in edges.iter_mut().zip(removals) {
            if remove {
                *edge = false;
            }
        }
    }
}

fn edge_at(edges: &[bool], width: u32, x: u32, y: u32) -> bool {
    edges[y as usize * width as usize + x as usize]
}

fn rgb_at(image: &RgbaImage, x: u32, y: u32) -> RgbColor {
    let pixel = image.get_pixel(x, y);
    RgbColor::new(pixel[0], pixel[1], pixel[2])
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn black_outline_marks_only_the_darker_side_of_a_boundary() {
        let image = RgbaImage::from_raw(
            3,
            1,
            vec![20, 20, 20, 255, 240, 240, 240, 255, 240, 240, 240, 255],
        )
        .expect("fixture dimensions should match");

        let result = apply_outline(
            image.clone(),
            &image,
            OutlineSettings {
                mode: OutlineMode::Black,
                threshold: 10,
            },
        );

        assert_eq!(result.get_pixel(0, 0), &Rgba([0, 0, 0, 255]));
        assert_eq!(result.get_pixel(1, 0), &Rgba([240, 240, 240, 255]));
        assert_eq!(result.get_pixel(2, 0), &Rgba([240, 240, 240, 255]));
    }

    #[test]
    fn uniform_regions_do_not_turn_into_grid_lines() {
        let image = RgbaImage::from_pixel(4, 4, Rgba([80, 120, 160, 255]));

        let result = apply_outline(
            image.clone(),
            &image,
            OutlineSettings {
                mode: OutlineMode::Black,
                threshold: 0,
            },
        );

        assert_eq!(result, image);
    }

    #[test]
    fn adaptive_outline_keeps_color_and_reduces_lightness() {
        let image = RgbaImage::from_raw(2, 1, vec![190, 40, 50, 255, 250, 230, 220, 255])
            .expect("fixture dimensions should match");

        let result = apply_outline(
            image.clone(),
            &image,
            OutlineSettings {
                mode: OutlineMode::Adaptive,
                threshold: 5,
            },
        );
        let outlined = rgb_at(&result, 0, 0);

        assert!(outlined.red > outlined.green);
        assert!(outlined.red > outlined.blue);
        assert!(perceptual_lightness(outlined) < perceptual_lightness(rgb_at(&image, 0, 0)));
    }

    #[test]
    fn every_outline_color_replaces_an_l_shaped_corner_with_a_diagonal_step() {
        let image = RgbaImage::from_raw(
            2,
            2,
            vec![
                20, 20, 20, 255, 80, 30, 30, 255, 30, 80, 30, 255, 240, 240, 240, 255,
            ],
        )
        .expect("fixture dimensions should match");

        for mode in [OutlineMode::Black, OutlineMode::Adaptive] {
            let result = apply_outline(
                image.clone(),
                &image,
                OutlineSettings { mode, threshold: 5 },
            );

            assert_eq!(result.get_pixel(0, 0), image.get_pixel(0, 0));
            assert!(
                perceptual_lightness(rgb_at(&result, 1, 0))
                    < perceptual_lightness(rgb_at(&image, 1, 0))
            );
            assert!(
                perceptual_lightness(rgb_at(&result, 0, 1))
                    < perceptual_lightness(rgb_at(&image, 0, 1))
            );
            assert_eq!(result.get_pixel(1, 1), image.get_pixel(1, 1));
        }
    }

    #[test]
    fn high_threshold_ignores_small_color_differences() {
        let image = RgbaImage::from_raw(2, 1, vec![100, 100, 100, 255, 110, 110, 110, 255])
            .expect("fixture dimensions should match");

        let result = apply_outline(
            image.clone(),
            &image,
            OutlineSettings {
                mode: OutlineMode::Black,
                threshold: 20,
            },
        );

        assert_eq!(result, image);
    }

    #[test]
    fn black_outline_replaces_an_l_shaped_corner_with_a_diagonal_step() {
        let mut edges = vec![true, true, false, true, false, false, false, false, false];

        thin_l_shaped_corners(&mut edges, 3, 3);

        assert_eq!(
            edges,
            vec![false, true, false, true, false, false, false, false, false]
        );
    }

    #[test]
    fn corner_thinning_preserves_straight_lines_and_solid_blocks() {
        let mut straight = vec![true, true, true];
        let mut solid = vec![true, true, true, true];

        thin_l_shaped_corners(&mut straight, 3, 1);
        thin_l_shaped_corners(&mut solid, 2, 2);

        assert_eq!(straight, vec![true, true, true]);
        assert_eq!(solid, vec![true, true, true, true]);
    }

    #[test]
    fn corner_thinning_removes_overlapping_l_shapes_until_stable() {
        let mut edges = vec![false, true, true, true, true, false, true, true, true];

        thin_l_shaped_corners(&mut edges, 3, 3);

        for y in 0..2 {
            for x in 0..2 {
                let black_count = u8::from(edge_at(&edges, 3, x, y))
                    + u8::from(edge_at(&edges, 3, x + 1, y))
                    + u8::from(edge_at(&edges, 3, x, y + 1))
                    + u8::from(edge_at(&edges, 3, x + 1, y + 1));
                assert_ne!(black_count, 3);
            }
        }
    }
}
