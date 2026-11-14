use super::Subject;

/// Identifiers available for a window, depending on subject and platform
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Window {
    pub subject: Subject,

    pub class: Option<String>,
    pub title: Option<String>,

    /// Application name, macOS only
    pub app: Option<String>,
}

impl Window {
    /// `None` for unknown placeholders, `Some(None)` if this window lacks the value
    fn var(&self, name: &str) -> Option<&Option<String>> {
        match name {
            "CLASS" => Some(&self.class),
            "TITLE" => Some(&self.title),
            "APP" => Some(&self.app),
            _ => None,
        }
    }
}

/// Replaces placeholders like `{TITLE}`, unknown placeholders are kept as is
pub fn render(args: &[impl AsRef<str>], window: &Window) -> Result<Vec<String>, String> {
    args.iter()
        .map(|arg| {
            let mut out = String::new();
            let mut rest = arg.as_ref();

            while let Some(start) = rest.find('{') {
                out.push_str(&rest[..start]);

                let after = &rest[start + 1..];
                let len = after
                    .find(|c: char| !c.is_ascii_uppercase())
                    .unwrap_or(after.len());
                let name = &after[..len];

                match window.var(name) {
                    Some(value) if after[len..].starts_with('}') => {
                        out.push_str(value.as_deref().ok_or_else(|| name.to_string())?);
                        rest = &after[len + 1..];
                    }
                    _ => {
                        out.push('{');
                        rest = after;
                    }
                }
            }

            out.push_str(rest);
            Ok(out)
        })
        .collect()
}

#[cfg(test)]
pub mod test_windows {
    use super::Window;
    use crate::focus::Subject;
    pub fn neovim() -> Window {
        Window {
            subject: Subject::Neovim,
            class: Some("com.defold.nvim.p1".into()),
            title: None,
            app: None,
        }
    }

    pub fn game() -> Window {
        Window {
            subject: Subject::Game,
            class: None,
            title: Some("My Game".into()),
            app: None,
        }
    }

    pub fn titled(title: &str) -> Window {
        Window {
            title: Some(title.into()),
            ..game()
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::focus::window::test_windows::*;

    #[test]
    fn renders_placeholders() {
        let args = [
            "{TARGET}",
            "x{CLASS}y",
            "{UNKNOWN} {} { {TITLE",
            "{{CLASS}}",
        ];

        assert_eq!(
            render(&args, &neovim()).unwrap(),
            [
                "{TARGET}",
                "xcom.defold.nvim.p1y",
                "{UNKNOWN} {} { {TITLE",
                "{com.defold.nvim.p1}"
            ]
        );

        assert_eq!(render(&["{TITLE}"], &neovim()), Err("TITLE".to_string()));
        assert_eq!(render(&["{APP}"], &game()), Err("APP".to_string()));
    }

    #[test]
    fn does_not_expand_placeholders_in_inserted_values() {
        assert_eq!(
            render(&["{TITLE}"], &titled("{CLASS}")).unwrap(),
            ["{CLASS}"]
        );
    }
}
