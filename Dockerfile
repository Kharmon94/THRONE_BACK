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
RUN bundle exec rails assets:precompile 2>/dev/null || true

EXPOSE 3000

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
