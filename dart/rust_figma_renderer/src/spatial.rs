//! Spatial index using R-tree for fast node intersection queries
//!
//! Enables efficient lookup of nodes within a rectangular region,
//! critical for tile-based rendering performance.

use rstar::{RTree, RTreeObject, AABB, PointDistance};
use crate::nodes::FigmaNode;
use std::collections::HashMap;

/// Node bounds stored in the R-tree
#[derive(Debug, Clone)]
pub struct NodeBounds {
    pub id: String,
    pub min_x: f64,
    pub min_y: f64,
    pub max_x: f64,
    pub max_y: f64,
}

impl NodeBounds {
    pub fn new(id: String, min_x: f64, min_y: f64, max_x: f64, max_y: f64) -> Self {
        Self { id, min_x, min_y, max_x, max_y }
    }

    pub fn from_node(node: &FigmaNode) -> Self {
        Self {
            id: node.id.clone(),
            min_x: node.x,
            min_y: node.y,
            max_x: node.x + node.width,
            max_y: node.y + node.height,
        }
    }

    /// Width of the bounds
    pub fn width(&self) -> f64 {
        self.max_x - self.min_x
    }

    /// Height of the bounds
    pub fn height(&self) -> f64 {
        self.max_y - self.min_y
    }

    /// Area of the bounds
    pub fn area(&self) -> f64 {
        self.width() * self.height()
    }

    /// Check if this bounds intersects another
    pub fn intersects(&self, other: &NodeBounds) -> bool {
        !(self.max_x < other.min_x
            || self.min_x > other.max_x
            || self.max_y < other.min_y
            || self.min_y > other.max_y)
    }

    /// Check if this bounds contains a point
    pub fn contains_point(&self, x: f64, y: f64) -> bool {
        x >= self.min_x && x <= self.max_x && y >= self.min_y && y <= self.max_y
    }
}

impl RTreeObject for NodeBounds {
    type Envelope = AABB<[f64; 2]>;

    fn envelope(&self) -> Self::Envelope {
        AABB::from_corners([self.min_x, self.min_y], [self.max_x, self.max_y])
    }
}

impl PointDistance for NodeBounds {
    fn distance_2(&self, point: &[f64; 2]) -> f64 {
        let dx = if point[0] < self.min_x {
            self.min_x - point[0]
        } else if point[0] > self.max_x {
            point[0] - self.max_x
        } else {
            0.0
        };

        let dy = if point[1] < self.min_y {
            self.min_y - point[1]
        } else if point[1] > self.max_y {
            point[1] - self.max_y
        } else {
            0.0
        };

        dx * dx + dy * dy
    }

    fn contains_point(&self, point: &[f64; 2]) -> bool {
        self.contains_point(point[0], point[1])
    }
}

/// Spatial index wrapping an R-tree for fast intersection queries
pub struct SpatialIndex {
    tree: RTree<NodeBounds>,
    /// Map from node ID to bounds for quick lookup
    bounds_map: HashMap<String, NodeBounds>,
}

impl SpatialIndex {
    /// Create an empty spatial index
    pub fn new() -> Self {
        Self {
            tree: RTree::new(),
            bounds_map: HashMap::new(),
        }
    }

    /// Build spatial index from a node map
    pub fn build(nodes: &HashMap<String, FigmaNode>) -> Self {
        let bounds: Vec<NodeBounds> = nodes
            .values()
            .filter(|n| n.width > 0.0 && n.height > 0.0)
            .map(NodeBounds::from_node)
            .collect();

        let bounds_map: HashMap<String, NodeBounds> = bounds
            .iter()
            .map(|b| (b.id.clone(), b.clone()))
            .collect();

        Self {
            tree: RTree::bulk_load(bounds),
            bounds_map,
        }
    }

    /// Build spatial index with absolute coordinates from render tree
    pub fn build_with_absolute_coords(
        nodes: &HashMap<String, FigmaNode>,
        root_id: &str,
    ) -> Self {
        let mut bounds_list = Vec::new();
        let mut bounds_map = HashMap::new();

        // Traverse tree to compute absolute coordinates
        if let Some(root) = nodes.get(root_id) {
            Self::collect_bounds_recursive(
                root,
                nodes,
                0.0,
                0.0,
                &mut bounds_list,
                &mut bounds_map,
            );
        }

        Self {
            tree: RTree::bulk_load(bounds_list),
            bounds_map,
        }
    }

    fn collect_bounds_recursive(
        node: &FigmaNode,
        all_nodes: &HashMap<String, FigmaNode>,
        parent_x: f64,
        parent_y: f64,
        bounds_list: &mut Vec<NodeBounds>,
        bounds_map: &mut HashMap<String, NodeBounds>,
    ) {
        let abs_x = parent_x + node.x;
        let abs_y = parent_y + node.y;

        if node.width > 0.0 && node.height > 0.0 {
            let bounds = NodeBounds::new(
                node.id.clone(),
                abs_x,
                abs_y,
                abs_x + node.width,
                abs_y + node.height,
            );
            bounds_list.push(bounds.clone());
            bounds_map.insert(node.id.clone(), bounds);
        }

        // Process children
        for child_id in &node.children {
            if let Some(child) = all_nodes.get(child_id) {
                Self::collect_bounds_recursive(
                    child,
                    all_nodes,
                    abs_x,
                    abs_y,
                    bounds_list,
                    bounds_map,
                );
            }
        }
    }

