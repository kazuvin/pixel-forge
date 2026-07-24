use std::{path::PathBuf, process::Command};

use image::{Rgba, RgbaImage};

#[test]
fn sample_manifest_builds_complete_sprite_asset_directory() {
    let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../..");
    let manifest = root.join("examples/sprites/moss-golem/moss-golem.sprite.json");
    let temporary = tempfile::tempdir().expect("temporary directory should be created");
    let source = temporary.path().join("parts.png");
    let output = temporary.path().join("output");
    fixture_parts_sheet()
        .save(&source)
        .expect("parts fixture should be written");

    let result = Command::new(env!("CARGO_BIN_EXE_pixel-cli"))
        .arg("sprite")
        .arg("build")
        .arg(&manifest)
        .arg("--source")
        .arg(&source)
        .arg("--output")
        .arg(&output)
        .output()
        .expect("pixel-cli should start");

    assert!(
        result.status.success(),
        "pixel-cli failed:\nstdout:\n{}\nstderr:\n{}",
        String::from_utf8_lossy(&result.stdout),
        String::from_utf8_lossy(&result.stderr)
    );
    for path in [
        "idle.png",
        "idle@4x.png",
        "idle.json",
        "sprite.recipe.json",
        "parts/body.png",
        "parts/head.png",
        "parts/left-arm.png",
        "parts/right-arm.png",
        "parts/left-leg.png",
        "parts/right-leg.png",
        "parts/equipment.png",
    ] {
        assert!(output.join(path).is_file(), "missing output {path}");
    }
    let sheet = image::open(output.join("idle.png"))
        .expect("logical sheet should decode")
        .to_rgba8();
    assert_eq!(sheet.dimensions(), (512, 64));
}

fn fixture_parts_sheet() -> RgbaImage {
    let mut image = RgbaImage::new(300, 300);
    let cells = [
        (0, 0, Rgba([120, 80, 40, 255])),
        (1, 0, Rgba([180, 140, 80, 255])),
        (2, 0, Rgba([80, 120, 40, 255])),
        (0, 1, Rgba([70, 110, 35, 255])),
        (1, 1, Rgba([90, 70, 35, 255])),
        (2, 1, Rgba([100, 80, 40, 255])),
        (0, 2, Rgba([140, 90, 30, 255])),
    ];
    for (column, row, color) in cells {
        for y in row * 100 + 25..row * 100 + 75 {
            for x in column * 100 + 25..column * 100 + 75 {
                image.put_pixel(x, y, color);
            }
        }
    }
    image
}
