---
paths:
  - "src/main/java/**/config/**"
---

You are editing configuration code.

config/ holds @Configuration classes and @ConfigurationProperties only.
@ConfigurationProperties are records, validated with @Validated where needed.
NEVER put business logic in configuration — wire beans, nothing more.
Constructor injection only — no field @Autowired.
Never hard-code connection details or secrets; they come from application.properties.
Hibernate stays ddl-auto=validate — never configure schema generation here.