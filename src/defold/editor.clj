(ns defold.editor
  (:require [babashka.process :refer [shell check]]
            [clojure.string :as string]
            [babashka.http-client :as http]
            [cheshire.core :as json]))

(defn- command-exists? [cmd]
  (try
    (check (shell {:out :string :err :string} "which" cmd))
    true
    (catch Exception _ false)))

(defn- extract-port [line]
  (->>
    (string/split line #" ")
    (filter not-empty)
    (map #(re-find #".*:(\d+)$" %))
    (filter some?)
    (first)
    (last)))

(defn- find-port-from-command [& cmd]
  (-> (apply shell {:out :string} cmd)
    :out
    (string/split-lines)
    (->> (filter #(string/includes? % "java")))
    (first)
    (extract-port)))

(defn find-port []
  (cond
    (command-exists? "lsof")
    (find-port-from-command "lsof" "-nP" "-iTCP" "-sTCP:LISTEN")

    (command-exists? "ss")
    (find-port-from-command "ss" "-tplH4")

    :else (throw (ex-info "Couldn't find either 'lsof' or 'ss', which is necessary to interact with Defold" {}))))

(defn make-command-url [port cmd]
  (str "http://127.0.0.1:" port "/command/" (string/lower-case cmd)))

(defn list-commands []
  (try
    (let [port (find-port)
          url  (make-command-url port "")]
      (->
        (http/get url)
        :body
        (json/parse-string)))
    (catch Exception e {"error" (ex-message e)})))

(defn send-command [cmd]
  (try
    (let [port (find-port)
          url  (make-command-url port cmd)]
      {"status" (:status (http/post url))})
    (catch Exception e {"error" (ex-message e)})))

