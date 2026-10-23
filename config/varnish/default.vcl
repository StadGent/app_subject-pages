vcl 4.1;

import std;
import bodyaccess;

# this is the backend that should be cached
backend default {
  .host = "$BACKEND_HOST";
  .port = "$BACKEND_PORT";
  .first_byte_timeout = $BACKEND_FIRST_BYTE_TIMEOUT;
}

# remove cookies from response
sub vcl_backend_response {
  if (beresp.http.Cache-Control) {
    unset beresp.http.Cache-Control;
  }

  set beresp.ttl = $CACHE_TTL;

  # handle errors
  if ($DISABLE_ERROR_CACHING && beresp.status >= 400) {
    # send requests directly to the backend for the next ttl period
    set beresp.ttl = $DISABLE_ERROR_CACHING_TTL;
    set beresp.uncacheable = true;
    return (deliver);
  }
}

# remove incoming cookies and allow caching POST requests
sub vcl_recv {
  unset req.http.X-Body-Len;

  if (req.method == "POST") {
    std.cache_req_body($BODY_SIZE);
    set req.http.X-Body-Len = bodyaccess.len_req_body();
    if (req.http.X-Body-Len == "-1") {
      return (pass);
    }
    # SPARQL updates must always hit the backend. Keywords are matched as
    # whole words; a false positive is only a cache miss.
    if (bodyaccess.rematch_req_body("(?i)(^|[^a-z])(insert|delete|clear|drop|load|create|move|copy|add)([^a-z]|$)")) {
      return (pass);
    }
    return (hash);
  }

  if (req.method != "GET" && req.method != "HEAD") {
    return (pass);
  }

  # Same update guard for queries passed via the query string (GET)
  if (req.method == "GET" && req.url ~ "(?i)(^|[^a-z])(insert|delete|clear|drop|load|create|move|copy|add)([^a-z]|$)") {
    return (pass);
  }

  return (hash);
}

sub vcl_hash {
  hash_data(req.url);
  # The response varies with the requested serialization
  hash_data(req.http.Accept);

  # to cache POST and PUT requests
  if (req.http.X-Body-Len) {
    bodyaccess.hash_req_body();
  } else {
    hash_data("");
  }

  return (lookup);
}

sub vcl_backend_fetch {
  if (bereq.http.X-Body-Len) {
    set bereq.method = "POST";
  }
}

# add a header to see if it was a cache miss or a cache hit
sub vcl_deliver {
  if (resp.http.X-Varnish ~ "[0-9]+ +[0-9]+") {
    set resp.http.X-Cache = "HIT";
  } else {
    set resp.http.X-Cache = "MISS";
  }
}
