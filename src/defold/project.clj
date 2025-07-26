(ns defold.project
  (:require
   [babashka.fs :as fs]
   [babashka.http-client :as http]
   [clojure.java.io :as io]
   [clojure.string :as string]
   [com.brainbot.iniconfig :as iniconfig]
   [defold.script-api-compiler :as script-api-compiler])
  (:import
   [java.nio.charset StandardCharsets]
   [java.security MessageDigest]))

(defn- get-dependencies [ini]
  (->>
    (seq (get ini "project"))
    (map #(when (string/starts-with? (first %) "dependencies") (second %)))
    (filter some?)))

(defn- sha3 [input-string]
  (let [digest       (MessageDigest/getInstance "SHA3-256")
        bytes        (.getBytes input-string StandardCharsets/UTF_8)
        hashed-bytes (.digest digest bytes)]
    (apply str (map #(format "%02x" (bit-and % 0xFF)) hashed-bytes))))

(defn- make-ident [string]
  (let [hash (sha3 string)]
    (subs hash 0 8)))

(defn- cache-dir [ident]
  (let [path (fs/path (fs/xdg-cache-home) "defold.nvim" ident "cache")]
    (fs/create-dirs path)
    (str path)))

(defn- deps-dir [ident]
  (let [path (fs/path (fs/xdg-data-home) "defold.nvim" ident "deps")]
    (fs/create-dirs path)
    (str path)))

(defn- download-file [base-dir file-url]
  (let [ext           (fs/extension file-url)
        file-ident    (make-ident file-url)
        filename      (str file-ident "." ext)
        zip-dir       (str (fs/path base-dir file-ident))
        download-path (str (fs/path base-dir filename))]
    (when (not (fs/exists? download-path))
      (let [response (http/get file-url {:as :stream})]
        (with-open [in  (:body response)
                    out (io/output-stream download-path)]
          (io/copy in out))))
    (when (not (fs/exists? zip-dir))
      (fs/create-dirs zip-dir)
      (fs/unzip download-path zip-dir {:replace-existing true}))))

(defn- find-game-project-files [in-dir]
  (fs/glob in-dir "**/game.project"))

(defn- find-include-dirs [in-dir]
  (let [game-projects (find-game-project-files in-dir)]
    (flatten (map (fn [game-project]
                    (let [project-dir (fs/parent game-project)
                          config      (iniconfig/read-ini (str game-project))
                          libs        (get-in config ["library" "include_dirs"])]
                      (map #(str (fs/path project-dir %)) (string/split libs #","))))
               game-projects))))

(defn- copy-files [from-dir to-dir extensions]
  (doseq [file (flatten (map #(fs/glob from-dir (str "**." %)) extensions))]
    (let [rel-file    (fs/relativize from-dir file)
          target-file (fs/path to-dir rel-file)
          target-dir  (fs/parent target-file)]
      (fs/create-dirs target-dir)
      (fs/copy file target-file))))

(defn- find-script-api-files [in-dir]
  (fs/glob in-dir "**.script_api"))

(defn- compile-script-api-file [file to-path]
  (let [parent (fs/parent to-path)
        output (with-out-str (script-api-compiler/run (str file)))]
    (fs/create-dirs parent)
    (spit (fs/file to-path) output)))

(defn- replace-ext [path new-ext]
  (str (fs/strip-ext path) "." new-ext))

(defn install-dependencies [game-project-file force-redownload]
  (try (when (not (fs/exists? game-project-file))
         (throw (ex-info (str "Could not find game.project file at: " game-project-file) {})))
       (let [ident     (make-ident game-project-file)
             ini       (iniconfig/read-ini game-project-file)
             deps      (get-dependencies ini)
             deps-dir  (deps-dir ident)
             cache-dir (cache-dir ident)]
         (when force-redownload
           (fs/delete-tree deps-dir)
           (fs/delete-tree cache-dir))
         (doseq [url deps]
           (let [url-ident  (make-ident url)
                 cache-path (fs/path cache-dir url-ident)
                 deps-path  (fs/path deps-dir url-ident)]
             (when (not (fs/exists? deps-path))
               (download-file cache-dir url)
               (doseq [include-dir (find-include-dirs cache-path)]
                 (copy-files include-dir (fs/path deps-path (fs/file-name include-dir)) ["lua"])
                 (let [script-api-files (find-script-api-files include-dir)]
                   (doseq [script-api-file script-api-files]
                     (compile-script-api-file script-api-file (str (fs/path deps-path (replace-ext (fs/file-name script-api-file) "lua")))))))
               (fs/delete-tree cache-path))))
         {"success" true})
       (catch Exception e {"error" (ex-message e)})))

(defn list-dependency-dirs [game-project-file]
  (let [ident    (make-ident game-project-file)
        deps-dir (deps-dir ident)
        dirs     (map str (fs/list-dir deps-dir))]
    {"dirs" dirs}))





