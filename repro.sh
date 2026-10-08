#!/bin/bash
# Usage: npm run repro  (or: PORT=3201 bash repro.sh)
# Builds and starts the repro, then runs the scenarios for both behaviours.
D="$(cd "$(dirname "$0")" && pwd)"; PORT="${PORT:-3201}"
H=http://localhost:$PORT
cd "$D"
echo '{}' > data/nodes.json
echo '{}' > data/redirects.json
rm -rf .next
npx next build > build.log 2>&1 || { echo "BUILD FAILED"; tail -30 build.log; exit 1; }
NODE_OPTIONS="--require $D/trace-location.js" npx next start -p $PORT > server.log 2>&1 &
SRV=$!
for i in $(seq 1 50); do curl -s -o /dev/null "$H/a/" && break; sleep 0.2; done

setjson() { node -e 'const fs=require("fs");const [f,k,v]=process.argv.slice(1);const o=JSON.parse(fs.readFileSync(f,"utf8"));if(v==="null")delete o[k];else o[k]=v;fs.writeFileSync(f,JSON.stringify(o))' "data/$1" "$2" "$3"; }
show() { printf '  %-6s ' "$1"; curl -s -D - -o body.tmp "$H$1" | grep -iE '^HTTP|x-nextjs-cache|^location' | tr -d '\r' | tr '\n' ' '; grep -o '<h1>[^<]*</h1>' body.tmp | head -1; echo; }
rev() { curl -s -o /dev/null "$H/api/revalidate/?tag=$1${2:+&expire=1}"; }
meta() { f=".next/server/app${1%/}.meta"; [ -f "$f" ] && echo "  meta: $(cat "$f")"; }

echo "== Next $(node -p "require('next/package.json').version")"

echo "-- B1: background (stale) render ends in permanentRedirect()  [revalidateTag(tag,'max')]"
P=/b1/
show $P; sleep 0.5; show $P
setjson redirects.json $P /a/
rev "redirect:$P"
for i in 1 2 3; do show $P; sleep 1; done
meta $P

echo "-- B1 control: blocking render  [revalidateTag(tag,{expire:0})]"
P=/c1/
show $P; sleep 0.5; show $P
setjson redirects.json $P /a/
rev "redirect:$P" 1
for i in 1 2 3; do show $P; sleep 1; done
meta $P

echo "-- B2: {expire:0} then 'max' on the same tag (page content change, no redirect)"
P=/n2/
setjson nodes.json $P Old
show $P; sleep 0.5; show $P
setjson nodes.json $P New
rev "node:$P" 1
rev "node:$P"
for i in 1 2 3; do show $P; sleep 1; done

echo "-- B2 control: {expire:0} only"
P=/n3/
setjson nodes.json $P Old
show $P; sleep 0.5; show $P
setjson nodes.json $P New
rev "node:$P" 1
for i in 1 2; do show $P; sleep 1; done

echo "-- trace (setHeader location calls)"
grep -c '\[trace\] setHeader location' server.log | sed 's/^/  count: /'
grep -iE 'error|threw' server.log | head -5
kill $SRV; sleep 0.5; pkill -f "next start -p $PORT" 2>/dev/null
rm -f body.tmp
