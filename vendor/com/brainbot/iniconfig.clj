(ns com.brainbot.iniconfig
  (:import [java.io StringReader])
  (:require
   [clojure.string :as string]
   [clojure.java.io :as io]))


(defn- parse-comment-line
  [line]
  (if-let [match (re-find #"^\s*(#.*)?$", line)]
    {:type :comment}))


(defn- parse-continuation-line
  [line]
  (if-let [match (re-find #"^\s+.*$", line)]
    {:type :continuation :value match}))
;; (parse-continuation-line "    foobar hello #b:a")


(defn- parse-section-line
  [line]
  (if-let [match (re-find #"^\[([^]]*)\]\s*(#.*)?$" line)]
    {:type :section :name (nth match 1)}))


(defn- parse-assignment-line
  [line]
  (if-let [match (re-find #"^(\S[^=]*)=(.*)$" line)]
    {:type :assignment
     :name (nth match 1)
     :value (nth match 2)}))


(defn- parse-line
  [line lineno]
  (assoc
      (or (parse-comment-line line)
          (parse-continuation-line line)
          (parse-section-line line)
          (parse-assignment-line line)
          {:type :error})
    :lineno lineno
    :line line))


(defmulti ^:private handle-line
  (fn [current-state line]
    (:type line)))

(defmethod handle-line :comment
  [current-state line]
  current-state)

(defmethod handle-line :assignment
  [{:keys [retval section variable raise] :as current-state} line]
  (let [variable (string/trim (:name line))]
    (cond
      (not section)
        (raise "assignment before first section")
      (get-in retval [section variable])
        (raise "duplicate assignment")
      :else
        (assoc current-state
          :retval (assoc-in retval [section variable] (string/trim (:value line)))
          :variable variable))))

(defmethod handle-line :continuation
  [{:keys [retval section variable raise] :as current-state} line]
  (if variable
    (assoc current-state
      :retval (assoc-in retval [section variable]
                        (string/join "\n" [(get-in retval [section variable]),
                                           (string/trimr (:value line))])))
    (raise "bad continuation")))

(defmethod handle-line :section
  [{:keys [retval section variable raise] :as current-state} line]
  (let [section-name (string/trim (:name line))]
    (cond
      (= "" section-name)
        (raise "empty section name")
      (contains? retval section-name)
        (raise "duplicate section name")
      :else
        (assoc current-state
          :retval (assoc retval section-name {})
          :section section-name
          :variable nil))))

(defmethod handle-line :error
  [{:keys [retval section variable raise] :as current-state} line]
  (raise "cannot parse"))


(defmethod handle-line :default
  [{:keys [retval section variable raise] :as current-state} line]
  (raise "internal error"))


(defn- wrap-handle-line
  [meta-info current-state line]
  (handle-line
   (assoc current-state
     :raise (fn [msg]
              (throw (ex-info
                      (str msg " in line " (:lineno line) " while parsing " (:source meta-info))
                      (merge meta-info (select-keys line [:lineno :line]))))))
   line))


(defn- build-map
  [meta-info parsed-lines]
  (:retval
   (reduce (partial wrap-handle-line meta-info)
           {:retval {} :section nil :variable nil}
           parsed-lines)))


(defn- read-ini-with-meta
  [in meta-info]
  (with-open [reader (io/reader in)]
    (with-meta
      (build-map meta-info (map parse-line (line-seq reader) (rest (range))))
      meta-info)))


(defn read-ini
  "parse .ini file into a map"
  [in]
  (read-ini-with-meta in {:source (str in)}))


(defn read-ini-string
  "parse .ini file from string"
  [s]
  (read-ini-with-meta (StringReader. s) {:source 'string}))
