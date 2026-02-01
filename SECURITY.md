# Security Considerations for SkullDB

## Important Security Notes

### ⚠️ PRODUCTION REQUIREMENTS

Before deploying SkullDB to production, you **MUST** implement the following security enhancements:

## 1. Authentication & Cryptography

### Current Implementation (Development Only)
- Simple SHA256 password hashing
- Basic token serialization

### Required for Production
Replace the following modules with proper cryptographic implementations:

#### Password Hashing
Replace simple hashing in `lib/skulldb/auth/user.ex`:

```elixir
# CURRENT (INSECURE):
defp hash_password(password) do
  :crypto.hash(:sha256, password) |> Base.encode64()
end

# REPLACE WITH:
defp hash_password(password) do
  Argon2.hash_pwd_salt(password)
end

defp verify_password(user, password) do
  Argon2.verify_pass(password, user.hashed_password)
end
```

Add to `mix.exs`:
```elixir
{:argon2_elixir, "~> 4.0"}
```

#### JWT Token Implementation
Replace basic token in `lib/skulldb/auth/token.ex`:

```elixir
# CURRENT (INSECURE):
token = Base.url_encode64(:erlang.term_to_binary(payload), padding: false)

# REPLACE WITH:
defmodule Skulldb.Auth.Token do
  use Joken.Config

  def generate(user) do
    extra_claims = %{
      user_id: user.id,
      email: user.email,
      metadata: user.metadata
    }

    generate_and_sign!(extra_claims)
  end

  def verify(token) do
    verify_and_validate(token)
  end
end
```

Add to `mix.exs`:
```elixir
{:joken, "~> 2.6"}
```

Configure JWT secret in `config/runtime.exs`:
```elixir
config :joken, default_signer: System.fetch_env!("SKULLDB_JWT_SECRET")
```

## 2. HTTPS/TLS

### Development
HTTP is acceptable for local development.

### Production
**ALWAYS use HTTPS in production**:

1. **Use a reverse proxy** (nginx, Caddy, or cloud load balancer)
2. **Obtain SSL certificates** (Let's Encrypt, AWS Certificate Manager, etc.)
3. **Configure TLS termination**

Example nginx configuration:

```nginx
server {
    listen 443 ssl http2;
    server_name api.yourdomain.com;

    ssl_certificate /etc/ssl/certs/skulldb.crt;
    ssl_certificate_key /etc/ssl/private/skulldb.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        proxy_pass http://localhost:4000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## 3. Rate Limiting

Implement rate limiting to prevent abuse:

```elixir
# Add to mix.exs
{:hammer, "~> 6.2"}

# In HTTP.Server
plug Hammer.Plug,
  rate_limit: {"api", 60_000, 100},  # 100 requests per minute
  by: {:conn, &get_user_id/1}
```

## 4. Input Validation

### SQL Injection Prevention
SkullQL queries are currently parsed, but add validation:

```elixir
defmodule Skulldb.Query.Validator do
  def validate_query(query) do
    # Check for dangerous patterns
    # Validate query structure
    # Sanitize inputs
  end
end
```

### Property Validation
Add validation for node/edge properties:

```elixir
defmodule Skulldb.Validation do
  def validate_properties(props) do
    # Check for size limits
    # Validate data types
    # Sanitize strings
  end
end
```

## 5. CORS Configuration

Configure CORS restrictively in production:

```elixir
# Development (permissive)
config :skulldb,
  cors_origins: ["*"]

# Production (restrictive)
config :skulldb,
  cors_origins: ["https://app.yourdomain.com", "https://admin.yourdomain.com"]
```

Implement in HTTP server:

```elixir
plug Corsica,
  origins: Application.get_env(:skulldb, :cors_origins),
  allow_headers: ["authorization", "content-type"],
  allow_methods: ["GET", "POST", "PUT", "DELETE"]
```

## 6. Secrets Management

### Never hardcode secrets
❌ Bad:
```elixir
config :skulldb,
  jwt_secret: "my-secret-key"
```

✅ Good:
```elixir
config :skulldb,
  jwt_secret: System.fetch_env!("SKULLDB_JWT_SECRET")
```

### Cloud Secrets Management
- **AWS**: Use AWS Secrets Manager or Parameter Store
- **GCP**: Use Secret Manager
- **Azure**: Use Key Vault
- **Kubernetes**: Use Sealed Secrets or external secrets operator

Example with AWS Secrets Manager:

```elixir
{:ok, secret} = ExAws.SecretsManager.get_secret_value("skulldb/jwt-secret")
Application.put_env(:skulldb, :jwt_secret, secret["SecretString"])
```

## 7. Audit Logging Security

### Sensitive Data
Don't log sensitive information:

```elixir
# Bad
AuditLog.log(context, :update_user, %{password: new_password})

# Good
AuditLog.log(context, :update_user, %{fields_updated: [:password]})
```

### Audit Log Protection
Restrict access to audit logs:

```elixir
def get_audit_logs(context) do
  if Context.has_role?(context, :admin) do
    AuditLog.query()
  else
    {:error, :forbidden}
  end
end
```

## 8. Database Security

### File Permissions
Ensure data directory has restricted permissions:

```bash
chmod 700 /var/lib/skulldb/data
chown skulldb:skulldb /var/lib/skulldb/data
```

### Backup Encryption
Encrypt backups:

```bash
# Example using GPG
tar czf - data/ | gpg --encrypt --recipient backup@example.com > backup.tar.gz.gpg
```

## 9. Dependency Security

### Regular Updates
```bash
mix hex.outdated
mix deps.update --all
```

### Security Audits
```bash
mix deps.audit
```

Add to `mix.exs`:
```elixir
{:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false}
```

## 10. Monitoring & Alerts

### Security Events to Monitor
- Failed login attempts
- Unauthorized access attempts
- Unusual query patterns
- Rate limit violations
- Token expiration/refresh patterns

### Implementation Example

```elixir
defmodule Skulldb.SecurityMonitor do
  require Logger

  def log_security_event(event_type, context, details) do
    Logger.warning("SECURITY: #{event_type}",
      user_id: context.user_id,
      tenant_id: context.tenant_id,
      details: details
    )

    # Send to monitoring service (e.g., Datadog, New Relic)
    # Trigger alerts if necessary
  end
end
```

## Security Checklist

Before going to production:

- [ ] Replace SHA256 with Argon2 for password hashing
- [ ] Implement proper JWT signing with secret rotation
- [ ] Enable HTTPS/TLS
- [ ] Configure restrictive CORS
- [ ] Implement rate limiting
- [ ] Set up secrets management
- [ ] Configure audit logging
- [ ] Set proper file permissions
- [ ] Enable security monitoring
- [ ] Perform security audit
- [ ] Test authentication flows
- [ ] Test authorization rules
- [ ] Validate input sanitization
- [ ] Review error messages (no information leakage)
- [ ] Set up automated dependency updates
- [ ] Configure backup encryption
- [ ] Document security procedures
- [ ] Set up incident response plan

## Compliance Considerations

If handling sensitive data:

- **GDPR**: Implement data deletion, export, and privacy features
- **HIPAA**: Ensure audit logging and encryption
- **PCI-DSS**: Follow payment data security standards
- **SOC 2**: Document security controls

## Additional Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Elixir Security Guide](https://hexdocs.pm/phoenix/security.html)
- [JWT Best Practices](https://tools.ietf.org/html/rfc8725)
- [Argon2 Password Hashing](https://github.com/P-H-C/phc-winner-argon2)

## Reporting Security Issues

If you discover a security vulnerability, please email: security@example.com

**Do not** create public GitHub issues for security problems.
