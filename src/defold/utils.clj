(ns defold.utils
  (:require
   [babashka.fs :as fs]
   [babashka.http-client :as http]
   [babashka.process :refer [shell]]
   [clojure.java.io :as io]
   [clojure.string :as string]
   [taoensso.timbre :as log]))

(defn command-exists? [cmd]
  (some? (fs/which cmd)))

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
      ("amd64" "x86" "x86_64") :x86
      ("arm" "aarch64")        :arm
      :else                    :unknown)))

(defn get-os-arch-value [m]
  (get-in m [(determine-os) (determine-arch)]))

(defn linux? []
  (= (determine-os) :linux))

(defn windows? []
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

(defn download-and-unpack [download-url]
  (let [temp-dir     (str (fs/create-temp-dir  {:prefix "defold.nvim"}))
        temp-file    (str (fs/create-temp-file {:prefix "defold.nvim"}))
        file-type    (cond
                       (string/ends-with? download-url ".tar.gz") :tar
                       (string/ends-with? download-url ".zip")    :zip
                       :else                                      :unknown)
        temp-file    (case file-type
                       :tar (str temp-file ".tar.gz")
                       :zip (str temp-file ".zip"))]

    (fs/create-dirs temp-dir)

    (log/debug "Downloading" download-url "to" temp-file)
    (download-file download-url temp-file)

    (case file-type
      :tar (run-shell "tar" "-xvf" temp-file "-C" temp-dir)
      :zip (fs/unzip temp-file temp-dir))

    (fs/delete-if-exists temp-file)

    (->
      temp-dir
      (fs/glob "**")
      first
      str)))

(defn seq-replace-var [coll search replace-with]
  (map #(if (= % search) replace-with %) coll))

(defn merge-seq-setters [coll]
  (loop [result [] [x y & rest] coll]
    (if (nil? x)
      result
      (if (and y (= \= (last x)))
        (recur (conj result (str x y)) rest)
        (recur (conj result x) (cons y rest))))))

