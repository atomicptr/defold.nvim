(ns defold.main
  (:require [cheshire.core :as json]
            [defold.editor :as editor]
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


