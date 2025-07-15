#!/usr/bin/env bb

(require '[babashka.curl :as curl]
         '[babashka.fs :as fs]
         '[cheshire.core :as json]
         '[clojure.string :as string]
         '[clojure.java.io :as io])

(def base-url "https://api.github.com/repos/astrochili/defold-annotations")
(def releases-url (str base-url "/releases"))

(defn snake-to-kebab-case [s]
  (assert (string? s))
  (string/replace s #"_" "-"))

(defn transform-key-fn [key]
  (-> key
      snake-to-kebab-case
      keyword))

(defn fetch-releases []
  (let [res  (curl/get releases-url)
        body (:body res)]
    (json/parse-string body transform-key-fn)))

(defn fetch-newest-release []
  (-> (fetch-releases)
      first))

(defn download-file [url to-path]
  (try
    (let [res (curl/get url {:as :bytes})]
      (with-open [os (io/output-stream to-path)]
        (.write os (:body res))))
    (catch Exception e
      (println "ERROR: Could not download" url "to path" to-path)
      (println e)
      (fs/delete-if-exists to-path))))

(def root-dir (-> *file*
                  (fs/parent)
                  (fs/parent)))

(def data-dir (fs/file root-dir "data"))
(def api-dir  (fs/file data-dir "defold_api"))

(let [release  (fetch-newest-release)
      _        (println "Found tag:" (:tag-name release))
      tempfile (fs/file (fs/temp-dir) "api.zip")
      _        (fs/delete-tree tempfile)
      url      (-> release
                   :assets
                   first
                   :browser-download-url)]
  (download-file url tempfile)
  (fs/delete-tree api-dir)
  (fs/unzip tempfile data-dir)
  (println "Downloaded" (str api-dir)))

