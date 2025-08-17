(ns defold.focus
  (:require
   [babashka.fs :as fs]
   [com.brainbot.iniconfig :as iniconfig]
   [defold.constants :refer [base-class-name]]
   [defold.utils :refer [command-exists? determine-os project-id run-shell]]
   [taoensso.timbre :as log]))

(defn switch-focus [type name]
  (when (not-any? #(= % type) [:class :title :app-name])
    (throw (ex-info (format "Unknown switcher type: %s" type) {:type type})))

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
          (throw (ex-info (format "Unknown switcher type for hyprctl: %s" type) {:type type}))))

      (command-exists? "swaymsg")
      (run-shell
        "swaymsg"
        (format
          "'[%s=%s] focus'"
          (case type
            :class "class"
            :title "title"
            (throw (ex-info (format "Unknown switcher type for swaymsg: %s" type) {:type type})))
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
          (throw (ex-info (format "Unknown switcher type for xdotool: %s" type) {:type type})))
        name
        "windowactivate")

      :else
      (log/error "No supported focus switcher for Linux found, do nothing..."))

    :mac
    (cond
      (command-exists? "osascript")
      (case type
        :app-name
        (run-shell
          "osascript"
          "-e"
          (format "'tell application \"System Events\" to tell process \"%s\" to set frontmost to true'" name))
        (throw (ex-info (format "Unknown switcher type for osascript: %s" type) {:type type})))

      :else
      (log/error "No supported focus switcher for MacOS found, do nothing..."))

    :windows
    (cond

      :else
      (log/error "No supported focus switcher for Windows found, do nothing..."))))

(defn focus-neovim [root-dir]
  (try
    (assert (some? root-dir))
    (assert (fs/exists? (fs/path root-dir "game.project")))
    (case (determine-os)
      :linux
      (let [class-name (format base-class-name (project-id root-dir))
            res (with-out-str (switch-focus :class class-name))]
        {"status" 200 "res" res})

      {"status" 200 "res" (format "not supported on os: %s" (determine-os))})

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
          _            (assert (some? title))]
      (case (determine-os)
        :linux
        (let [res (with-out-str (switch-focus :title title))]
          {"status" 200 "res" res})

        :mac
        (let [res (with-out-str (switch-focus :app-name title))]
          {"status" 200 "res" res})

        {"status" 200 "res" (format "not supported on os: %s" (determine-os))}))

    (catch Throwable t
      (log/error "focus-game: Error" (ex-message t) t)
      {"error" (ex-message t)})))
