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

## Environment

- `DATABASE_URL` - Production PostgreSQL URL
- `FRONTEND_ORIGIN` - CORS allowed origin
- `SECRET_KEY_BASE` - **Required in production.** Generate with `rails secret`, then set in your hosting env (e.g. Railway Variables).
- `JWT_SECRET` - Optional JWT signing secret (defaults to secret_key_base)
- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `AWS_BUCKET` - Production S3
- `RAILS_MASTER_KEY` - Alternative to SECRET_KEY_BASE (for credentials-based setup)
