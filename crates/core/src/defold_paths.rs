use std::{
    collections::{HashMap, HashSet},
    fs::{self},
    path::{Path, PathBuf},
};

use anyhow::{Context, Result};
use serde::Serialize;
use walkdir::{DirEntry, WalkDir};

use crate::{
    miniproto::{self, Message, Value},
    path,
};

#[derive(Debug)]
struct Collection {
    name: String,
    game_objects: Vec<GameObjectRef>,
}

#[derive(Debug)]
struct GameObjectRef {
    id: String,
    prototype_path: Option<String>,
    data: Option<String>,
}

#[derive(Debug)]
struct Component {
    id: String,
    path: Option<String>,
}

type CollectionsMap = HashMap<String, Collection>;
type GameObjectsMap = HashMap<String, Vec<Component>>;

#[derive(Debug, Serialize, Hash, PartialEq, Eq)]
pub struct PathEntry {
    #[serde(skip_serializing_if = "Option::is_none")]
    collection_name: Option<String>,

    #[serde(skip_serializing_if = "Option::is_none")]
    game_object_id: Option<String>,

    #[serde(skip_serializing_if = "Option::is_none")]
    component_id: Option<String>,

    #[serde(skip_serializing_if = "Option::is_none")]
    from_location: Option<String>,

    is_component: bool,
    same_game_object: bool,
}

fn load_data(root_dir: &PathBuf) -> (CollectionsMap, GameObjectsMap) {
    let mut collections: CollectionsMap = HashMap::new();
    let mut game_objects: GameObjectsMap = HashMap::new();

    let files = WalkDir::new(root_dir)
        .into_iter()
        .filter_entry(|e| !path::is_hidden(e))
        .filter_map(Result::ok)
        .map(DirEntry::into_path)
        .filter(|p| p.is_file());

    for file in files {
        let ext = file.extension().and_then(|s| s.to_str());

        if !matches!(ext, Some("collection" | "go")) {
            continue;
        }

        let message = match fs::read_to_string(&file)
            .map_err(anyhow::Error::from)
            .and_then(|src| miniproto::parse(&src))
        {
            Ok(message) => message,
            Err(err) => {
                tracing::error!("could not parse file {}: {err:?}", file.display());
                continue;
            }
        };

        let Ok(rel) = file.strip_prefix(root_dir) else {
            continue;
        };

        let rel = rel.to_string_lossy().to_string();

        match ext {
            Some("collection") => {
                let Some(collection) = parse_collection(&message) else {
                    tracing::debug!("couldn't parse collection {}", file.display());
                    continue;
                };

                collections.insert(rel, collection);
            }
            Some("go") => {
                game_objects.insert(rel, parse_game_object(&message));
            }
            _ => {}
        }
    }

    (collections, game_objects)
}

fn parse_collection(message: &Message) -> Option<Collection> {
    let Some(Value::String(name)) = message.get("name").first().cloned() else {
        return None;
    };

    let mut game_objects = Vec::new();

    for key in ["instances", "embedded_instances"] {
        for go in message.get(key).iter().filter_map(|v| match v {
            Value::Message(msg) => Some(msg),
            _ => None,
        }) {
            let Some(id) = go.first_string("id") else {
                // skip game objects without ids, invalid ids
                continue;
            };

            game_objects.push(GameObjectRef {
                id,
                prototype_path: go.first_string("prototype").and_then(strip_prefix_slash),
                data: go.first_string("data"),
            });
        }
    }

    Some(Collection { name, game_objects })
}

fn parse_game_object(message: &Message) -> Vec<Component> {
    let mut components: Vec<Component> = Vec::new();

    for key in ["components", "embedded_components"] {
        for component in message.get(key).iter().filter_map(|v| match v {
            Value::Message(component) => Some(component),
            _ => None,
        }) {
            let Some(id) = component.first_string("id") else {
                // skip components without id
                continue;
            };

            components.push(Component {
                id,
                path: component
                    .first_string("component")
                    .and_then(strip_prefix_slash),
            });
        }
    }

    components
}

fn references_path(components: &[Component], path: &str) -> bool {
    components.iter().any(|c| c.path.as_deref() == Some(path))
}

fn push_components(
    entries: &mut HashSet<PathEntry>,
    components: &[Component],
    collection_name: Option<String>,
    game_object_id: Option<String>,
    from_location: &str,
    same_game_object: bool,
) {
    for comp in components {
        entries.insert(PathEntry {
            collection_name: if same_game_object {
                None
            } else {
                collection_name.clone()
            },
            game_object_id: if same_game_object {
                None
            } else {
                game_object_id.clone()
            },
            component_id: Some(comp.id.clone()),
            from_location: Some(format!("/{from_location}")),
            is_component: true,
            same_game_object,
        });
    }
}

