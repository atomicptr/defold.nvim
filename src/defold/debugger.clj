(ns defold.debugger
  (:require
   [babashka.fs :as fs]
   [defold.utils :refer [data-dir download-and-unpack get-os-arch-value
                         windows?]]
   [taoensso.timbre :as log]))

(def ^:private mobdap-version "0.1.5")

(def ^:private mobdap-urls
  {:linux   {:x86 "https://github.com/atomicptr/mobdap/releases/download/v%s/mobdap-linux-amd64.tar.gz"
             :arm "https://github.com/atomicptr/mobdap/releases/download/v%s/mobdap-linux-arm64.tar.gz"}
   :mac     {:x86 "https://github.com/atomicptr/mobdap/releases/download/v%s/mobdap-macos-amd64.tar.gz"
             :arm "https://github.com/atomicptr/mobdap/releases/download/v%s/mobdap-macos-arm64.tar.gz"}
   :windows {:x86 "https://github.com/atomicptr/mobdap/releases/download/v%s/mobdap-windows-amd64.zip"}})

(defn executable-path []
  (if (windows?)
    (data-dir "defold.nvim" "bin" "mobdap.exe")
    (data-dir "defold.nvim" "bin" "mobdap")))

(defn- version-file-path []
  (data-dir "defold.nvim" ".meta" "mobdap.version"))

(defn- installed-version []
  (let [path (version-file-path)]
    (fs/create-dirs (fs/parent path))

    (when (fs/exists? path)
      (slurp path))))

(defn- install-mobdap []
  (let [download-url (format (get-os-arch-value mobdap-urls) mobdap-version)
        mobdap-file  (download-and-unpack download-url)
        exec-path    (executable-path)]
    (fs/create-dirs (fs/parent exec-path))
    (fs/delete-if-exists exec-path)

    (fs/move mobdap-file exec-path)
    (spit (version-file-path) mobdap-version)
    (log/debug "mobdap: Installed version:" mobdap-version)

    (when-not (windows?)
      (fs/set-posix-file-permissions exec-path "rwxr-xr-x"))))

(defn setup []
  (when (get-os-arch-value mobdap-urls)
    (log/debug "mobdap: Currently installed version:" (installed-version))

    (cond
      (not  (fs/exists? (executable-path)))     (install-mobdap)
      (not= (installed-version) mobdap-version) (install-mobdap)
      :else (log/debug "mobdap: Nothing to do..."))

    (log/debug "mobdap: Installed at" (executable-path))))

