pub enum Failure {
    Unavailable(&'static str),
    Error(anyhow::Error),
}

impl From<anyhow::Error> for Failure {
    fn from(err: anyhow::Error) -> Self {
        Self::Error(err)
    }
}
