// CloudFront viewer-request function (runtime: cloudfront-js-2.0).
//
// 1. www.bottomuplabs.ai -> 301 to the apex, keeping path and query string.
// 2. Directory-style URLs (/about, /about/) are rewritten to their index.html,
//    since the S3 origin has no notion of a directory index.
var APEX = "bottomuplabs.ai";

// Keys and values arrive still percent-encoded, as the client sent them, so
// they are joined back together as-is.
function queryString(qs) {
  var parts = [];
  for (var key in qs) {
    var entry = qs[key];
    var values = entry.multiValue ? entry.multiValue : [entry];
    for (var i = 0; i < values.length; i++) {
      parts.push(key + "=" + values[i].value);
    }
  }
  return parts.length ? "?" + parts.join("&") : "";
}

function handler(event) {
  var request = event.request;
  var host = request.headers.host ? request.headers.host.value : "";

  if (host === "www." + APEX) {
    return {
      statusCode: 301,
      statusDescription: "Moved Permanently",
      headers: {
        location: { value: "https://" + APEX + request.uri + queryString(request.querystring) },
      },
    };
  }

  var uri = request.uri;
  if (uri.endsWith("/")) {
    request.uri = uri + "index.html";
  } else if (uri.split("/").pop().indexOf(".") === -1) {
    request.uri = uri + "/index.html";
  }
  return request;
}
