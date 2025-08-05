(ns defold.editor
  (:require
   [babashka.http-client :as http]
   [babashka.process :refer [shell]]
   [cheshire.core :as json]
   [clojure.string :as string]
   [defold.utils :refer [command-exists?]]))

(defn make-command-url [port cmd]
  (str "http://127.0.0.1:" port "/command/" (string/lower-case cmd)))

(defn- is-defold-port? [port]
  (try (let [res    (http/head (make-command-url port "") {:timeout 100})
             status (:status res)]
         (= status 200))
       (catch Exception _ false)))

(defn- extract-port-generic [line]
  (->>
    (string/split line #" ")
    (filter not-empty)
    (map #(re-find #".*:(\d+)$" %))
    (filter some?)
    (first)
    (last)))

(defn- find-port-generic [& cmd]
  (try
    (-> (apply shell {:out :string} cmd)
      :out
      (string/split-lines)
      (->> (filter #(string/includes? % "java")))
      (->> (map extract-port-generic))
      (->> (filter is-defold-port?))
      (first))
    (catch Exception _ (throw (ex-info (str "Could not find Defold port via '" (string/join " " cmd) "'.") {})))))

(defn- find-port-netstat []
  (some #(when (is-defold-port? %) %)
    (-> (shell {:out :string :err :string} "netstat" "-anv")
      :out
      (string/split-lines)
      (->> (filter #(string/includes? % "LISTEN")))
      (->> (map #(string/split % #" ")))
      (->> (filter #(= (first %) "tcp")))
      (flatten)
      (->> (map #(re-find #".*:(\d+)$" %)))
      (->> (map second))
      (->> (filter some?))
      (->> (map Integer/parseInt))
      (->> (sort >)))))

(defn find-port []
  (cond
    (command-exists? "lsof")
    (find-port-generic "lsof" "-nP" "-iTCP" "-sTCP:LISTEN")

    (command-exists? "ss")
    (find-port-generic "ss" "-tplH4")

    (command-exists? "netstat")
    (find-port-netstat)

    :else (throw (ex-info "Couldn't find either 'lsof', 'ss' or 'netstat', which is necessary to interact with Defold" {}))))

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

