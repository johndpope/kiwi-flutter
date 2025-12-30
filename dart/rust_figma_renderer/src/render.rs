//! Render tree and draw commands

use crate::api::DrawCommand;
use crate::nodes::FigmaNode;
use std::collections::HashMap;

/// Render tree built from node hierarchy
pub struct RenderTree {
    pub root_id: String,
    pub nodes: HashMap<String, RenderNode>,
}

/// Node in the render tree with computed bounds
pub struct RenderNode {
    pub id: String,
    pub absolute_x: f64,
    pub absolute_y: f64,
    pub width: f64,
    pub height: f64,
    pub opacity: f64,
    pub clip: bool,
    pub children: Vec<String>,
    pub draw_command: Option<DrawCommand>,
}

impl RenderTree {
    /// Build render tree from node map
    pub fn build(
        root_id: &str,
        nodes: &HashMap<String, FigmaNode>,
    ) -> Self {
        let mut render_nodes = HashMap::new();
        
        if let Some(root) = nodes.get(root_id) {
            build_render_node(root, nodes, 0.0, 0.0, 1.0, &mut render_nodes);
        }
        
        RenderTree {
            root_id: root_id.to_string(),
            nodes: render_nodes,
        }
    }
    
    /// Get draw commands in render order (back to front)
    pub fn get_draw_commands(&self) -> Vec<DrawCommand> {
        let mut commands = Vec::new();
        self.collect_commands(&self.root_id, &mut commands);
        commands
    }
    
    fn collect_commands(&self, node_id: &str, commands: &mut Vec<DrawCommand>) {
        if let Some(node) = self.nodes.get(node_id) {
            if let Some(cmd) = &node.draw_command {
                commands.push(cmd.clone());
            }
            
            for child_id in &node.children {
                self.collect_commands(child_id, commands);
            }
        }
    }
}

fn build_render_node(
    node: &FigmaNode,
    all_nodes: &HashMap<String, FigmaNode>,
    parent_x: f64,
    parent_y: f64,
    parent_opacity: f64,
    render_nodes: &mut HashMap<String, RenderNode>,
) {
    let absolute_x = parent_x + node.x;
    let absolute_y = parent_y + node.y;
    let opacity = parent_opacity * node.opacity;
    
    let render_node = RenderNode {
        id: node.id.clone(),
        absolute_x,
        absolute_y,
        width: node.width,
        height: node.height,
        opacity,
        clip: false, // TODO: Check clip property
        children: node.children.clone(),
        draw_command: node.to_draw_command(),
    };
    
    render_nodes.insert(node.id.clone(), render_node);
    
    // Build children
    for child_id in &node.children {
        if let Some(child) = all_nodes.get(child_id) {
            build_render_node(child, all_nodes, absolute_x, absolute_y, opacity, render_nodes);
        }
    }
}
