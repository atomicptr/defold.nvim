(ns defold.main
  (:require
   [cheshire.core :as json]
   [defold.logging :as logging]
   [defold.project :as project]
   [taoensso.timbre :as log]))

(defn- setup-logging! [type]
  (case type
    (:launch-neovim) (logging/setup-with-stdout-logging!)

    (logging/setup-with-file-logging-only!)))

(defn- print-json [m]
  (print (json/generate-string m)))

(defmulti run
  (fn [type & args]
    (setup-logging! type)
    (log/info (format "Run command '%s' with args: %s" type args))
    type))

(defmethod run :setup [_]
  (print-json {:status 200}))

(defmethod run :install-dependencies
  ([_ game-project]
   (print-json (project/install-dependencies game-project false)))
  ([_ game-project force-redownload]
   (print-json (project/install-dependencies game-project force-redownload))))

(defmethod run :list-dependency-dirs [_ game-project]
  (print-json (project/list-dependency-dirs game-project)))

(defn run-wrapped [& args]
  (try
    (apply run args)
    (catch Throwable t
      (log/error (ex-message t) t))))
