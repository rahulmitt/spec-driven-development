---
paths:
  - "src/main/java/**/service/**"
---

You are editing service layer code.

@Service — business logic and orchestration.
Services NEVER contain persistence logic — go through a repository/ interface.
NEVER handle HTTP: no ResponseEntity, no status codes, no @RequestMapping.
Throw domain exceptions from exception/ for business rule violations; the controller maps them to HTTP.
Constructor injection only — no field @Autowired.
BigDecimal for ALL monetary values — never float, double, or int.
Explicit RoundingMode.DOWN, scale 2.
BigDecimal.valueOf() or new BigDecimal("...") — NEVER new BigDecimal(double).
Use records for value objects; no Lombok.
Use sealed interfaces and pattern matching where a closed set of variants exists.
Test with plain JUnit 5 + Mockito (repositories mocked, no Spring context), asserting with JUnit 5 Assertions — never AssertJ.
