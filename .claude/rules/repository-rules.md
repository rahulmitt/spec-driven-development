---
paths:
  - "src/main/java/**/repository/**"
  - "src/main/java/**/model/**"
---

You are editing persistence code: repositories and JPA entities.

Repositories are @Repository Spring Data JPA interfaces.
Repositories NEVER contain business logic — queries and data access only.
JPA entities live in model/, never in service/ or dto/.
Entities are classes, not records — JPA needs a no-arg constructor. Give them a
protected no-arg constructor, no Lombok, and no setters beyond what the service needs.
Entities map to tables that already exist: Hibernate is ddl-auto=validate
and NEVER generates schema.
When an entity gains or changes a column, update src/test/resources/schema.sql
in the SAME change — otherwise every @SpringBootTest fails at context startup.
Production DDL is applied out of band (migration script or DBA).
BigDecimal columns for money — DECIMAL(n,2), never FLOAT or DOUBLE.
Test with @DataJpaTest against H2 in MySQL mode.
