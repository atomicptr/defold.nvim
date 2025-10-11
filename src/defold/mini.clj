; This file is part of mini - One file, no dependency .ini parse for Clojure
;
; Github: https://github.com/atomicptr/mini
;
; Copyright (c) 2025 Christopher Kaster <me@atomicptr.de>
;
; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the "Software"), to deal
; in the Software without restriction, including without limitation the rights
; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:
;
; The above copyright notice and this permission notice shall be included in all
; copies or substantial portions of the Software.
;
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
; SOFTWARE.

(ns dev.atomicptr.mini
  (:require
   [clojure.string :as string]))

(set! *warn-on-reflection* true)

(defn- lexer-error [message pos]
  (throw (ex-info (format "Lexer Error: %s" message) {:position pos})))

(defn- lexer [source]
  (let [source (string/trim source)
        data   (vec source)
        len    (count data)]
    (loop [current 0
           tokens  []]
      (if (>= current len)
        (conj tokens [:eof])
        (let [c (nth data current)
              [token new-current]
              (case c
                (\space \return \tab) [nil (inc current)]
                \newline [[:newline current] (inc current)]
                \[ [[:lbracket current] (inc current)]
                \] [[:rbracket current] (inc current)]
                \= [[:equal current] (inc current)]
                \. [[:dot current] (inc current)]
                \; (loop [curr (inc current)]
                     (if (or (>= curr len) (= \newline (nth data curr)))
                       [[:newline curr] (inc curr)]
                       (recur (inc curr))))

                ; parse strings
                \" (let [start (inc current)
                         [end found]
                         (loop [curr start]
                           (if (>= curr len)
                             [curr false]
                             (if (= \" (nth data curr))
                               [curr true]
                               (recur (inc curr)))))]
                     (if found
                       [[:string (string/join (subvec data start end)) current]
                        (inc end)]
                       (lexer-error "Unterminated string" current)))

                (let [start current
                      [ident-str new-current]
                      (loop [curr current
                             chars []]
                        (if (or (>= curr len)
                                (let [c (nth data curr)]
                                  (or (= c \=) (= c \;) (= c \newline) (= c \]) (= c \[))))
                          [(string/join chars) curr]
                          (recur (inc curr) (conj chars (nth data curr)))))]
                  [[:ident (string/trim ident-str) start] new-current]))]
          (recur new-current (if token (conj tokens token) tokens)))))))

(defn- parser-error [message pos]
  (throw (ex-info (format "Parser Error: %s" message) {:position pos})))

(defn- expect-token [tokens token-type]
  (let [token   (first tokens)
        toktype (first token)
        pos     (last token)]
    (cond
      (empty? tokens)
      (parser-error "Unexpected end of file" pos)

      (and (not (coll? token-type))
           (not= toktype token-type))
      (parser-error (format "Expected token %s but found %s instead" token-type toktype) pos)

      (and (coll? token-type)
           (not (some #(= toktype %) token-type)))
      (parser-error (format "Expected token %s but found %s instead" token-type toktype) pos)

      :else
      (rest tokens))))

(defn- consume-token
  ([tokens] (consume-token tokens nil))
  ([tokens token-type]
   (let [token   (first tokens)
         value   (second token)]
     [value (if token-type
              (expect-token tokens token-type)
              (rest tokens))])))

(defn- peek-token [tokens]
  (if (empty? tokens)
    nil
    (ffirst tokens)))

(defn- parse-tokens [tokens]
  (loop [tokens tokens
         result {}
         current-section nil
         error nil]
    (when error
      (parser-error (:msg error) (:pos error)))
    (if (empty? tokens)
      result
      (let [token              (first tokens)
            [token-type value] token
            pos                (last token)]
        (case token-type
          :lbracket (let [[ident tokens] (consume-token (rest tokens) :ident)
                          tokens         (expect-token tokens  :rbracket)
                          tokens         (expect-token tokens  [:newline :eof])]
                      (recur tokens result (string/split ident #"\.") nil))

          (:ident :string)
          (let [k value
                tokens (expect-token (rest tokens) :equal)
                [v tokens] (case (peek-token tokens)
                             :ident  (consume-token tokens)
                             :string (consume-token tokens)
                             (parser-error (format "Unexpected token: %s" (ffirst tokens)) (last (first tokens))))
                tokens     (expect-token tokens [:newline :eof])]
            (if current-section
              (recur tokens (assoc-in result (concat current-section [k]) v) current-section nil)
              (recur tokens (assoc result k v) current-section nil)))

          :newline
          (recur (rest tokens) result current-section nil)

          :eof result

          (recur (rest tokens) result nil {:msg (format "Unexpected token: %s" token-type)
                                           :pos pos}))))))

(defn parse-string
  "Parses .ini string to a Clojure map"
  [^String source]
  (parse-tokens (lexer source)))
