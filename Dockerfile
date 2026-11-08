ARG RUBY_VERSION=3.3.0
FROM ruby:${RUBY_VERSION}-slim

WORKDIR /app

ENV RAILS_ENV=production
ENV BUNDLE_DEPLOYMENT=1
ENV BUNDLE_WITHOUT=development:test

RUN apt-get update -qq && apt-get install -y build-essential libpq-dev && rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .
# API-only app: no asset pipeline, so no assets:precompile step (the previous
# "|| true" variant silently hid any boot error at build time).

EXPOSE 3000

CMD ["sh", "-c", "bundle exec rails db:migrate && bundle exec rails db:seed && exec bundle exec puma -C config/puma.rb"]
