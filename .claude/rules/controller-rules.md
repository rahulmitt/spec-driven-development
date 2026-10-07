---
paths:
  - "src/main/java/**/controller/**"
---

You are editing controller layer code.

@RestController — handle HTTP and input validation only.
Controllers are THIN — delegate to a @Service immediately.
NEVER put business logic in controllers.
NEVER call a repository directly.
Constructor injection only — no field @Autowired.
Use DTOs (records) from dto/, never JPA entities from model/, over HTTP.
@Valid on all request bodies.
Status codes: 201 create, 200 query, 400 validation, 404 not found.
Map domain exceptions (from exception/) to HTTP HERE and nowhere else —
in a @RestControllerAdvice inside controller/.
Never swallow exceptions or leak infrastructure details.
Test with @WebMvcTest (one controller).
