# app_subject_pages

LOD infrastructure for stad.gent.

To test locally you can use the following query to get relevant URIs:
```sparql
select distinct ?Concept where {?Concept a <http://data.vlaanderen.be/ns/toestemming#VerwerkingsActiviteit>} LIMIT 100
```

Then replace https://qa.stad.gent with http://localhost to get a uri like http://localhost/id/data-processing/activities/06d21c71-2ca7-e911-80e6-005056935251
