//! Vector path operations

use lyon::path::Path;
#[allow(unused_imports)]
use lyon::path::builder::*; // Provides PathBuilder trait methods
use lyon::math::point;

/// Parse SVG path commands into a lyon Path
pub fn parse_svg_path(commands: &str) -> Option<Path> {
    let mut builder = Path::builder();
    let mut chars = commands.chars().peekable();
    
    while let Some(c) = chars.next() {
        match c {
            'M' | 'm' => {
                let (x, y) = parse_point(&mut chars)?;
                builder.begin(point(x, y));
            }
            'L' | 'l' => {
                let (x, y) = parse_point(&mut chars)?;
                builder.line_to(point(x, y));
            }
            'C' | 'c' => {
                let (x1, y1) = parse_point(&mut chars)?;
                let (x2, y2) = parse_point(&mut chars)?;
                let (x, y) = parse_point(&mut chars)?;
                builder.cubic_bezier_to(
                    point(x1, y1),
                    point(x2, y2),
                    point(x, y),
                );
            }
            'Q' | 'q' => {
                let (x1, y1) = parse_point(&mut chars)?;
                let (x, y) = parse_point(&mut chars)?;
                builder.quadratic_bezier_to(point(x1, y1), point(x, y));
            }
            'Z' | 'z' => {
                builder.close();
            }
            ' ' | ',' | '\n' | '\r' | '\t' => continue,
            _ => {}
        }
    }
    
    Some(builder.build())
}

fn parse_point(chars: &mut std::iter::Peekable<std::str::Chars>) -> Option<(f32, f32)> {
    skip_whitespace(chars);
    let x = parse_number(chars)?;
    skip_whitespace(chars);
    let y = parse_number(chars)?;
    Some((x, y))
}

fn parse_number(chars: &mut std::iter::Peekable<std::str::Chars>) -> Option<f32> {
    let mut s = String::new();
    
    // Handle negative sign
    if chars.peek() == Some(&'-') {
        s.push(chars.next()?);
    }
    
    // Parse digits and decimal
    while let Some(&c) = chars.peek() {
        if c.is_ascii_digit() || c == '.' {
            s.push(chars.next()?);
        } else {
            break;
        }
    }
    
    s.parse().ok()
}

fn skip_whitespace(chars: &mut std::iter::Peekable<std::str::Chars>) {
    while let Some(&c) = chars.peek() {
        if c == ' ' || c == ',' || c == '\n' || c == '\r' || c == '\t' {
            chars.next();
        } else {
            break;
        }
    }
}
