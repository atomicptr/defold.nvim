(ns defold.main
  (:require
   [cheshire.core :as json]
   [defold.editor :as editor]
   [defold.editor-config :as editor-config]
   [defold.launcher :as launcher]
   [defold.project :as project]))

(defn init []
  (print (json/generate-string {:hello "defold"})))

(defn install-dependencies []
  (print (json/generate-string (project/install-dependencies (first *command-line-args*) (second *command-line-args*)))))

(defn list-commands []
  (print (json/generate-string (editor/list-commands))))

(defn list-dependency-dirs []
  (print (json/generate-string (project/list-dependency-dirs (first *command-line-args*)))))

(defn send-command []
  (print (json/generate-string (editor/send-command (first *command-line-args*)))))

(defn launch-neovim []
  (launcher/run (first *command-line-args*) (second *command-line-args*)))

(defn set-default-editor []
  (print (json/generate-string (editor-config/set-default-editor (first *command-line-args*)))))

(defn focus-neovim []
  (print (json/generate-string (launcher/focus-neovim (first *command-line-args*)))))

(defn focus-game []
  (print (json/generate-string (launcher/focus-game (first *command-line-args*)))))
