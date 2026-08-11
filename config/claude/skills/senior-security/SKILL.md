---
name: senior-security
description: Comprehensive security engineering skill for application security, penetration testing, security architecture, and compliance auditing. Includes security assessment tools, threat modeling, crypto implementation, and security automation.
version: 1.0.0
author: example-org Team
triggers:
  - security audit
  - secure code
  - penetration test
  - vulnerability check
  - threat model
  - compliance
---

# Senior Security Skill

## When to Use

Use this skill for:
- Designing security architecture
- Conducting penetration tests
- Implementing cryptography
- Performing security audits
- Ensuring compliance

## Areas of Expertise

### Application Security
- Input validation and sanitization
- Authentication and authorization
- Session management
- Secure API design

### Cryptography
- Proper encryption implementation
- Key management
- Hashing and salting
- TLS/SSL configuration

### Vulnerability Assessment
- OWASP Top 10 awareness
- Common vulnerability patterns
- Code review for security
- Dependency scanning

### Compliance
- GDPR, CCPA data protection
- SOC 2 requirements
- Industry-specific regulations
- Security policies

## Security Checklist

### Input Validation
- [ ] Validate all inputs server-side
- [ ] Use allowlists, not denylists
- [ ] Sanitize output to prevent XSS
- [ ] Prevent SQL injection with parameterized queries

### Authentication
- [ ] Use strong password policies
- [ ] Implement MFA where possible
- [ ] Secure token storage
- [ ] Proper session timeout handling

### Authorization
- [ ] Implement RBAC or ABAC
- [ ] Validate permissions on every request
- [ ] Principle of least privilege
- [ ] Prevent IDOR vulnerabilities

### Data Protection
- [ ] Encrypt sensitive data at rest
- [ ] Use HTTPS for all communications
- [ ] Secure secrets management
- [ ] Proper logging without sensitive data

## Anti-Patterns

- DON'T roll your own crypto
- DON'T trust client-side validation
- DON'T log sensitive data
- DON'T hardcode secrets
- DON'T ignore security warnings
