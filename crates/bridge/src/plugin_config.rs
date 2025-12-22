#[derive(Debug, clap::ValueEnum, Clone, Copy)]
pub enum LauncherType {
    #[clap(name = "neovide")]
    Neovide,

    #[clap(name = "terminal")]
    Terminal,
}

#[derive(Debug, clap::ValueEnum, Clone, Copy)]
pub enum SocketType {
    #[clap(name = "fsock")]
    Fsock,

    #[clap(name = "netsock")]
    Netsock,
}

#[derive(Debug, Clone)]
pub struct PluginConfig {
    pub launcher_type: Option<LauncherType>,
    pub socket_type: Option<SocketType>,
    pub executable: Option<String>,
    pub arguments: Option<Vec<String>>,
}
