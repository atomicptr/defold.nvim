(ns defold.utils
  (:require
   [babashka.fs :as fs]
   [clojure.string :as string]))

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
