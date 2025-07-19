(ns defold.main
  (:require [defold.tasks.script-api-compiler :as script-api-compiler]
            [defold.editor :as editor]
            [cheshire.core :as json]))

(defn compile-script-api []
  (script-api-compiler/run (first *command-line-args*)))

(defn list-commands []
  (print (json/generate-string (editor/list-commands))))

(defn send-command []
  (print (json/generate-string (editor/send-command (first *command-line-args*)))))
