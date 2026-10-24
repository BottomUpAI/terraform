#!/usr/bin/env bash
# Checks the live site and DNS against what this repo declares.
# Prints "ok <check>" per passing check; exits non-zero on the first failure.
set -euo pipefail

DOMAIN="bottomuplabs.ai"
NAMESERVERS="ns-1347.awsdns-40.org. ns-1881.awsdns-43.co.uk. ns-323.awsdns-40.com. ns-764.awsdns-31.net."

fail() {
  echo "FAIL $1: $2"
  exit 1
}

ok() {
  echo "ok $1"
}

# Response headers of a GET, lowercased, without carriage returns.
headers() {
  curl -sS --max-time 20 -o /dev/null -D - "$1" | tr -d '\r' | tr '[:upper:]' '[:lower:]'
}

status_of() {
  awk 'NR == 1 { print $2 }' <<<"$1"
}

header_of() {
  awk -v name="$2:" '$1 == name { sub(/^[^ ]+ /, ""); print; exit }' <<<"$1"
}

# 1. Plain HTTP is redirected to HTTPS.
h=$(headers "http://$DOMAIN/")
[[ $(status_of "$h") == 301 ]] || fail http-to-https "status $(status_of "$h")"
[[ $(header_of "$h" location) == "https://$DOMAIN/" ]] || fail http-to-https "location $(header_of "$h" location)"
ok http-to-https

# 2. www is redirected to the apex, keeping path and query.
h=$(headers "https://www.$DOMAIN/about?x=1")
[[ $(status_of "$h") == 301 ]] || fail www-to-apex "status $(status_of "$h")"
[[ $(header_of "$h" location) == "https://$DOMAIN/about?x=1" ]] || fail www-to-apex "location $(header_of "$h" location)"
ok www-to-apex

# 3. Missing pages are real 404s, and carry the security headers.
h=$(headers "https://$DOMAIN/definitely-missing-page")
[[ $(status_of "$h") == 404 ]] || fail not-found "status $(status_of "$h")"
ok not-found
for name in strict-transport-security content-security-policy referrer-policy; do
  [[ -n $(header_of "$h" "$name") ]] || fail security-headers "missing $name"
done
[[ $(header_of "$h" x-content-type-options) == nosniff ]] || fail security-headers "x-content-type-options $(header_of "$h" x-content-type-options)"
[[ $(header_of "$h" x-frame-options) == deny ]] || fail security-headers "x-frame-options $(header_of "$h" x-frame-options)"
ok security-headers

# 4. No geo restriction. CI can't request from abroad, so read the config.
id=$(aws cloudfront list-distributions --output text \
  --query "DistributionList.Items[?contains(Aliases.Items, '$DOMAIN')].Id")
[[ -n $id && $id != None ]] || fail geo-restriction "no distribution with alias $DOMAIN"
geo=$(aws cloudfront get-distribution-config --id "$id" --output text \
  --query "DistributionConfig.Restrictions.GeoRestriction.RestrictionType")
[[ $geo == none ]] || fail geo-restriction "restriction type $geo"
ok geo-restriction

# 5. Delegation still points at the registrar-created zone.
ns=$(dig +short NS "$DOMAIN" | sort | xargs)
[[ $ns == "$NAMESERVERS" ]] || fail nameservers "got: $ns"
ok nameservers

# 6. Mail records match email.tf.
mx=$(dig +short MX "$DOMAIN" | sort | xargs)
[[ $mx == "10 us1-smtp.messagingengine.com. 20 us2-smtp.messagingengine.com." ]] || fail mx "got: $mx"
ok mx
dig +short TXT "$DOMAIN" | grep -qxF '"v=spf1 include:spf.messagingengine.com ?all"' || fail spf "no matching TXT record"
ok spf
dkim=$(dig +short CNAME "fm1._domainkey.$DOMAIN")
[[ $dkim == "fm1.$DOMAIN.dkim.fmhosted.com." ]] || fail dkim "got: $dkim"
ok dkim
