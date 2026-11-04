# app_subject_pages

LOD infrastructure for stad.gent.

To test locally you can use the following query to get relevant URIs:
```sparql
select distinct ?Concept where {?Concept a <http://data.vlaanderen.be/ns/toestemming#VerwerkingsActiviteit>} LIMIT 100
```

Then replace https://qa.stad.gent with http://localhost to get a uri like http://localhost/id/data-processing/activities/06d21c71-2ca7-e911-80e6-005056935251

## SPARQL cache

Requests to `/sparql` go through a Varnish cache (`sparql-cache`, image `redpencil/varnish-post`) before they reach Virtuoso. Other routes (`/sparql-auth`, `/sparql-graph-crud-auth`, `/conductor`, `/data/...`) bypass it.

- **Cache duration:** responses are cached for `CACHE_TTL` (1 hour).
- **After a data load:** restart the cache so the new data shows up right away:
  `docker compose restart sparql-cache` (or `podman-compose restart sparql-cache`).
- **Result formats:** the `Accept` header is part of the cache key, so JSON, XML and CSV results are cached separately. This is why `config/varnish/default.vcl` is mounted. The image's built-in VCL does not do this, so don't remove the mount.
- **Updates:** queries containing update keywords (`INSERT`, `DELETE`, ...) are never cached.
- **Errors:** failed responses are only cached for 30 seconds (`DISABLE_ERROR_CACHING`).
- **Hit or miss:** the `X-Cache: HIT` / `MISS` response header shows whether a response came from the cache.
- **Podman:** use fully qualified image names (`docker.io/...`), because short names don't resolve on our servers.

To test the cache locally, run the same query twice and compare the response times, for example with `curl -w "%{time_total}\n"`.
