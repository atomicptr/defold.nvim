(ns defold.launcher
  (:require
   [babashka.fs :as fs]
   [babashka.process :refer [shell]]
   [clojure.string :as string]
   [com.brainbot.iniconfig :as iniconfig]
   [defold.utils :refer [cache-dir command-exists? determine-os is-windows?
                         sha3]]
   [taoensso.timbre :as log]))

(def base-class-name "com.defold.nvim.%s")

(defn- usage []
  (println "Usage: <file> [line]")
  (println "    <file>: The file to open")
  (println "    [line]: Optional. The line number to open the file at")
  (System/exit 1))

(defn- remove-ansi-codes [s]
  (string/replace s #"\x1B\[([0-9A-Za-z;?])*[\w@]" ""))

(defn- run-shell [& cmd]
  (log/info "run-shell:" cmd)
  (let [res (apply shell {:out :string :err :string} cmd)
        out (remove-ansi-codes (:out res))
        err (remove-ansi-codes (:err res))]
    (when (and (some? out) (not-empty out))
      (log/debug "run-shell result:" out))
    (when (and (some? err) (not-empty err))
      (log/error "run-shell error:" err))
    res))

(defn- find-project-root-from-file [file]
  (loop [current-dir (fs/parent (fs/path file))]
    (if-not current-dir
      (throw (ex-info (str "Could not determine Defold project from path: " file) {}))
      (let [target (fs/path current-dir "game.project")]
        (if (fs/exists? target)
          (str current-dir)
          (recur (fs/parent current-dir)))))))

(defn- project-id [project-root]
  (subs (sha3 project-root) 0 8))

(defn- runtime-dir [project-root]
  (let [p (cache-dir "defold.nvim" "runtime" (project-id project-root))]
    (fs/create-dirs p)
    p))

(defn- terminals []
  (concat
    [["ghostty" "--class=%s" "-e"]
     ["foot" "--app-id=%s" "-e"]
     ["kitty" "--class=%s" "-e"]
     ["alacritty" "--class=%s" "-e"]
     ["st" "-c %s" "-e"]]
    (case (determine-os)
      :linux   []
      :mac     []
      :windows [["wt" "" ""]]
      :else [])))

(defn- launch-app-in-terminal [class-name cmd & args]
  (let [term  (some #(when (command-exists? (first %)) %) (terminals))]
    (if term
      (let [[term-cmd class-arg run-arg] term]
        (try
          (apply run-shell term-cmd (format class-arg class-name) run-arg cmd args)
          (catch Exception e
            (log/error "Failed to launch terminal" e)
            (System/exit 1))))
      (do (log/error "No supported terminal found, aborting...")
          (System/exit 1)))))

(defn- switch-focus [type name]
  (let [target (case type
                 :class (format "class:%s" name)
                 :title (format "title:%s" name)
                 (throw (ex-info (format "Unknown type: %s" type) {})))]
    (log/info "Switching to:" target)
    (try
      (cond
        (command-exists? "hyprctl") (run-shell "hyprctl" "dispatch" "focuswindow" target)

        :else
        (log/error "No supported focus switcher found, do nothing..."))
      (catch Exception e
        (log/error "Could not switch focus, do nothing..." e)))))

(defn- escape-spaces [s]
  (string/escape s {\space "\\ "}))

(defn- make-neovim-edit-command [file-name line]
  (if line
    (format "edit +%s %s" line (escape-spaces file-name))
    (format "edit %s" (escape-spaces file-name))))

(defn- launch-new-nvim-instance [class-name neovim socket-file file-name line]
  (let [file (if line (format "%s +%s" file-name line) file-name)]
    (launch-app-in-terminal class-name neovim "--listen" socket-file "--remote" file)))

(defn- run-fsock [neovim root-dir _ filename line edit-cmd]
  (let [runtime     (runtime-dir root-dir)
        socket-file (str (fs/path runtime "neovim.sock"))
        class-name  (format base-class-name (project-id root-dir))]
    (if (fs/exists? socket-file)
      (try
        (run-shell neovim "--server" socket-file "--remote-send" (format "\"<C-\\\\><C-n>:%s<CR>\"" edit-cmd))
        (catch Exception e
          (log/error "Failed to communicate with neovim server:" e)

          ; if we couldnt communicate with the server despite existing apparently
          ; delete it and start a new instance
          (fs/delete-if-exists socket-file)
          (launch-new-nvim-instance class-name neovim socket-file (escape-spaces filename) line)))
      (launch-new-nvim-instance class-name neovim socket-file (escape-spaces filename) line))))

(defn- win-port-in-use? [port]
  (string/includes? (:out (shell {:out :string} "netstat" "-aon")) (format ":%s" port)))

(defn- win-find-free-port []
  (loop [port (+ 1024 (rand-int (- 65535 1024)))]
    (if (not (win-port-in-use? port))
      port
      (recur (+ 1024 (rand-int (- 65535 1024)))))))

(defn- run-netsock [neovim root-dir class-name filename line edit-cmd]
  (let [runtime   (runtime-dir root-dir)
        port-path (str (fs/path runtime "port"))
        exists?   (fs/exists? port-path)
        port      (if exists? (slurp port-path) (win-find-free-port))
        socket    (format "127.0.0.1:%s" port)]
    (log/info "run-netsock: Port:" port)
    (if (win-port-in-use? port)
      (try
        (run-shell neovim "--server" socket "--remote-send" (format "\"<C-\\\\><C-n>:%s<CR>\"" edit-cmd))
        (catch Exception e
          (log/error "Failed to communicate with neovim server:" e)
          (let [new-port (win-find-free-port)]
            (spit port-path new-port)
            (launch-new-nvim-instance class-name neovim socket (escape-spaces filename) line))))
      (launch-new-nvim-instance class-name neovim socket (escape-spaces filename) line))))

(defn run [file-name line]
  (when (or (< (count *command-line-args*) 1)
          (> (count *command-line-args*) 2))
    (usage))

  (let [neovim      (str (fs/which "nvim"))
        line        (when line (Integer/parseInt line))
        root-dir    (find-project-root-from-file file-name)
        class-name  (format base-class-name (project-id root-dir))
        edit-cmd    (make-neovim-edit-command file-name line)]
    (when (not (command-exists? neovim))
      (log/error "Could not find neovim" neovim)
      (System/exit 1))
    (cond
      (is-windows?) (run-netsock neovim root-dir class-name file-name line edit-cmd)
      :else         (run-fsock   neovim root-dir class-name file-name line edit-cmd))
    (switch-focus :class class-name)))

(defn focus-neovim [root-dir]
  (try
    (assert (some? root-dir))
    (assert (fs/exists? (fs/path root-dir "game.project")))
    (let [class-name (format base-class-name (project-id root-dir))
          res (with-out-str (switch-focus :class class-name))]
      {"status" 200 "res" res})
    (catch Throwable t
      (log/error "focus-neovim: Error" (ex-message t) t)
      {"error" (ex-message t)})))

(defn focus-game [root-dir]
  (try
    (assert (some? root-dir))
    (let [game-project (fs/path root-dir "game.project")
          _            (assert (fs/exists? game-project))
          config       (iniconfig/read-ini (str game-project))
          title        (get-in config ["project" "title"])
          _            (assert (some? title))
          res (with-out-str (switch-focus :title title))]
      {"status" 200 "res" res})
    (catch Throwable t
      (log/error "focus-game: Error" (ex-message t) t)
      {"error" (ex-message t)})))
