(ns defold.main
  (:require [cheshire.core :as json]
            [defold.editor :as editor]
            [defold.tasks.script-api-compiler :as script-api-compiler]))

(defn compile-script-api []
  (script-api-compiler/run (first *command-line-args*)))

(defn list-commands []
  (print (json/generate-string (editor/list-commands))))

(defn send-command []
  (print (json/generate-string (editor/send-command (first *command-line-args*)))))
