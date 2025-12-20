use anyhow::{Result, bail};
use serde::Deserialize;
use std::fmt::Write;

const LINE_WRAP: usize = 120;

#[derive(Debug, Deserialize, Clone)]
#[serde(untagged)]
enum Type {
    Single(String),
    Multiple(Vec<String>),
}

impl Type {
    pub fn type_name(&self) -> String {
        match self {
            Type::Single(s) => s.clone(),
            Type::Multiple(items) => format!("[{}]", items.join(", ")),
        }
    }

    pub fn is_single(&self, t: &str) -> bool {
        match self {
            Type::Single(s) => s == t,
            Type::Multiple(_) => false,
        }
    }
}

#[derive(Debug, Deserialize, Default)]
struct Value {
    pub name: Option<String>,
    pub desc: Option<String>,

    #[serde(rename = "type")]
    pub vtype: Option<Type>,

    pub members: Option<Vec<Value>>,
    pub examples: Option<Vec<Value>>,
    pub parameters: Option<Vec<Value>>,

    #[serde(rename = "return")]
    pub returnx: Option<Box<Value>>,

    pub returns: Option<Vec<Value>>,
}

const TYPE_TABLE: &str = "table";
const TYPE_FUNCTION: &str = "function";

impl Value {
    pub fn is_field(&self) -> bool {
        match &self.vtype {
            Some(Type::Single(s)) => {
                let s = s.as_str();
                !matches!(s, TYPE_FUNCTION | TYPE_TABLE)
            }
            Some(Type::Multiple(_)) => true,
            None => false,
        }
    }

    pub fn fully_qualified_name(&self, parents: &Vec<&Value>) -> Result<String> {
        let mut fqn = String::new();

        for p in parents {
            write!(fqn, "{}.", p.name.clone().expect("parent must have name"))?;
        }

        write!(fqn, "{}", self.name.clone().expect("must have name"))?;

        Ok(fqn)
    }

    pub fn param_name(&self) -> String {
        self.name
            .clone()
            .expect("called param_name on element without name")
            .trim_end_matches("[optional]")
            .to_string()
    }

    pub fn param_type(&self) -> String {
        format!(
            "{}{}",
            self.vtype
                .as_ref()
                .expect("called param_type on element without type")
                .type_name(),
            if self.is_optional() { "|nil" } else { "" }
        )
    }

    pub fn is_optional(&self) -> bool {
        self.name
            .clone()
            .expect("called param_name on element without name")
            .ends_with("[optional]")
    }
}

fn split_lines(input: &str, line_width: usize, first_line_cutoff: usize) -> Vec<String> {
    let mut result = Vec::new();

    let first_line_options = textwrap::Options::new(line_width - first_line_cutoff);
    let first_line_wrapped = textwrap::wrap(input, &first_line_options);

    if let Some(first) = first_line_wrapped.first() {
        result.push(first.to_string());
        let remaining_text = &input[first.len()..].trim_start();

        if !remaining_text.is_empty() {
            let rest_options = textwrap::Options::new(line_width);
            let rest_wrapped = textwrap::wrap(remaining_text, &rest_options);

            for line in rest_wrapped {
                result.push(line.into_owned());
            }
        }
    }

    result
}

