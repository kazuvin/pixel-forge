use std::collections::BTreeMap;

use image::RgbaImage;

pub(crate) type Rgb = [u8; 3];

#[derive(Clone, Debug)]
struct WeightedColor {
    rgb: Rgb,
    count: u32,
}

#[derive(Debug)]
struct ColorBox {
    colors: Vec<WeightedColor>,
}

impl ColorBox {
    fn split_score(&self) -> Option<u64> {
        if self.colors.len() < 2 {
            return None;
        }
        let range = u64::from(*self.channel_ranges().iter().max().unwrap_or(&0));
        Some(range * self.population())
    }

    fn split(mut self) -> Option<(Self, Self)> {
        if self.colors.len() < 2 {
            return None;
        }
        let channel = self.split_channel();
        self.colors.sort_by_key(|color| {
            (
                color.rgb[channel],
                color.rgb[(channel + 1) % 3],
                color.rgb[(channel + 2) % 3],
            )
        });

        let total = self.population();
        let mut accumulated = 0_u64;
        let mut split_index = 1;
        for (index, color) in self.colors.iter().enumerate().take(self.colors.len() - 1) {
            accumulated += u64::from(color.count);
            split_index = index + 1;
            if accumulated * 2 >= total {
                break;
            }
        }

        let right = self.colors.split_off(split_index);
        Some((self, Self { colors: right }))
    }

    fn split_channel(&self) -> usize {
        let ranges = self.channel_ranges();
        if ranges[1] > ranges[0] && ranges[1] >= ranges[2] {
            1
        } else if ranges[2] > ranges[0] && ranges[2] > ranges[1] {
            2
        } else {
            0
        }
    }

    fn channel_ranges(&self) -> Rgb {
        let mut minimum = [u8::MAX; 3];
        let mut maximum = [u8::MIN; 3];
        for color in &self.colors {
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

    fn population(&self) -> u64 {
        self.colors.iter().map(|color| u64::from(color.count)).sum()
    }

    fn average(&self) -> Rgb {
        let total = self.population();
        let mut channels = [0_u64; 3];
        for color in &self.colors {
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
}

pub(crate) fn median_cut_palette(image: &RgbaImage, limit: usize) -> Vec<Rgb> {
    let mut histogram = BTreeMap::<Rgb, u32>::new();
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
    let mut boxes = vec![ColorBox { colors }];

    while boxes.len() < limit {
        let Some(index) = best_box_to_split(&boxes) else {
            break;
        };
        let color_box = boxes.remove(index);
        let Some((left, right)) = color_box.split() else {
            break;
        };
        boxes.insert(index, right);
        boxes.insert(index, left);
    }

    let mut palette = boxes.iter().map(ColorBox::average).collect::<Vec<_>>();
    palette.sort_by_key(|rgb| {
        (
            u32::from(rgb[0]) * 2126 + u32::from(rgb[1]) * 7152 + u32::from(rgb[2]) * 722,
            *rgb,
        )
    });
    palette
}

fn best_box_to_split(boxes: &[ColorBox]) -> Option<usize> {
    let mut best = None;
    let mut best_score = 0_u64;
    for (index, color_box) in boxes.iter().enumerate() {
        let Some(score) = color_box.split_score() else {
            continue;
        };
        if best.is_none() || score > best_score {
            best = Some(index);
            best_score = score;
        }
    }
    best
}

#[cfg(test)]
mod tests {
    use image::Rgba;

    use super::*;

    #[test]
    fn weighted_average_accounts_for_repeated_colors() {
        let image = RgbaImage::from_fn(4, 1, |x, _| {
            if x == 0 {
                Rgba([0, 0, 0, 255])
            } else {
                Rgba([200, 100, 0, 255])
            }
        });

        assert_eq!(median_cut_palette(&image, 1), vec![[150, 75, 0]]);
    }

    #[test]
    fn transparent_pixels_do_not_bias_the_palette() {
        let image = RgbaImage::from_raw(2, 1, vec![255, 0, 0, 0, 0, 0, 255, 255])
            .expect("fixture dimensions match its bytes");

        assert_eq!(median_cut_palette(&image, 8), vec![[0, 0, 255]]);
    }

    #[test]
    fn palette_order_and_tie_breaks_are_deterministic() {
        let image = RgbaImage::from_fn(4, 4, |x, y| {
            Rgba([
                u8::try_from(x * 60).expect("fixture red is in range"),
                u8::try_from(y * 60).expect("fixture green is in range"),
                u8::try_from((x + y) * 30).expect("fixture blue is in range"),
                255,
            ])
        });

        let first = median_cut_palette(&image, 5);
        for _ in 0..10 {
            assert_eq!(median_cut_palette(&image, 5), first);
        }
        assert_eq!(first.len(), 5);
    }
}
