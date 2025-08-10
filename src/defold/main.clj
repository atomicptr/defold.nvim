(ns defold.main
  (:require
   [cheshire.core :as json]
   [defold.editor :as editor]
   [defold.editor-config :as editor-config]
   [defold.launcher :as launcher]
   [defold.logging :as logging]
   [defold.project :as project]
   [taoensso.timbre :as log]))

(defn init []
  (logging/setup-with-file-logging-only!)
  (log/info "init" *command-line-args*)
  (print (json/generate-string {:hello "defold"})))

(defn install-dependencies []
  (logging/setup-with-file-logging-only!)
  (log/info "install-dependencies" *command-line-args*)
  (print (json/generate-string (project/install-dependencies (first *command-line-args*) (second *command-line-args*)))))

(defn list-commands []
  (logging/setup-with-file-logging-only!)
  (log/info "list-commands" *command-line-args*)
  (print (json/generate-string (editor/list-commands))))

(defn list-dependency-dirs []
  (logging/setup-with-file-logging-only!)
  (log/info "list-dependency-dirs" *command-line-args*)
  (print (json/generate-string (project/list-dependency-dirs (first *command-line-args*)))))

(defn send-command []
  (logging/setup-with-file-logging-only!)
  (log/info "send-command" *command-line-args*)
  (print (json/generate-string (editor/send-command (first *command-line-args*)))))

(defn launch-neovim []
  (logging/setup-with-stdout-logging!)
  (log/info "launch-neovim" *command-line-args*)
  (launcher/run (first *command-line-args*) (second *command-line-args*)))

(defn set-default-editor []
  (logging/setup-with-file-logging-only!)
  (log/info "set-default-editor" *command-line-args*)
  (print (json/generate-string (editor-config/set-default-editor (first *command-line-args*)))))

(defn focus-neovim []
  (logging/setup-with-file-logging-only!)
  (log/info "focus-neovim" *command-line-args*)
  (print (json/generate-string (launcher/focus-neovim (first *command-line-args*)))))

(defn focus-game []
  (logging/setup-with-file-logging-only!)
  (log/info "focus-game" *command-line-args*)
  (print (json/generate-string (launcher/focus-game (first *command-line-args*)))))