fn compile_table(out: &mut String, table: &Value, parents: &Vec<&Value>) -> Result<()> {
    if let Some(vtype) = &table.vtype
        && !vtype.is_single(TYPE_TABLE)
    {
        bail!("compile_table can only be called with tables");
    }

    if let Some(desc) = &table.desc {
        writeln!(out, "---{desc}")?;
    }

    if let Some(vtype) = &table.vtype {
        writeln!(
            out,
            "---@class {} : {}",
            table.name.clone().expect("table must have name"),
            vtype.type_name(),
        )?;
    } else {
        writeln!(
            out,
            "---@class {}",
            table.name.clone().expect("table must have name"),
        )?;
    }

    if let Some(members) = &table.members {
        for m in members.iter().filter(|m| m.is_field()) {
            compile_field(out, m)?;
        }
    }

    if parents.is_empty() {
        writeln!(
            out,
            "local {} = {{}}",
            table.name.clone().expect("table must have name")
        )?;
    } else {
        writeln!(out, "{} = {{}}", table.fully_qualified_name(&parents)?)?;
    }

    if let Some(members) = &table.members {
        for m in members {
            let Some(vtype) = &m.vtype else {
                continue;
            };

            if vtype.is_single(TYPE_TABLE) {
                writeln!(out)?;
                compile_table(out, m, &{
                    let mut tmp = parents.clone();
                    tmp.extend_from_slice(&[table]);
                    tmp
                })?;
            } else if vtype.is_single(TYPE_FUNCTION) {
                writeln!(out)?;
                compile_function(out, m, &{
                    let mut tmp = parents.clone();
                    tmp.extend_from_slice(&[table]);
                    tmp
                })?;
            }

            // we already handled others
        }
    }

    if parents.is_empty() {
        writeln!(out)?;
        writeln!(
            out,
            "return {}",
            table.name.clone().expect("table must have name")
        )?;
    }

    Ok(())
}

fn compile_field(out: &mut String, field: &Value) -> Result<()> {
    assert!(field.is_field());

    let prefix = format!(
        "---@field public {} {} ",
        field.name.clone().expect("field must have name"),
        field
            .vtype
            .as_ref()
            .expect("field must have type")
            .type_name(),
    );

    if let Some(desc) = &field.desc {
        let lines = split_lines(desc, LINE_WRAP - 3, prefix.len());

        write!(out, "{prefix}")?;

        if let Some(first) = lines.first() {
            writeln!(out, "{first}")?;
        }

        for line in lines.iter().skip(1) {
            writeln!(out, "---{line}")?;
        }
    } else {
        writeln!(out, "{prefix}")?;
    }

    Ok(())
}

fn compile_function(out: &mut String, function: &Value, parents: &Vec<&Value>) -> Result<()> {
    if let Some(desc) = &function.desc {
        let lines = split_lines(desc, LINE_WRAP - 3, 0);

        for line in lines {
            write!(out, "---")?;

            if line.starts_with('-') {
                write!(out, " ")?;
            }

            writeln!(out, "{line}")?;
        }
    }

    if let Some(examples) = &function.examples {
        writeln!(out, "---")?;
        writeln!(out, "---    Examples:")?;
        writeln!(out, "---")?;

        let prefix = "---        ";

        for example in examples {
            if example.desc.is_none() {
                continue;
            }

            let desc = example.desc.clone().unwrap();

            let lines = split_lines(&desc, LINE_WRAP, prefix.len());

            for line in lines {
                writeln!(out, "{prefix}{line}")?;
            }
        }

        writeln!(out, "---")?;
    }

    if let Some(params) = &function.parameters {
        for param in params {
            compile_parameter(out, param)?;
        }
    }

    if let Some(returnx) = &function.returnx {
        compile_return(out, returnx)?;
    }

    if let Some(returns) = &function.returns {
        for ret in returns {
            compile_return(out, ret)?;
        }
    }

    let params = if let Some(params) = &function.parameters {
        params
            .iter()
            .map(Value::param_name)
            .collect::<Vec<String>>()
            .join(", ")
    } else {
        String::new()
    };

    if !parents.is_empty() {
        writeln!(
            out,
            "function {}({params}) end",
            function.fully_qualified_name(&parents)?,
        )?;
    } else {
        writeln!(
            out,
            "function {}({params}) end",
            function.name.clone().unwrap()
        )?;
    }

    Ok(())
}

fn compile_return(out: &mut String, ret: &Value) -> Result<()> {
    let prefix = format!(
        "---@return {}",
        ret.vtype
            .clone()
            .expect("return must have type")
            .type_name()
    );

    if let Some(desc) = &ret.desc {
        let lines = split_lines(desc, LINE_WRAP, prefix.len() + 1);
        write!(out, "{prefix} ")?;

        if let Some(first) = lines.first() {
            writeln!(out, "{first}")?;
        }

        for line in lines.iter().skip(1) {
            if line.starts_with('-') {
                writeln!(out, "--- {line}")?;
                continue;
            }
            writeln!(out, "---{line}")?;
        }
    }

    Ok(())
}