    /// Query all nodes intersecting a rectangular region
    pub fn query_rect(&self, min_x: f64, min_y: f64, max_x: f64, max_y: f64) -> Vec<String> {
        let envelope = AABB::from_corners([min_x, min_y], [max_x, max_y]);

        self.tree
            .locate_in_envelope_intersecting(&envelope)
            .map(|nb| nb.id.clone())
            .collect()
    }

    /// Query nodes at a specific point
    pub fn query_point(&self, x: f64, y: f64) -> Vec<String> {
        self.tree
            .locate_all_at_point(&[x, y])
            .map(|nb| nb.id.clone())
            .collect()
    }

    /// Get bounds for a specific node
    pub fn get_node_bounds(&self, id: &str) -> Option<&NodeBounds> {
        self.bounds_map.get(id)
    }

    /// Get the total number of indexed nodes
    pub fn len(&self) -> usize {
        self.tree.size()
    }

    /// Check if the index is empty
    pub fn is_empty(&self) -> bool {
        self.tree.size() == 0
    }

    /// Get the bounding box of all indexed nodes
    pub fn overall_bounds(&self) -> Option<NodeBounds> {
        if self.is_empty() {
            return None;
        }

        let mut min_x = f64::MAX;
        let mut min_y = f64::MAX;
        let mut max_x = f64::MIN;
        let mut max_y = f64::MIN;

        for bounds in self.bounds_map.values() {
            min_x = min_x.min(bounds.min_x);
            min_y = min_y.min(bounds.min_y);
            max_x = max_x.max(bounds.max_x);
            max_y = max_y.max(bounds.max_y);
        }

        Some(NodeBounds::new(String::new(), min_x, min_y, max_x, max_y))
    }

    /// Iterator over all node bounds
    pub fn iter(&self) -> impl Iterator<Item = &NodeBounds> {
        self.tree.iter()
    }
}

impl Default for SpatialIndex {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn create_test_bounds(id: &str, x: f64, y: f64, w: f64, h: f64) -> NodeBounds {
        NodeBounds::new(id.to_string(), x, y, x + w, y + h)
    }

    #[test]
    fn test_node_bounds_intersects() {
        let a = create_test_bounds("a", 0.0, 0.0, 100.0, 100.0);
        let b = create_test_bounds("b", 50.0, 50.0, 100.0, 100.0);
        let c = create_test_bounds("c", 200.0, 200.0, 50.0, 50.0);

        assert!(a.intersects(&b));
        assert!(b.intersects(&a));
        assert!(!a.intersects(&c));
        assert!(!c.intersects(&a));
    }

    #[test]
    fn test_spatial_index_query() {
        let bounds = vec![
            create_test_bounds("a", 0.0, 0.0, 100.0, 100.0),
            create_test_bounds("b", 50.0, 50.0, 100.0, 100.0),
            create_test_bounds("c", 200.0, 200.0, 50.0, 50.0),
            create_test_bounds("d", 500.0, 500.0, 100.0, 100.0),
        ];

        let tree = RTree::bulk_load(bounds.clone());
        let bounds_map: HashMap<String, NodeBounds> = bounds
            .into_iter()
            .map(|b| (b.id.clone(), b))
            .collect();

        let index = SpatialIndex { tree, bounds_map };

        // Query overlapping a and b
        let result = index.query_rect(25.0, 25.0, 75.0, 75.0);
        assert!(result.contains(&"a".to_string()));
        assert!(result.contains(&"b".to_string()));
        assert!(!result.contains(&"c".to_string()));
        assert!(!result.contains(&"d".to_string()));

        // Query only c
        let result = index.query_rect(200.0, 200.0, 250.0, 250.0);
        assert!(result.contains(&"c".to_string()));
        assert_eq!(result.len(), 1);

        // Query empty region
        let result = index.query_rect(300.0, 300.0, 400.0, 400.0);
        assert!(result.is_empty());
    }

    #[test]
    fn test_spatial_index_point_query() {
        let bounds = vec![
            create_test_bounds("a", 0.0, 0.0, 100.0, 100.0),
            create_test_bounds("b", 50.0, 50.0, 100.0, 100.0),
        ];

        let tree = RTree::bulk_load(bounds.clone());
        let bounds_map: HashMap<String, NodeBounds> = bounds
            .into_iter()
            .map(|b| (b.id.clone(), b))
            .collect();

        let index = SpatialIndex { tree, bounds_map };

        // Point in both a and b
        let result = index.query_point(75.0, 75.0);
        assert_eq!(result.len(), 2);

        // Point only in a
        let result = index.query_point(25.0, 25.0);
        assert!(result.contains(&"a".to_string()));
        assert!(!result.contains(&"b".to_string()));

        // Point outside all
        let result = index.query_point(200.0, 200.0);
        assert!(result.is_empty());
    }

    #[test]
    fn test_overall_bounds() {
        let bounds = vec![
            create_test_bounds("a", 10.0, 20.0, 100.0, 100.0),
            create_test_bounds("b", 50.0, 50.0, 200.0, 150.0),
        ];

        let tree = RTree::bulk_load(bounds.clone());
        let bounds_map: HashMap<String, NodeBounds> = bounds
            .into_iter()
            .map(|b| (b.id.clone(), b))
            .collect();

        let index = SpatialIndex { tree, bounds_map };
        let overall = index.overall_bounds().unwrap();

        assert_eq!(overall.min_x, 10.0);
        assert_eq!(overall.min_y, 20.0);
        assert_eq!(overall.max_x, 250.0); // 50 + 200
        assert_eq!(overall.max_y, 200.0); // 50 + 150
    }
}
