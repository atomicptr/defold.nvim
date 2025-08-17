(ns defold.focus
  (:require
   [babashka.fs :as fs]
   [com.brainbot.iniconfig :as iniconfig]
   [defold.constants :refer [base-class-name]]
   [defold.utils :refer [command-exists? determine-os project-id run-shell]]
   [taoensso.timbre :as log]))

(defn switch-focus [type name]
  (when (not-any? #(= % type) [:class :title])
    (throw (ex-info (format "Unknown type: %s" type) {})))
  (log/info "Switching to:" type name)
  (case (determine-os)
    :linux
    (cond
      (command-exists? "hyprctl")
      (run-shell
        "hyprctl"
        "dispatch"
        "focuswindow"
        (case type
          :class (format "class:%s" name)
          :title (format "title:%s" name)
          (throw (ex-info "Unknonw type: %s" type))))

      (command-exists? "swaymsg")
      (run-shell
        "swaymsg"
        (format
          "'[%s=%s] focus'"
          (case type
            :class "class"
            :title "title"
            (throw (ex-info "Unknonw type: %s" type)))
          name))

      (command-exists? "wmctrl")
      (run-shell
        "wmctrl"
        (when (= type :class) "-x")
        "-a"
        name)

      (command-exists? "xdotool")
      (run-shell
        "xdotool"
        "search"
        (case type
          :class "--class"
          :title "--title"
          (throw (ex-info "Unknonw type: %s" type)))
        name
        "windowactivate")

      :else
      (log/error "No supported focus switcher found, do nothing..."))

    :mac
    (cond

      :else
      (log/error "No supported focus switcher found, do nothing..."))

    :windows
    (cond

      :else
      (log/error "No supported focus switcher found, do nothing..."))))

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
