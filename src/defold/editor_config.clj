(ns defold.editor-config
  (:require
   [babashka.fs :as fs :refer [which]]
   [clojure.edn :as edn]
   [defold.utils :refer [cache-dir config-dir determine-os escape-spaces]]
   [taoensso.timbre :as log]))

(defn- editor-settings-filepath []
  (config-dir "Defold" "prefs.editor_settings"))

(defn- read-editor-settings [path]
  (edn/read-string (slurp path)))

(defn- save-editor-settings [path config]
  (spit path config))

(defn- bb-edn []
  (System/getProperty "babashka.config"))

(defn- create-runner-script [config-path bb-path]
  (let [os (determine-os)
        [run-file content]
        (case os
          :linux   ["run.sh"  (format "#!/usr/bin/env bash\n%s --config \"%s\" run launch-neovim \"%s\" \"$1\" $2" (escape-spaces bb-path) (bb-edn) config-path)]
          :mac     ["run.sh"  (format "#!/usr/bin/env bash\nexport PATH=\"/usr/bin:/usr/local/bin:$PATH\"\n%s --config \"%s\" run launch-neovim \"%s\" \"$1\" $2" (escape-spaces bb-path) (bb-edn) config-path)]
          :windows ["run.bat" (format "@echo off\r\n\"%s\" --config \"%s\" run launch-neovim \"%s\" \"%%1\" %%2" bb-path (bb-edn) config-path)]
          :unknown (let [ex (ex-info "Can't create runner script for unknown operating system" {})]
                     (log/error (ex-message ex) ex)
                     (throw ex)))
        runner-path (cache-dir "defold.nvim" run-file)]
    (fs/create-dirs (fs/parent runner-path))
    (spit runner-path content)
    (when (or (= os :linux) (= os :mac))
      (fs/set-posix-file-permissions runner-path "rwxr-xr-x"))
    runner-path))

(defn- update-editor-settings [config config-path bb-path]
  (-> config
    (assoc-in [:code :custom-editor]     (create-runner-script config-path bb-path))
    (assoc-in [:code :open-file]         "{file}")
    (assoc-in [:code :open-file-at-line] "{file} {line}")))

(defn set-default-editor [config-path bb-path]
  (let [bb-path       (or bb-path (which "bb"))
        settings-file (editor-settings-filepath)]
    (if (not (fs/exists? settings-file))
      {"error" (str "Could not find Defold 'prefs.editor_settings' at " settings-file)}
      (let [settings (read-editor-settings settings-file)]
        (save-editor-settings settings-file (pr-str (update-editor-settings settings config-path bb-path)))
        {"status" 200}))))

