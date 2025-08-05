(ns defold.utils
  (:require
   [babashka.fs :refer [which]]))

(defn command-exists? [cmd]
  (try
    (which cmd)
    true
    (catch Throwable t
      (println t)
      false)))

