use serde::Deserialize;

#[derive(Debug, Deserialize, Clone, Copy)]
pub enum LauncherType {
    #[serde(rename = "neovide")]
    Neovide,

    #[serde(rename = "terminal")]
    Terminal,
}

#[derive(Debug, Deserialize, Clone, Copy)]
pub enum SocketType {
    #[serde(rename = "fsock")]
    Fsock,

    #[serde(rename = "netsock")]
    Netsock,
}

#[derive(Debug, Deserialize, Clone)]
pub struct LauncherConfig {
    #[serde(rename = "type")]
    pub launcher_type: Option<LauncherType>,

    pub executable: Option<String>,
    pub extra_arguments: Option<Vec<String>>,
    pub terminal: Option<TerminalConfig>,
    pub socket_type: Option<SocketType>,
}

#[derive(Debug, Deserialize, Clone)]
pub struct TerminalConfig {
    pub class_argument: Option<String>,
    pub run_argument: Option<String>,
}

#[derive(Debug, Deserialize, Clone)]
pub struct PluginConfig {
    pub launcher: Option<LauncherConfig>,
}
