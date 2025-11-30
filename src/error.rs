use nvim_oxi::{conversion::ToObject, serde::Serializer};
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize)]
pub struct LuaError {
    pub error: String,
}

impl From<String> for LuaError {
    fn from(value: String) -> Self {
        LuaError {
            error: format!("Err: {value}"),
        }
    }
}

impl From<anyhow::Error> for LuaError {
    fn from(value: anyhow::Error) -> Self {
        LuaError::from(format!("{value:?}"))
    }
}

impl ToObject for LuaError {
    fn to_object(self) -> Result<nvim_oxi::Object, nvim_oxi::conversion::Error> {
        self.serialize(Serializer::new()).map_err(Into::into)
    }
}
