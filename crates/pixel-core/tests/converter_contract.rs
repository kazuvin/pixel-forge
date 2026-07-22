use pixel_core::{
    ColorMode, CropRect, CropRegion, OutlineSettings, Palette, PaletteApplication, PixelSession,
    RENDER_RECIPE_SCHEMA_VERSION, RenderRecipe, RenderSettings, RgbColor,
};

#[test]
fn public_converter_api_covers_crop_palette_output_and_recipe() {
    let ppm = b"P3\n4 2\n255\n250 20 20  230 40 30  20 30 240  30 40 220\n250 20 20  230 40 30  20 30 240  30 40 220\n";
    let session = PixelSession::new(ppm).expect("fixture should decode");
    assert_eq!(session.source_dimensions(), (4, 2));
    let settings = RenderSettings {
        long_side: 4,
        upscale: 3,
        crop: CropRegion::Rectangle {
            rect: CropRect {
                x: 1,
                y: 0,
                width: 2,
                height: 2,
            },
        },
        color_mode: ColorMode::Palette {
            palette: Palette {
                name: "red-blue".into(),
                colors: vec![RgbColor::new(255, 0, 0), RgbColor::new(0, 0, 255)],
            },
            application: PaletteApplication::Exact,
        },
        outline: OutlineSettings::default(),
    };

    let result = session
        .convert(settings.clone())
        .expect("conversion should succeed");
    let recipe: RenderRecipe =
        serde_json::from_str(&result.recipe_json).expect("recipe should decode");

    assert_eq!((result.logical_width, result.logical_height), (4, 4));
    assert_eq!((result.width, result.height), (12, 12));
    assert_eq!(result.palette, ["#FF0000", "#0000FF"]);
    assert_eq!(recipe.schema_version, RENDER_RECIPE_SCHEMA_VERSION);
    assert_eq!(recipe.settings, settings);
    assert_eq!((recipe.logical_width, recipe.logical_height), (4, 4));
}
