//! Layout calculations (auto-layout, constraints)

#[derive(Debug, Clone, Copy, Default)]
pub enum LayoutMode {
    #[default]
    None,
    Horizontal,
    Vertical,
}

#[derive(Debug, Clone, Copy, Default)]
pub enum SizingMode {
    #[default]
    Fixed,
    Hug,
    Fill,
}

#[derive(Debug, Clone, Copy, Default)]
pub enum LayoutAlign {
    #[default]
    Min,
    Center,
    Max,
    Stretch,
}

/// Auto-layout frame properties
#[derive(Debug, Clone, Default)]
pub struct AutoLayout {
    pub mode: LayoutMode,
    pub primary_axis_sizing: SizingMode,
    pub counter_axis_sizing: SizingMode,
    pub primary_axis_align: LayoutAlign,
    pub counter_axis_align: LayoutAlign,
    pub padding: [f64; 4], // [left, top, right, bottom]
    pub item_spacing: f64,
}

/// Calculate layout for a frame and its children
pub fn calculate_auto_layout(
    frame_width: f64,
    frame_height: f64,
    layout: &AutoLayout,
    children: &[(f64, f64)], // (width, height) of each child
) -> Vec<(f64, f64, f64, f64)> { // (x, y, width, height) for each child
    let mut results = Vec::with_capacity(children.len());
    
    match layout.mode {
        LayoutMode::None => {
            // No auto-layout, return original positions
            for (w, h) in children {
                results.push((0.0, 0.0, *w, *h));
            }
        }
        LayoutMode::Horizontal => {
            let mut x = layout.padding[0];
            let y = layout.padding[1];
            let available_height = frame_height - layout.padding[1] - layout.padding[3];
            
            for (w, h) in children {
                let child_y = match layout.counter_axis_align {
                    LayoutAlign::Min => y,
                    LayoutAlign::Center => y + (available_height - h) / 2.0,
                    LayoutAlign::Max => y + available_height - h,
                    LayoutAlign::Stretch => y,
                };
                let child_h = if matches!(layout.counter_axis_align, LayoutAlign::Stretch) {
                    available_height
                } else {
                    *h
                };
                
                results.push((x, child_y, *w, child_h));
                x += w + layout.item_spacing;
            }
        }
        LayoutMode::Vertical => {
            let x = layout.padding[0];
            let mut y = layout.padding[1];
            let available_width = frame_width - layout.padding[0] - layout.padding[2];
            
            for (w, h) in children {
                let child_x = match layout.counter_axis_align {
                    LayoutAlign::Min => x,
                    LayoutAlign::Center => x + (available_width - w) / 2.0,
                    LayoutAlign::Max => x + available_width - w,
                    LayoutAlign::Stretch => x,
                };
                let child_w = if matches!(layout.counter_axis_align, LayoutAlign::Stretch) {
                    available_width
                } else {
                    *w
                };
                
                results.push((child_x, y, child_w, *h));
                y += h + layout.item_spacing;
            }
        }
    }
    
    results
}
