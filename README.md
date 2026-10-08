# A background re-render that ends in a redirect is cached without `Location`

Minimal Next.js repro (no other dependencies) for two Cache Components behaviours. Both reproduce on 16.2.3, 16.2.12, 16.3.8, 16.4.0 and 16.5.0-canary.3, with `cacheComponents: true`, the default cache handlers, and `next build && next start` (Turbopack and `--webpack` alike).

```bash
npm install
npm run repro
```

`repro.sh` builds, starts the server on `PORT` (default 3201), runs the scenarios with `curl` and prints status, `x-nextjs-cache` and `Location`.

The app has one optional catch-all page (`app/[[...uri]]/page.tsx`). It reads a `'use cache'` + `cacheLife('max')` node lookup. With no node, it reads a redirect lookup tagged `redirect:{uri}` and calls `permanentRedirect(target)`, or `notFound()`. Data comes from `data/*.json`, and `GET /api/revalidate/?tag=…[&expire=1]` calls `revalidateTag(tag, 'max' | { expire: 0 })`.

## B1: a stale-while-revalidate render that ends in `permanentRedirect()` is cached as 308 without `Location`

1. Request `/b1/` twice: `404 MISS`, then `404 HIT`.
2. Add a redirect `/b1/` → `/a/` to the data and call `revalidateTag('redirect:/b1/', 'max')`.
3. Request `/b1/` again: `404 STALE` (expected), and the page re-renders in the background.
4. **Every later request is `308 HIT` with no `Location` header.** `.next/server/app/b1.meta` stores `"status":308` and no `location`.

```
/b1/   HTTP/1.1 404 Not Found x-nextjs-cache: MISS
/b1/   HTTP/1.1 404 Not Found x-nextjs-cache: HIT
/b1/   HTTP/1.1 404 Not Found x-nextjs-cache: STALE
/b1/   HTTP/1.1 308 Permanent Redirect x-nextjs-cache: HIT
/b1/   HTTP/1.1 308 Permanent Redirect x-nextjs-cache: HIT
```

Control: the same steps with `revalidateTag(tag, { expire: 0 })` (a blocking render) give `308 MISS`, then `308 HIT`, both with `location: /a/`.

**Cause:** `prerenderToStream` (`packages/next/src/server/app-render/app-render.tsx`) records headers by reading them back: `metadata.headers[name] = res.getHeader(name)`. A background re-render runs on the response that already served the stale entry. `patchSetHeaderWithCookieSupport` makes `setHeader` a no-op once `headersSent` is true, so `location` is lost while `metadata.statusCode = 308` is kept. This is the root cause of vercel/next.js#98600. Recording the value directly, as vercel/next.js#99220 does, fixes this repro too (checked by patching the canary bundle).

`trace-location.js` (loaded by `repro.sh` through `NODE_OPTIONS`) logs each `setHeader('location')` call with `headersSent`.

## B2: `revalidateTag(tag, 'max')` cancels an earlier `revalidateTag(tag, { expire: 0 })`

1. Request `/n2/` twice: `200 MISS Old`, then `HIT Old`.
2. Change the data to `New`.
3. Call `revalidateTag('node:/n2/', { expire: 0 })`, then `revalidateTag('node:/n2/', 'max')`.
4. Request `/n2/`: `STALE Old`. Expected: a blocking `MISS New`, which is what `{ expire: 0 }` alone gives.

**Cause:** `FileSystemCache.revalidateTag` and the default `'use cache'` handler's `updateTags` set `expired = now + durations.expire * 1000` unconditionally. A later, longer profile therefore replaces a pending immediate expiry.
