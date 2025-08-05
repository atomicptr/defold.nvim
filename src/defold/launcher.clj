(ns defold.launcher
  (:require
   [babashka.fs :as fs]
   [babashka.process :refer [shell]]
   [defold.utils :refer [command-exists?]]))

(def base-class-name "com.defold.nvim.%s")

(defn usage []
  (println "Usage: <file> [line]")
  (println "    <file>: The file to open")
  (println "    [line]: Optional. The line number to open the file at")
  (System/exit 1))

(defn sha3 [s]
  (let [md (.getInstance java.security.MessageDigest "SHA3-256")
        bytes (.getBytes s)]
    (.update md bytes)
    (apply str (map #(format "%02x" %) (.digest md)))))

(defn run-shell [& cmd]
  (println "Run:" cmd)
  (apply shell cmd))

(defn find-project-root-from-file [file]
  (loop [current-dir (fs/parent file)]
    (if-not current-dir
      (throw (ex-info "Could not determine Defold project from path: " file {}))
      (let [target (fs/path current-dir "game.project")]
        (if (fs/exists? target)
          (str current-dir)
          (recur (fs/parent current-dir)))))))

(defn project-id [project-root]
  (subs (sha3 project-root) 0 8))

; TODO: support windows / macos better, should work tho
(defn runtime-dir [project-root]
  (let [p (fs/path (fs/xdg-cache-home) "defold.nvim" "runtime" (project-id project-root))]
    (fs/create-dirs p)
    (str p)))

(defn launch-app-in-terminal [class-name cmd & args]
  (let [term [["ghostty" "--class=%s" "-e"]
              ["foot" "--app-id=%s" "-e"]
              ["kitty" "--class=%s" "-e"]
              ["alacritty" "--class=%s" "-e"]
              ["st" "-c %s" "-e"]]
        term  (some #(when (command-exists? (first %1)) %1) term)]
    (if term
      (let [[term-cmd class-arg run-arg] term]
        (try
          (apply run-shell term-cmd (format class-arg class-name) run-arg cmd args)
          (catch Exception e
            (println "Failed to launch terminal" e)
            (System/exit 1))))
      (do (println "No supported terminal found, aborting...")
          (System/exit 1)))))

(defn switch-focus [class-name]
  (try
    (cond
      (command-exists? "hyprctl") (run-shell "hyprctl" "dispatch" "focuswindow" (str "class:" class-name))

      :else
      (println "No supported focus switcher found, do nothing..."))
    (catch Exception e
      (println "Could not switch focus, do nothing..." e))))

(defn make-neovim-edit-command [file-name line]
  (if line
    (format "edit +%s %s" line file-name)
    (format "edit %s" file-name)))

(defn launch-new-nvim-instance [class-name neovim socket-file file-name line]
  (let [file (if line (format "%s +%s" file-name line) file-name)]
    (launch-app-in-terminal class-name neovim "--listen" socket-file "--remote" file)))

(defn run [file-name line]
  (when (or (< (count *command-line-args*) 1)
          (> (count *command-line-args*) 2))
    (usage))

  (let [neovim      "nvim"
        line        (when line (Integer/parseInt line))
        root-dir    (find-project-root-from-file file-name)
        runtime     (runtime-dir root-dir)
        socket-file (str (fs/path runtime "neovim.socket"))
        class-name  (format base-class-name (project-id root-dir))
        edit-cmd    (make-neovim-edit-command file-name line)]
    (when (not (command-exists? neovim))
      (println "Could not find nvim")
      (System/exit 1))
    (if (fs/exists? socket-file)
      (try
        (run-shell neovim "--server" socket-file "--remote-send" (format "\"<C-\\\\><C-n>:%s<CR>\"" edit-cmd))
        (catch Exception e
          (println "Failed to communicate with neovim server:" e)

         ; if we couldnt communicate with the server despite existing apparently
         ; delete it and start a new instance
          (fs/delete-if-exists socket-file)
          (launch-new-nvim-instance class-name neovim socket-file file-name line)))
      (launch-new-nvim-instance class-name neovim socket-file file-name line))
    (switch-focus class-name)))