fn compile_parameter(out: &mut String, param: &Value) -> Result<()> {
    let mut prefix = format!("---@param {} ", param.param_name());

    if let Some(vtype) = &param.vtype
        && vtype.is_single(TYPE_FUNCTION)
    {
        write!(
            out,
            "{prefix}fun({})",
            if let Some(params) = &param.parameters {
                params
                    .iter()
                    .map(|p| format!("{}: {}", p.param_name(), p.param_type()))
                    .collect::<Vec<String>>()
                    .join(", ")
            } else {
                String::new()
            }
        )?;

        if let Some(returnx) = &param.returnx {
            write!(
                out,
                ": {}",
                returnx
                    .vtype
                    .clone()
                    .expect("return must have type")
                    .type_name()
            )?;
        }

        if let Some(returns) = &param.returns {
            write!(
                out,
                ": {}",
                returns
                    .iter()
                    .filter_map(|r| r.vtype.clone())
                    .map(|t| t.type_name())
                    .collect::<Vec<String>>()
                    .join("|")
            )?;
        }

        writeln!(out)?;
    } else {
        write!(prefix, "{} ", param.param_type(),)?;

        if let Some(desc) = &param.desc {
            let lines = split_lines(desc, LINE_WRAP - 3, prefix.len());
            write!(out, "{prefix}")?;

            if let Some(first) = lines.first() {
                writeln!(out, "{first}")?;
            }

            for line in lines.iter().skip(1) {
                if line.starts_with('-') {
                    writeln!(out, "--- {line}")?;
                    continue;
                }

                writeln!(out, "---{line}")?;
            }
        }
    }

    Ok(())
}

fn parse(input: &str) -> Result<Vec<Value>> {
    Ok(serde_yaml::from_str(input)?)
}

pub fn compile(input: &str) -> Result<String> {
    let tables = parse(input)?;

    let mut out = String::new();

    writeln!(out, "-- Generated by atomicptr/defold.nvim")?;
    writeln!(out)?;

    if tables.len() == 1 {
        compile_table(&mut out, tables.first().unwrap(), &Vec::new())?;
        return Ok(out);
    }

    // if we have multiple tables, create a fake wrapper "M" table
    let wrapper = Value {
        name: Some(String::from("M")),
        members: Some(tables),
        ..Default::default()
    };

    compile_table(&mut out, &wrapper, &Vec::new())?;

    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;
    use pretty_assertions::assert_eq;

    const DEFOLD_ASTAR_EXAMPLE: &str = include_str!("../fixtures/astar.script_api");
    const DEFOLD_FACEBOOK_EXAMPLE: &str = include_str!("../fixtures/facebook.script_api");
    const DEFOLD_WEBVIEW_EXAMPLE: &str = include_str!("../fixtures/webview.script_api");

    #[test]
    fn test_parse_astar() {
        let astar = parse(DEFOLD_ASTAR_EXAMPLE).expect("expect parse to succeed");
        assert_eq!(1, astar.len());
        let astar = astar.first().expect("should have one");
        assert_eq!(Some("astar".to_string()), astar.name);
    }

    #[test]
    fn test_parse_facebook() {
        let facebook = parse(DEFOLD_FACEBOOK_EXAMPLE).expect("expect parse to succeed");
        assert_eq!(1, facebook.len());
        let facebook = facebook.first().expect("should have one");
        assert_eq!(Some("facebook".to_string()), facebook.name);
    }

    #[test]
    fn test_parse_webview() {
        let webview = parse(DEFOLD_WEBVIEW_EXAMPLE).expect("expect parse to succeed");
        assert_eq!(1, webview.len());
        let webview = webview.first().expect("should have one");
        assert_eq!(Some("webview".to_string()), webview.name);
    }
}
