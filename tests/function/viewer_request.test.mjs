// Tests for the CloudFront viewer-request function. The function runs in the
// cloudfront-js-2.0 runtime, which has no module system, so we load its source
// and pull `handler` out of it.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const src = readFileSync(
  new URL("../../modules/static_site/function/viewer_request.js", import.meta.url),
  "utf8",
);
const handler = new Function(`${src}\nreturn handler;`)();

// Builds an event in the cloudfront-js-2.0 shape.
function ev(host, uri, querystring = {}) {
  return {
    request: {
      method: "GET",
      uri,
      querystring,
      headers: { host: { value: host } },
      cookies: {},
    },
  };
}

test("www redirects to apex preserving path and query", () => {
  const res = handler(ev("www.bottomuplabs.ai", "/about", { x: { value: "1" } }));
  assert.equal(res.statusCode, 301);
  assert.equal(res.headers.location.value, "https://bottomuplabs.ai/about?x=1");
});

test("www root redirect", () => {
  const res = handler(ev("www.bottomuplabs.ai", "/"));
  assert.equal(res.statusCode, 301);
  assert.equal(res.headers.location.value, "https://bottomuplabs.ai/");
});

// The runtime passes query keys and values exactly as the client sent them,
// still percent-encoded, so the redirect must not encode them again.
test("www redirect keeps multi-value and encoded query parameters", () => {
  const res = handler(
    ev("www.bottomuplabs.ai", "/", {
      tag: { value: "a", multiValue: [{ value: "a" }, { value: "b%20c" }] },
    }),
  );
  assert.equal(res.headers.location.value, "https://bottomuplabs.ai/?tag=a&tag=b%20c");
});

test("www redirect does not re-encode already-encoded values", () => {
  const res = handler(
    ev("www.bottomuplabs.ai", "/about", {
      q: { value: "a%2Fb%26c%3Dd" },
      y: { value: "%C3%A9" },
      s: { value: "a+b" },
    }),
  );
  assert.equal(res.headers.location.value, "https://bottomuplabs.ai/about?q=a%2Fb%26c%3Dd&y=%C3%A9&s=a+b");
});

test("directory index rewrite", () => {
  const cases = {
    "/": "/index.html",
    "/about/": "/about/index.html",
    "/about": "/about/index.html",
    "/posts/collusion": "/posts/collusion/index.html",
  };
  for (const [uri, expected] of Object.entries(cases)) {
    const res = handler(ev("bottomuplabs.ai", uri));
    assert.equal(res.statusCode, undefined, `${uri} should not redirect`);
    assert.equal(res.uri, expected, uri);
  }
});

test("files untouched", () => {
  for (const uri of ["/style.css", "/og/collusion.png", "/resume.pdf", "/.well-known/security.txt"]) {
    assert.equal(handler(ev("bottomuplabs.ai", uri)).uri, uri);
  }
});

test("apex query preserved on rewrite", () => {
  const qs = { utm_source: { value: "linkedin" } };
  const res = handler(ev("bottomuplabs.ai", "/about", qs));
  assert.equal(res.uri, "/about/index.html");
  assert.deepEqual(res.querystring, qs);
});
