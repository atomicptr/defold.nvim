(ns defold.editor-config
  (:require
   [babashka.fs :as fs :refer [which]]
   [clojure.edn :as edn]
   [defold.utils :refer [cache-dir config-dir is-windows?]]))

(defn- editor-settings-filepath []
  (config-dir "Defold" "prefs.editor_settings"))

(defn- read-editor-settings [path]
  (edn/read-string (slurp path)))

(defn- save-editor-settings [path config]
  (spit path config))

(defn- bb-edn []
  (System/getProperty "babashka.config"))

(defn- create-runner-script [bb-path]
  (if (is-windows?)
    (let [runner-path (cache-dir "defold.nvim" "run.bat")]
      (fs/create-dirs (fs/parent runner-path))
      (spit runner-path (format "@echo off\r\n\"%s\" --config \"%s\" run launch-neovim %%1 %%2" bb-path (bb-edn)))
      runner-path)
    (let [runner-path (cache-dir "defold.nvim" "run.sh")]
      (fs/create-dirs (fs/parent runner-path))
      (spit runner-path (format "#!/usr/bin/env bash\n%s --config %s run launch-neovim $1 $2" bb-path (bb-edn)))
      (fs/set-posix-file-permissions runner-path "rwxr-xr-x")
      runner-path)))

(defn- update-editor-settings [config bb-path]
  (-> config
    (assoc-in [:code :custom-editor]     (create-runner-script bb-path))
    (assoc-in [:code :open-file]         "{file}")
    (assoc-in [:code :open-file-at-line] "{file} {line}")))

(defn set-default-editor [bb-path]
  (let [bb-path       (or bb-path (which "bb"))
        settings-file (editor-settings-filepath)]
    (if (not (fs/exists? settings-file))
      {"error" (str "Could not find Defold 'prefs.editor_settings' at " settings-file)}
      (let [settings (read-editor-settings settings-file)]
        (save-editor-settings settings-file (pr-str (update-editor-settings settings bb-path)))
        {"status" 200}))))

