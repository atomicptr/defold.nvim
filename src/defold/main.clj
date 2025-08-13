(ns defold.main
  (:require
   [babashka.fs :as fs]
   [cheshire.core :as json]
   [clojure.string :as string]
   [defold.debugger :as debugger]
   [defold.editor :as editor]
   [defold.editor-config :as editor-config]
   [defold.launcher :as launcher]
   [defold.logging :as logging]
   [defold.project :as project]
   [taoensso.timbre :as log]))

(defn- setup-logging! [type]
  (case type
    (:launch-neovim) (logging/setup-with-stdout-logging!)

    (logging/setup-with-file-logging-only!)))

(defn- print-json [m]
  (print (json/generate-string m)))

(defn parse-config [path]
  (assert (fs/exists? path) (format "assert that '%s' exists" path))
  (json/parse-string (slurp path)))

(defmulti run
  (fn [type & args]
    (setup-logging! type)
    (log/info (format "Run command '%s' with args: [%s]" type (string/join " " args)))
    type))

(defmethod run :setup [_ config-file]
  (try
    (let [conf (parse-config config-file)]
      (when-not (get-in conf ["plugin_config" "debugger" "custom_executable"])
        (debugger/setup))
      (print-json {:status 200}))
    (catch Throwable t
      (log/error "Error:" (ex-message t) t)
      (print-json {:status 500 :error (ex-message t)}))))

(defmethod run :set-default-editor [_ config-file]
  (let [conf (parse-config config-file)]
    (print-json (editor-config/set-default-editor config-file (conf "bb_path")))))

(defmethod run :install-dependencies
  ([_ config game-project] (run :install-dependencies config game-project false))
  ([_ _ game-project force-redownload] (print-json (project/install-dependencies game-project force-redownload))))

(defmethod run :list-commands [_ _]
  (print-json (editor/list-commands)))

(defmethod run :list-dependency-dirs [_ _ game-project]
  (print-json (project/list-dependency-dirs game-project)))

(defmethod run :send-command [_ _ cmd]
  (print-json (editor/send-command cmd)))

(defmethod run :launch-neovim
  ([_ _ filename] (launcher/run filename nil))
  ([_ _ filename line] (launcher/run filename line)))

(defmethod run :focus-neovim [_ _ root-dir]
  (print-json (launcher/focus-neovim root-dir)))

(defmethod run :focus-game [_ _ root-dir]
  (print-json (launcher/focus-game root-dir)))

(defmethod run :mobdap-path [_ _]
  (let [path (debugger/executable-path)]
    (if (fs/exists? path)
      (print-json {:status 200 :mobdap_path path})
      (print-json {:status 500 :error (str "Could not find file: " path)}))))