pub fn fetch_paths_for(root_dir: &PathBuf, filepath: &Path) -> Result<Vec<PathEntry>> {
    let relpath = filepath
        .strip_prefix(root_dir)
        .with_context(|| format!("{} must be in {}", filepath.display(), root_dir.display()))?
        .to_string_lossy()
        .to_string();

    let (collections, game_objects) = load_data(root_dir);
    let has_multiple_collections = collections.len() > 1;
    let mut entries = HashSet::new();

    for (collection_path, collection) in &collections {
        let collection_name = has_multiple_collections.then(|| collection.name.clone());

        for go in &collection.game_objects {
            entries.insert(PathEntry {
                collection_name: collection_name.clone(),
                game_object_id: Some(go.id.clone()),
                component_id: None,
                from_location: Some(format!("/{collection_path}")),
                is_component: false,
                same_game_object: false,
            });

            // parse the component in the data field if available
            if let Some(data) = &go.data
                && let Ok(parsed) = miniproto::parse(data)
            {
                let components = parse_game_object(&parsed);

                if references_path(&components, &relpath) {
                    push_components(&mut entries, &components, None, None, collection_path, true);
                }

                for comp in components {
                    entries.insert(PathEntry {
                        collection_name: collection_name.clone(),
                        game_object_id: Some(go.id.clone()),
                        component_id: Some(comp.id.clone()),
                        from_location: Some(format!("/{collection_path}")),
                        is_component: true,
                        same_game_object: false,
                    });

                    if let Some(proto) = &comp.path
                        && let Some(comps) = game_objects.get(proto)
                    {
                        push_components(
                            &mut entries,
                            comps,
                            collection_name.clone(),
                            Some(go.id.clone()),
                            proto,
                            references_path(comps, &relpath),
                        );
                    }
                }
            }

            if let Some(proto) = &go.prototype_path
                && let Some(comps) = game_objects.get(proto)
            {
                push_components(
                    &mut entries,
                    comps,
                    collection_name.clone(),
                    Some(go.id.clone()),
                    proto,
                    references_path(comps, &relpath),
                );
            }
        }
    }

    let attached: Vec<_> = game_objects
        .iter()
        .filter(|(_, comps)| references_path(comps, &relpath))
        .collect();

    // if our script affects more than one game object don't infer local components
    if attached.len() > 1 {
        return Ok(entries.into_iter().collect());
    }

    for (go_path, components) in attached {
        for comp in components {
            entries.insert(PathEntry {
                collection_name: None,
                game_object_id: None,
                component_id: Some(comp.id.clone()),
                from_location: Some(format!("/{go_path}")),
                is_component: true,
                same_game_object: true,
            });
        }
    }

    Ok(entries.into_iter().collect())
}

fn strip_prefix_slash(s: String) -> Option<String> {
    s.strip_prefix("/").map(ToString::to_string)
}

#[cfg(test)]
mod tests {
    use super::*;

    const COMPONENTS: &str = r#"
components { id: "map_manager" component: "/map_manager.script" }
embedded_components { id: "tile_factory" type: "factory" }
components { component: "/missing_id.script" }
"#;

    #[test]
    fn parses_components_and_matches_only_referenced_paths() {
        let components = parse_game_object(&miniproto::parse(COMPONENTS).unwrap());

        assert_eq!(components.len(), 2);
        assert_eq!(components[0].id, "map_manager");
        assert_eq!(components[0].path.as_deref(), Some("map_manager.script"));
        assert_eq!(components[1].id, "tile_factory");
        assert_eq!(components[1].path, None);
        assert!(references_path(&components, "map_manager.script"));
        assert!(!references_path(&components, "other.script"));
    }

    #[test]
    fn parses_standalone_and_embedded_collection_objects() {
        let source = format!(
            r#"
name: "main"
instances {{ id: "standalone" prototype: "/map.go" }}
embedded_instances {{ id: "embedded" data: {} }}
instances {{ prototype: "/missing_id.go" }}
"#,
            serde_json::to_string(COMPONENTS).unwrap()
        );
        let collection = parse_collection(&miniproto::parse(&source).unwrap()).unwrap();

        assert_eq!(collection.name, "main");
        assert_eq!(collection.game_objects.len(), 2);

        let standalone = &collection.game_objects[0];
        assert_eq!(standalone.id, "standalone");
        assert_eq!(standalone.prototype_path.as_deref(), Some("map.go"));
        assert_eq!(standalone.data, None);

        let embedded = &collection.game_objects[1];
        assert_eq!(embedded.id, "embedded");
        assert_eq!(embedded.prototype_path, None);
        assert_eq!(embedded.data.as_deref(), Some(COMPONENTS));
        assert!(
            parse_collection(&miniproto::parse("instances { id: \"map\" }").unwrap()).is_none()
        );
    }

    #[test]
    fn local_components_omit_scope_while_qualified_components_preserve_it() {
        let components = parse_game_object(&miniproto::parse(COMPONENTS).unwrap());

        for same_game_object in [true, false] {
            let mut entries = HashSet::new();

            push_components(
                &mut entries,
                &components,
                Some("main".to_string()),
                Some("map".to_string()),
                "main.collection",
                same_game_object,
            );

            for id in ["map_manager", "tile_factory"] {
                assert!(entries.contains(&PathEntry {
                    collection_name: (!same_game_object).then(|| "main".to_string()),
                    game_object_id: (!same_game_object).then(|| "map".to_string()),
                    component_id: Some(id.to_string()),
                    from_location: Some("/main.collection".to_string()),
                    is_component: true,
                    same_game_object,
                }));
            }
        }
    }
}
