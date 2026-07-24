use std::fmt::Write;

use pixel_sprite::SpriteManifest;

pub(crate) fn render_imagegen_prompt(manifest: &SpriteManifest) -> String {
    let mut prompt = String::new();
    writeln!(prompt, "Use case: stylized-concept").expect("writing to String cannot fail");
    writeln!(
        prompt,
        "Asset type: separated game character rig parts sheet for deterministic sprite assembly"
    )
    .expect("writing to String cannot fail");
    writeln!(
        prompt,
        "Primary request: Create one square parts sheet for {}.",
        manifest.generation.description
    )
    .expect("writing to String cannot fail");
    writeln!(
        prompt,
        "Scene/backdrop: A perfectly flat solid {} chroma-key background across the entire canvas. No shadows, gradients, texture, floor plane, reflections, or lighting variation in the background.",
        manifest.generation.chroma_key
    )
    .expect("writing to String cannot fail");
    writeln!(prompt, "View: {}", manifest.generation.view).expect("writing to String cannot fail");
    writeln!(prompt, "Style/medium: {}", manifest.generation.style)
        .expect("writing to String cannot fail");
    writeln!(prompt, "Color palette: {}", manifest.generation.palette)
        .expect("writing to String cannot fail");
    writeln!(
        prompt,
        "Composition/framing: Square canvas divided conceptually into {} equal columns and {} equal rows. Do not draw the grid.",
        manifest.grid.columns, manifest.grid.rows
    )
    .expect("writing to String cannot fail");
    writeln!(prompt, "Place exactly these isolated pieces:")
        .expect("writing to String cannot fail");
    let mut parts = manifest.parts.iter().collect::<Vec<_>>();
    parts.sort_by_key(|part| (part.cell.row, part.cell.column));
    for part in parts {
        writeln!(
            prompt,
            "- row {}, column {}: {}",
            part.cell.row + 1,
            part.cell.column + 1,
            readable_id(&part.id)
        )
        .expect("writing to String cannot fail");
    }
    writeln!(
        prompt,
        "Keep every unlisted cell completely empty and filled only with the chroma-key color."
    )
    .expect("writing to String cannot fail");
    writeln!(
        prompt,
        "Part construction: Every piece belongs to the same character and must share identical scale, perspective, materials, lighting, outline treatment, and proportions. Center one complete piece in each specified cell with generous padding. Show clean connection ends at neck, shoulders, hips, hands, or equipment sockets. Character-left and character-right pieces must be separate. Do not overlap pieces or let a piece cross a cell boundary."
    )
    .expect("writing to String cannot fail");
    writeln!(
        prompt,
        "Output intent: Produce clean high-resolution source artwork. Pixel Forge will define the final pixel grid and palette later."
    )
    .expect("writing to String cannot fail");
    writeln!(
        prompt,
        "Constraints: No assembled full character. No animation frames. No labels, letters, numbers, captions, panel borders, guide marks, watermark, signature, cast shadow, contact shadow, or reflection. Do not use {} anywhere inside a character piece. Use only the specified cells and keep all silhouettes fully separated from the background.",
        manifest.generation.chroma_key
    )
    .expect("writing to String cannot fail");
    let mut avoid = vec![
        "fake pixel grid".to_owned(),
        "inconsistent part scale".to_owned(),
        "duplicate pieces".to_owned(),
        "cropped silhouettes".to_owned(),
        "extra props".to_owned(),
    ];
    avoid.extend(manifest.generation.avoid.iter().cloned());
    writeln!(prompt, "Avoid: {}", avoid.join("; ")).expect("writing to String cannot fail");
    prompt
}

fn readable_id(id: &str) -> String {
    id.replace(['-', '_'], " ")
}

#[cfg(test)]
mod tests {
    use pixel_core::DitherMode;
    use pixel_sprite::{
        AnimationSpec, Cell, GenerationSpec, GridSpec, Offset, PartSpec, Point, RenderSpec, Size,
        SpriteManifest,
    };

    use super::*;

    #[test]
    fn prompt_fixes_grid_cells_background_and_forbidden_content() {
        let manifest = SpriteManifest {
            schema_version: 1,
            id: "moss-golem".into(),
            generation: GenerationSpec {
                description: "a moss golem".into(),
                style: "chunky hand-painted fantasy concept art".into(),
                view: "front view".into(),
                palette: "moss green and sandstone".into(),
                chroma_key: "#FF00FF".into(),
                avoid: vec!["thin limbs".into()],
            },
            grid: GridSpec {
                columns: 3,
                rows: 3,
                logical_cell_width: 32,
                logical_cell_height: 32,
            },
            canvas: Size {
                width: 64,
                height: 64,
            },
            render: RenderSpec {
                color_count: 12,
                dither: DitherMode::None,
                preview_scale: 4,
            },
            animation: AnimationSpec {
                name: "idle".into(),
                frames: 8,
                fps: 8,
            },
            parts: vec![PartSpec {
                id: "left-arm".into(),
                cell: Cell { column: 2, row: 0 },
                anchor: Point { x: 16, y: 8 },
                position: Point { x: 20, y: 28 },
                z_index: 10,
                offsets: vec![Offset::default(); 8],
                size_deltas: vec![],
                z_index_deltas: vec![],
                resize_anchor: pixel_sprite::ResizeAnchor::Center,
            }],
        };

        let prompt = render_imagegen_prompt(&manifest);

        assert!(prompt.contains("row 1, column 3: left arm"));
        assert!(prompt.contains("#FF00FF"));
        assert!(prompt.contains("Do not draw the grid"));
        assert!(prompt.contains("No assembled full character"));
        assert!(prompt.contains("thin limbs"));
    }
}
