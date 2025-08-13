(ns defold.utils
  (:require
   [babashka.fs :as fs]
   [babashka.http-client :as http]
   [babashka.process :refer [shell]]
   [clojure.java.io :as io]
   [clojure.string :as string]
   [taoensso.timbre :as log]))

(defn command-exists? [cmd]
  (try
    (not (nil? (fs/which cmd)))
    (catch Throwable t
      (println t)
      false)))

(defn determine-os []
  (let [os-name (string/lower-case (System/getProperty "os.name"))]
    (cond
      (string/includes? os-name "linux")   :linux
      (string/includes? os-name "mac")     :mac
      (string/includes? os-name "windows") :windows
      :else                                :unknown)))

(defn determine-arch []
  (let [arch-name (string/lower-case (System/getProperty "os.arch"))]
    (case arch-name
      ("amd64" "x86")   :x86
      ("arm" "aarch64") :arm
      :else             :unknown)))

(defn get-os-arch-value [m]
  (get-in m [(determine-os) (determine-arch)]))

(defn is-windows? []
  (= (determine-os) :windows))

(defn config-dir
  ([] (case (determine-os)
        :linux   (str (fs/xdg-config-home))
        :mac     (str (fs/path (fs/home) "Library" "Preferences"))
        :windows (str (fs/path (System/getenv "APPDATA")))
        :unknown (str (fs/path (fs/home) ".config"))))
  ([& path] (str (apply fs/path (config-dir) path))))

(defn data-dir
  ([] (case (determine-os)
        :linux   (str (fs/xdg-data-home))
        :mac     (str (fs/path (fs/home) "Library"))
        :windows (str (fs/path (System/getenv "APPDATA")))
        :unknown (str (fs/path (fs/home) ".data"))))
  ([& path] (str (apply fs/path (data-dir) path))))

(defn cache-dir
  ([] (case (determine-os)
        :linux   (str (fs/xdg-cache-home))
        :mac     (str (fs/path (fs/home) "Library" "Caches"))
        :windows (str (fs/path (System/getenv "TEMP")))
        :unknown (str (fs/path (fs/home) ".cache"))))
  ([& path] (str (apply fs/path (cache-dir) path))))

(defn sha3 [s]
  (let [md (.getInstance java.security.MessageDigest "SHA3-256")
        bytes (.getBytes s)]
    (.update md bytes)
    (apply str (map #(format "%02x" %) (.digest md)))))

(defn escape-spaces [s]
  (string/escape s {\space "\\ "}))

(defn- remove-ansi-codes [s]
  (string/replace s #"\x1B\[([0-9A-Za-z;?])*[\w@]" ""))

(defn run-shell [& cmd]
  (log/info "run-shell:" cmd)
  (let [res (apply shell {:out :string :err :string} cmd)
        out (remove-ansi-codes (:out res))
        err (remove-ansi-codes (:err res))]
    (when (and (some? out) (not-empty out))
      (log/debug "run-shell result:" out))
    (when (and (some? err) (not-empty err))
      (log/error "run-shell error:" err))
    res))

(defn download-file [url path]
  (let [response (http/get url {:as :stream})]
    (with-open [in  (:body response)
                out (io/output-stream path)]
      (io/copy in out))))
