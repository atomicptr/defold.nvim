(ns defold.logging
  (:require
   [defold.utils :refer [cache-dir]]
   [taoensso.timbre :as log]
   [taoensso.timbre.appenders.core :as appenders]))

(defn- setup! [log-to-stdout?]
  (log/merge-config! {:level :debug
                      :appenders {:println {:enabled? log-to-stdout?}
                                  :spit (appenders/spit-appender {:fname (cache-dir "defold.nvim" "bb.log")})}}))

(defn setup-with-stdout-logging! []
  (setup! true))

(defn setup-with-file-logging-only! []
  (setup! false))
