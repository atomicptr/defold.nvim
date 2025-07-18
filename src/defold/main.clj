(ns defold.main
  (:require [defold.tasks.script-api-compiler :as script-api-compiler]))

(defn compile-script-api []
  (script-api-compiler/run (first *command-line-args*)))
