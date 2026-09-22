// shitty & incomplete implementation of protobuf just enough to help us parse defold protobuf
use anyhow::Result;
use chumsky::prelude::*;

#[derive(Debug, Clone, PartialEq)]
pub enum Value {
    String(String),
    Number(f64),
    Bool(bool),
    Ident(String),
    Message(Message),
}

#[derive(Debug, Clone, Default, PartialEq)]
pub struct Message {
    pub fields: Vec<(String, Value)>,
}

impl Message {
    pub fn get(&self, key: &str) -> Vec<Value> {
        self.fields
            .iter()
            .filter(|(k, _)| k == key)
            .map(|(_, v)| v)
            .cloned()
            .collect()
    }

    pub fn first_string(&self, key: &str) -> Option<String> {
        match self.get(key).first()? {
            Value::String(s) => Some(s.clone()),
            _ => None,
        }
    }
}

pub fn parse(src: &str) -> Result<Message> {
    miniproto()
        .parse(src)
        .into_result()
        .map_err(|e| anyhow::anyhow!("{e:?}"))
}

fn miniproto<'a>() -> impl Parser<'a, &'a str, Message> {
    let ident = text::ascii::ident().map(str::to_owned);

    let escape = just('\\').ignore_then(choice((
        just('\\').to('\\'),
        just('"').to('"'),
        just('\'').to('\''),
        just('n').to('\n'),
        just('r').to('\r'),
        just('t').to('\t'),
    )));

    let string = just('"')
        .ignore_then(
            choice((escape, none_of('"')))
                .repeated()
                .collect::<String>(),
        )
        .then_ignore(just('"'))
        .padded();

    let strings = string
        .repeated()
        .at_least(1)
        .collect::<Vec<_>>()
        .map(|parts| Value::String(parts.concat()));

    let number = just('-')
        .or_not()
        .then(text::int(10))
        .then(just('.').then(text::digits(10)).or_not())
        .to_slice()
        .from_str::<f64>()
        .unwrapped()
        .map(Value::Number)
        .padded();

    let boolean = choice((
        text::ascii::keyword("true").to(Value::Bool(true)),
        text::ascii::keyword("false").to(Value::Bool(false)),
    ))
    .padded();

    let ident_val = ident.map(Value::Ident).padded();

    recursive(|msg| {
        let message_val = msg
            .clone()
            .delimited_by(just('{').padded(), just('}').padded())
            .map(Value::Message);

        let scalar = choice((strings, number, boolean, ident_val));

        let field = ident.padded().then(choice((
            just(':').padded().ignore_then(scalar),
            message_val,
        )));

        field
            .repeated()
            .collect()
            .map(|fields| Message { fields })
            .padded()
    })
    .then_ignore(end())
}
