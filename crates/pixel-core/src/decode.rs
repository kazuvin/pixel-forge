use std::io::Cursor;

use image::{ImageError, ImageFormat, ImageReader, Limits, RgbaImage};

use crate::{PixelError, settings::MAX_INPUT_PIXELS};

const MAX_BYTES_PER_DECODED_PIXEL: u64 = 8;

pub(crate) fn decode_source(encoded_image: &[u8]) -> Result<RgbaImage, PixelError> {
    let guessed = ImageReader::new(Cursor::new(encoded_image))
        .with_guessed_format()
        .map_err(ImageError::IoError)?;
    let format = guessed.format().ok_or(PixelError::UnsupportedFormat)?;
    if !is_supported_format(format, encoded_image) {
        return Err(PixelError::UnsupportedFormat);
    }

    let (width, height) =
        ImageReader::with_format(Cursor::new(encoded_image), format).into_dimensions()?;
    let pixels = u64::from(width) * u64::from(height);
    if pixels > MAX_INPUT_PIXELS {
        return Err(PixelError::InputTooLarge {
            width,
            height,
            pixels,
            maximum: MAX_INPUT_PIXELS,
        });
    }

    let mut reader = ImageReader::with_format(Cursor::new(encoded_image), format);
    let mut limits = Limits::default();
    limits.max_image_width = Some(width);
    limits.max_image_height = Some(height);
    limits.max_alloc = Some(pixels.saturating_mul(MAX_BYTES_PER_DECODED_PIXEL));
    reader.limits(limits);
    Ok(reader.decode()?.to_rgba8())
}

fn is_supported_format(format: ImageFormat, encoded_image: &[u8]) -> bool {
    match format {
        ImageFormat::Png | ImageFormat::Jpeg => true,
        ImageFormat::Pnm => encoded_image.starts_with(b"P3") || encoded_image.starts_with(b"P6"),
        _ => false,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_known_but_unsupported_formats() {
        let error = decode_source(b"GIF89a").expect_err("GIF must not be accepted");

        assert!(matches!(error, PixelError::UnsupportedFormat));
    }

    #[test]
    fn rejects_non_ppm_members_of_the_pnm_family() {
        let error = decode_source(b"P2\n1 1\n255\n0\n").expect_err("PGM must not be accepted");

        assert!(matches!(error, PixelError::UnsupportedFormat));
    }

    #[test]
    fn checks_pixel_count_before_decoding_the_raster() {
        let oversized_header = format!("P3\n{} 1\n255\n", MAX_INPUT_PIXELS + 1);
        let error = decode_source(oversized_header.as_bytes())
            .expect_err("oversized dimensions must fail before missing pixels are decoded");

        assert!(matches!(
            error,
            PixelError::InputTooLarge {
                width: 80_000_001,
                height: 1,
                pixels: 80_000_001,
                maximum: MAX_INPUT_PIXELS,
            }
        ));
    }
}
