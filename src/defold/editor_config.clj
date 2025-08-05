(ns defold.editor-config
  (:require
   [babashka.fs :as fs :refer [which]]
   [clojure.edn :as edn]
   [defold.utils :refer [config-dir]]))

(defn- editor-settings-filepath []
  (config-dir "Defold" "prefs.editor_settings"))

(defn- read-editor-settings [path]
  (edn/read-string (slurp path)))

(defn- save-editor-settings [path config]
  (spit path config))

(defn- bb-edn []
  (System/getProperty "babashka.config"))

(defn- update-editor-settings [config bb-path]
  (-> config
    (assoc-in [:code :custom-editor]     (str bb-path))
    (assoc-in [:code :open-file]         (format "--config %s run launch-neovim {file}" (bb-edn)))
    (assoc-in [:code :open-file-at-line] (format "--config %s run launch-neovim {file} {line}" (bb-edn)))))

(defn set-default-editor [bb-path]
  (let [bb-path       (or bb-path (which "bb"))
        settings-file (editor-settings-filepath)]
    (if (not (fs/exists? settings-file))
      {"error" (str "Could not find Defold 'prefs.editor_settings' at " settings-file)}
      (let [settings (read-editor-settings settings-file)]
        (save-editor-settings settings-file (pr-str (update-editor-settings settings bb-path)))
        {"status" 200}))))

