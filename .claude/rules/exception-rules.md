---
paths:
  - "src/main/java/**/exception/**"
---

You are editing domain exception code.

exception/ holds domain exceptions for business rule violations — nothing else.
Unchecked only: extend RuntimeException.
Prefer a sealed hierarchy when a closed set of violations exists.
NEVER import org.springframework.*
NEVER carry HTTP status codes or ResponseEntity — the controller layer maps
exceptions to HTTP in a @RestControllerAdvice inside controller/.
Services throw these; controllers map them; nothing else catches them.
Messages use plain business language — never leak infrastructure details
(SQL, table names, stack traces, class names).