(ns defold.launcher
  (:require
   [babashka.fs :as fs]
   [babashka.process :refer [shell]]
   [clojure.string :as string]
   [defold.constants :refer [base-class-name]]
   [defold.focus :refer [switch-focus]]
   [defold.neovide :as neovide]
   [defold.utils :refer [cache-dir command-exists? escape-spaces linux?
                         merge-seq-setters project-id run-shell
                         seq-replace-var windows?]]
   [taoensso.timbre :as log]))

(defn- runtime-dir [project-root]
  (let [p (cache-dir "defold.nvim" "runtime" (project-id project-root))]
    (fs/create-dirs p)
    p))

(defn- make-neovim-edit-command [file-name line]
  (if line
    (format "edit +%s %s" line (escape-spaces file-name))
    (format "edit %s" (escape-spaces file-name))))

(defn- launch [launcher classname addr filename line]
  (let [remote-cmd (if line
                     [(format "+%s" line) filename]
                     [filename])
        args       (-> (:args launcher)
                     (seq-replace-var :classname classname)
                     (seq-replace-var :addr addr)
                     (seq-replace-var :remote-cmd remote-cmd)
                     merge-seq-setters
                     flatten)]
    (log/debug "Launch cmd" (:cmd launcher))
    (log/debug "Launch arguments" args)
    (try
      (apply run-shell (:cmd launcher) args)
      (catch Throwable t
        (log/error "Failed to launch:" t)
        (System/exit 1)))))

(defn- run-fsock [launcher neovim root-dir _ filename line edit-cmd]
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
          (launch launcher class-name socket-file filename line)))
      (launch launcher class-name socket-file filename line))))

(defn- win-port-in-use? [port]
  (string/includes? (:out (shell {:out :string} "netstat" "-aon")) (format ":%s" port)))

(defn- win-find-free-port []
  (loop [port (+ 1024 (rand-int (- 65535 1024)))]
    (if (not (win-port-in-use? port))
      port
      (recur (+ 1024 (rand-int (- 65535 1024)))))))

(defn- run-netsock [launcher neovim root-dir class-name filename line edit-cmd]
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
            (launch launcher class-name socket filename line))))
      (launch launcher class-name socket filename line))))

(defn- create-neovide-launcher [cfg neovim]
  (let [args (vec
               (flatten
                 (filter some?
                   ["--neovim-bin" neovim
                    (get-in cfg ["extra_arguments"])
                    (when (linux?)
                      ["--wayland_app_id" :classname
                       "--x11-wm-class" :classname])
                    "--"
                    "--listen" :addr
                    "--remote" :remote-cmd])))]
    (cond
      ; custom executable
      (and (some? (cfg "executable")) (fs/exists? (cfg "executable")))
      {:cmd (cfg "executable")
       :args args}

      ; command already installed
      (command-exists? "neovide")
      {:cmd (str (fs/which "neovide"))
       :args args}

      :else
      {:cmd (let [neovide (neovide/executable-path)]
              (when-not neovide
                (throw (ex-info "Could not find neovide, have you installed it?" {})))
              neovide)
       :args args})))

(def ^:private default-terminals
  [["ghostty" "--class=" "-e"]
   ["foot" "--app-id=" "-e"]
   ["kitty" "--class=" "-e"]
   ["alacritty" "--class=" "-e"]
   ["st" "-c" "-e"]])

(defn- create-terminal-launcher [cfg neovim]
  (let [class-arg (get-in cfg ["terminal" "class_argument"])
        run-arg   (or (get-in cfg ["terminal" "run_argument"]) "-e")
        nvim-args (filter some? ["--listen" :addr "--remote" :remote-cmd])]
    (cond
      ; custom executable
      (and (some? (cfg "executable")) (fs/exists? (cfg "executable")))
      {:cmd (cfg "executable")
       :args (filter some?
               (flatten
                 (concat
                   [(when class-arg [class-arg :classname])
                    run-arg neovim]
                   (cfg "extra_arguments")
                   nvim-args)))}

      ; check default terminals
      (some #(command-exists? (first %)) default-terminals)
      (let [[term class-arg run-arg] (some #(when (command-exists? (first %)) %) default-terminals)]
        {:cmd term
         :args (flatten (concat [class-arg :classname run-arg neovim] nvim-args))})

      :else
      (throw (ex-info "Could not find a supported terminal launcher" {})))))

(defn- create-launcher [cfg neovim]
  (case (cfg "type")
    "neovide"  (create-neovide-launcher cfg neovim)
    "terminal" (create-terminal-launcher cfg neovim)
    (throw (ex-info (format "Unknown launcher type: %s" (cfg "type")) {:launcher-config cfg}))))

(defn run [launcher-config root-dir file-name line]
  (let [neovim      (str (fs/which "nvim"))
        launcher    (create-launcher launcher-config neovim)
        line        (when line (Integer/parseInt line))
        class-name  (format base-class-name (project-id root-dir))
        edit-cmd    (make-neovim-edit-command file-name line)]
    (when (or (nil? (:cmd launcher)) (not (command-exists? (:cmd launcher))))
      (log/error "Could not create launcher" (:cmd launcher) launcher-config)
      (System/exit 1))
    (when (not (command-exists? neovim))
      (log/error "Could not find neovim" neovim)
      (System/exit 1))
    (cond
      (windows?) (run-netsock launcher neovim root-dir class-name file-name line edit-cmd)
      :else      (run-fsock   launcher neovim root-dir class-name file-name line edit-cmd))
    (switch-focus :class class-name)))
