--[[
  Generated with github.com/astrochili/defold-annotations
  Defold 1.11.0

  HTTP API documentation

  Functions for performing HTTP and HTTPS requests.
--]]

---@meta
---@diagnostic disable: lowercase-global
---@diagnostic disable: missing-return
---@diagnostic disable: duplicate-doc-param
---@diagnostic disable: duplicate-set-field
---@diagnostic disable: args-after-dots

---@class defold_api.http
http = {}

---Perform a HTTP/HTTPS request.
--- If no timeout value is passed, the configuration value "network.http_timeout" is used. If that is not set, the timeout value is `0` (which blocks indefinitely).
---@param url string target url
---@param method string HTTP/HTTPS method, e.g. "GET", "PUT", "POST" etc.
---@param callback fun(self, id, response) response callback function
---
---`self`
---object The script instance
---`id`
---hash Internal message identifier. Do not use!
---`response`
---table The response data. Contains the fields:
---
---
---- number `status`: the status of the response
---- string `response`: the response data (if not saved on disc)
---- table `headers`: all the returned headers (if status is 200 or 206)
---- string `path`: the stored path (if saved to disc)
---- string `error`: if any unforeseen errors occurred (e.g. file I/O)
---- number `bytes_received`: the amount of bytes received/sent for a request, only if option `report_progress` is true
---- number `bytes_total`: the total amount of bytes for a request, only if option `report_progress` is true
---- number `range_start`: the start offset into the requested file
---- number `range_end`: the end offset into the requested file (inclusive)
---- number `document_size`: the full size of the requested file
---
---@param headers? table optional table with custom headers
---@param post_data? string optional data to send
---@param options? table optional table with request parameters. Supported entries:
---
---- number `timeout`: timeout in seconds
---- string `path`: path on disc where to download the file. Only overwrites the path if status is 200.  Path should be absolute
---- boolean `ignore_cache`: don't return cached data if we get a 304.  Not available in HTML5 build
---- boolean `chunked_transfer`: use chunked transfer encoding for https requests larger than 16kb. Defaults to true.  Not available in HTML5 build
---- boolean `report_progress`: when it is true, the amount of bytes sent and/or received for a request will be passed into the callback function
---
function http.request(url, method, callback, headers, post_data, options) end

return http