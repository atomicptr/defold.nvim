(ns defold.neovide
  (:require
   [babashka.fs :as fs]
   [defold.utils :refer [data-dir download-and-unpack get-os-arch-value
                         windows?]]
   [taoensso.timbre :as log]))

(def ^:private neovide-version "0.15.1")

(def ^:private neovide-urls
  ; TODO: add macos support, sadly neovide only offers the executables as .dmg (and then .app) files making the installation kinda cumbersome
  {:linux   {:x86 "https://github.com/neovide/neovide/releases/download/%s/neovide-linux-x86_64.tar.gz"}
   :windows {:x86 "https://github.com/neovide/neovide/releases/download/%s/neovide.exe.zip"}})

(defn executable-path []
  (if (windows?)
    (data-dir "defold.nvim" "bin" "neovide.exe")
    (data-dir "defold.nvim" "bin" "neovide")))

(defn- version-file-path []
  (data-dir "defold.nvim" ".meta" "neovide.version"))

(defn- installed-version []
  (let [path (version-file-path)]
    (fs/create-dirs (fs/parent path))

    (when (fs/exists? path)
      (slurp path))))

(defn- install-neovide []
  (let [download-url (format (get-os-arch-value neovide-urls) neovide-version)
        mobdap-file  (download-and-unpack download-url)
        exec-path    (executable-path)]
    (fs/create-dirs (fs/parent exec-path))
    (fs/delete-if-exists exec-path)

    (fs/move mobdap-file exec-path)
    (spit (version-file-path) neovide-version)
    (log/debug "neovide: Installed version:" neovide-version)

    (when-not (windows?)
      (fs/set-posix-file-permissions exec-path "rwxr-xr-x"))))

(defn setup []
  (log/debug "neovide: Currently installed version:" (installed-version))

  (cond
    (not  (fs/exists? (executable-path)))      (install-neovide)
    (not= (installed-version) neovide-version) (install-neovide)))
