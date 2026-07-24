use std::io::Cursor;

use image::{DynamicImage, ImageFormat, Rgba, RgbaImage};
use pixel_core::DitherMode;
use pixel_sprite::{
    AnimationSpec, Cell, GenerationSpec, GridSpec, Offset, PartSpec, Point, RenderSpec,
    ResizeAnchor, Size, SpriteBuilder, SpriteManifest,
};

#[test]
fn transparent_parts_are_pixelized_composed_and_packed_into_eight_frames() {
    let source = fixture_parts_sheet();
    let manifest = fixture_manifest();

    let first = SpriteBuilder::new(&source)
        .expect("fixture should decode")
        .build(&manifest)
        .expect("sprite should build");
    let second = SpriteBuilder::new(&source)
        .expect("fixture should decode")
        .build(&manifest)
        .expect("sprite should build deterministically");

    assert_eq!(first.logical_sheet_png, second.logical_sheet_png);
    assert_eq!(first.scaled_sheet_png, second.scaled_sheet_png);
    assert_eq!(first.recipe_json, second.recipe_json);
    assert_eq!((first.frame_width, first.frame_height), (8, 8));
    assert_eq!((first.frame_count, first.fps), (8, 8));

    let logical = image::load_from_memory(&first.logical_sheet_png)
        .expect("logical sheet should decode")
        .to_rgba8();
    assert_eq!(logical.dimensions(), (64, 8));
    assert!(
        (0..8).any(|y| (0..8).any(|x| logical.get_pixel(x, y)[3] > 0)),
        "first frame should contain composed parts"
    );
    for y in 0..7 {
        for x in 0..8 {
            assert_eq!(
                logical.get_pixel(x, y),
                logical.get_pixel(x + 2 * 8, y + 1),
                "frame 3 should move every visible part down one pixel"
            );
        }
    }
    assert!((0..8).all(|x| logical.get_pixel(x + 2 * 8, 0)[3] == 0));

    let scaled = image::load_from_memory(&first.scaled_sheet_png)
        .expect("scaled sheet should decode")
        .to_rgba8();
    assert_eq!(scaled.dimensions(), (128, 16));
    assert_eq!(first.parts.len(), 2);

    let metadata: serde_json::Value =
        serde_json::from_str(&first.metadata_json).expect("metadata should decode");
    assert_eq!(metadata["frameWidth"], 8);
    assert_eq!(metadata["frameHeight"], 8);
    assert_eq!(metadata["frameCount"], 8);
    assert_eq!(metadata["fps"], 8);
}

#[test]
fn source_without_transparency_is_rejected_before_composition() {
    let opaque = RgbaImage::from_pixel(30, 30, Rgba([0, 255, 0, 255]));
    let source = encode_png(&opaque);

    let error = SpriteBuilder::new(&source)
        .expect("fixture should decode")
        .build(&fixture_manifest())
        .expect_err("opaque source must be rejected");

    assert!(error.to_string().contains("transparent"));
}

fn fixture_manifest() -> SpriteManifest {
    SpriteManifest {
        schema_version: 1,
        id: "contract-monster".into(),
        generation: GenerationSpec {
            description: "a test monster".into(),
            style: "flat game character pieces".into(),
            view: "front".into(),
            palette: "red and blue".into(),
            chroma_key: "#00FF00".into(),
            avoid: vec![],
        },
        grid: GridSpec {
            columns: 3,
            rows: 3,
            logical_cell_width: 4,
            logical_cell_height: 4,
        },
        canvas: Size {
            width: 8,
            height: 8,
        },
        render: RenderSpec {
            color_count: 2,
            dither: DitherMode::None,
            preview_scale: 2,
        },
        animation: AnimationSpec {
            name: "idle".into(),
            frames: 8,
            fps: 8,
        },
        parts: vec![
            PartSpec {
                id: "body".into(),
                cell: Cell { column: 0, row: 0 },
                anchor: Point { x: 2, y: 2 },
                position: Point { x: 4, y: 4 },
                z_index: 10,
                offsets: vec![
                    Offset::default(),
                    Offset::default(),
                    Offset { x: 0, y: 1 },
                    Offset { x: 0, y: 1 },
                    Offset { x: 0, y: 1 },
                    Offset { x: 0, y: 1 },
                    Offset::default(),
                    Offset::default(),
                ],
                size_deltas: vec![],
                z_index_deltas: vec![],
                resize_anchor: ResizeAnchor::Center,
            },
            PartSpec {
                id: "head".into(),
                cell: Cell { column: 1, row: 0 },
                anchor: Point { x: 2, y: 2 },
                position: Point { x: 4, y: 2 },
                z_index: 20,
                offsets: vec![
                    Offset::default(),
                    Offset::default(),
                    Offset { x: 0, y: 1 },
                    Offset { x: 0, y: 1 },
                    Offset { x: 0, y: 2 },
                    Offset { x: 0, y: 2 },
                    Offset { x: 0, y: 1 },
                    Offset::default(),
                ],
                size_deltas: vec![],
                z_index_deltas: vec![],
                resize_anchor: ResizeAnchor::Center,
            },
        ],
    }
}

fn fixture_parts_sheet() -> Vec<u8> {
    let mut image = RgbaImage::new(30, 30);
    for y in 2..8 {
        for x in 2..8 {
            image.put_pixel(x, y, Rgba([255, 0, 0, 255]));
        }
    }
    for y in 2..8 {
        for x in 12..18 {
            image.put_pixel(x, y, Rgba([0, 0, 255, 255]));
        }
    }
    encode_png(&image)
}

fn encode_png(image: &RgbaImage) -> Vec<u8> {
    let mut cursor = Cursor::new(Vec::new());
    DynamicImage::ImageRgba8(image.clone())
        .write_to(&mut cursor, ImageFormat::Png)
        .expect("fixture should encode");
    cursor.into_inner()
}
