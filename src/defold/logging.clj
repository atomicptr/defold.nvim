(ns defold.logging
  (:require
   [babashka.fs :as fs]
   [defold.utils :refer [cache-dir]]
   [taoensso.timbre :as log]
   [taoensso.timbre.appenders.core :as appenders]))

(defn- setup! [log-to-stdout?]
  (let [file (cache-dir "defold.nvim" "bb.log")]
    (fs/create-dirs (fs/parent file))
    (log/merge-config! {:level :debug
                        :appenders {:println {:enabled? log-to-stdout?}
                                    :spit (appenders/spit-appender {:fname (cache-dir "defold.nvim" "bb.log")})}})))

(defn setup-with-stdout-logging! []
  (setup! true))

(defn setup-with-file-logging-only! []
  (setup! false))
