# Throne API

Rails 8 API for the Throne portfolio app.

## Requirements

- Ruby 3.3.0
- Rails 8.0.4
- SQLite (development/test)
- PostgreSQL (production)
- Node.js (for asset compilation if needed)

## Setup

1. Install Ruby 3.3.0 (via rbenv, asdf, or rvm)
2. Run in WSL: `source ~/.bashrc`
3. `bundle install`
4. `rails db:create db:migrate db:seed`
5. `rails server`

## Tests

```bash
bundle exec rails test
```

## Environment

- `DATABASE_URL` - Production PostgreSQL URL
- `FRONTEND_ORIGIN` - CORS allowed origin / reschedule email link base (include scheme, e.g. `https://app.example.com`)
- `SECRET_KEY_BASE` - **Required in production.** Generate with `rails secret`, then set in your hosting env (e.g. Railway Variables).
- `JWT_SECRET` - Optional JWT signing secret (defaults to secret_key_base)
- `API_HOST` - Public API hostname (no scheme) used for Active Storage URLs and host allowlisting
- `RAILS_HOSTS` - Comma-separated extra hostnames allowed by Rails (e.g. Railway domain)
- `ADMIN_SEED_EMAIL` / `ADMIN_SEED_PASSWORD` - Seed admin (`ADMIN_SEED_PASSWORD` required in production)
- `ALLOW_PUBLIC_SIGN_UP` - Optional; when `true`, allows registration after the first user exists (default: only bootstrap when User.count is zero)
- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `AWS_BUCKET` - **Required for durable media on Railway.** Without these, uploads use local disk and are lost on redeploy.
- `RAILS_MASTER_KEY` - Alternative to SECRET_KEY_BASE (for credentials-based setup)
- `RESEND_API_KEY` - Resend API key for appointment reschedule emails (required in production for mail delivery)
- `MAILER_FROM` - From address for Action Mailer (e.g. `Throne <bookings@yourdomain.com>`; must be a verified Resend domain)

## Appointments

Public booking and admin management replace the old contact form.

**Public**

- `GET /api/v1/appointments/slots?from=&to=` — ISO8601 range; returns available slot starts
- `POST /api/v1/appointments` — book a slot (`name`, `email`, optional `company`/`notes`, `starts_at`)
- `GET /api/v1/appointments/reschedule/:token` — validate one-time reschedule token
- `PATCH /api/v1/appointments/reschedule/:token` — pick a new `starts_at` (returns booking to `pending`)

**Admin** (JWT + admin)

- `GET /api/v1/admin/appointments?from=&to=` — optional calendar range
- `PATCH /api/v1/admin/appointments/:id` — update `status` (`pending` / `confirmed` / `declined` / `cancelled`)
- `POST /api/v1/admin/appointments/:id/reschedule` — mint token + email client via Resend
- `DELETE /api/v1/admin/appointments/:id`
- `GET /api/v1/admin/appointment_settings`
- `PATCH /api/v1/admin/appointment_settings` — weekly hours, timezone, slot duration, lead time, bookable days

Defaults are seeded once from `config/appointments.yml` into the `appointment_settings` singleton (timezone `America/New_York`, weekly hours 10:00–16:00 Eastern). Runtime availability always reads the DB settings, not the YAML file.

If an environment was already seeded with an older timezone (e.g. `America/Denver`), re-running seeds will **not** overwrite it — update timezone via Admin → Hours, or in Rails console: `AppointmentSetting.instance.update!(timezone: "America/New_York")`.

## Railway checklist (API service)

1. `SECRET_KEY_BASE` (or `RAILS_MASTER_KEY`)
2. `DATABASE_URL` (Railway Postgres)
3. `ADMIN_SEED_PASSWORD` (+ optional `ADMIN_SEED_EMAIL`)
4. `FRONTEND_ORIGIN` = frontend public URL
5. `API_HOST` = this API's public hostname
6. `RAILS_HOSTS` = same hostname (or comma-separated list)
7. `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `AWS_BUCKET` for persistent project images
8. `RESEND_API_KEY` + `MAILER_FROM` for appointment reschedule emails
