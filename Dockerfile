# syntax=docker/dockerfile:1

# Cistergraphia, as a container (docs/serving.md): the web app under Puma,
# listening on PORT (8080), as a user with no privileges.
#
# Two stages: the gems are built where a compiler is (Puma has a native
# extension) and copied into an image that has none. Development and test
# gems are left out. Nothing of the app is built: it is Ruby, templates and
# static files, copied as they are (what .dockerignore lets through).

ARG RUBY_VERSION=4.0

FROM ruby:${RUBY_VERSION}-slim AS gems
ENV BUNDLE_WITHOUT=development:test \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_JOBS=4
RUN apt-get update -qq \
    && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle install \
    && rm -rf "${BUNDLE_PATH}"/ruby/*/cache

FROM ruby:${RUBY_VERSION}-slim
ENV RACK_ENV=production \
    BUNDLE_WITHOUT=development:test \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    PORT=8080 \
    PUMA_THREADS=3 \
    WEB_CONCURRENCY=0
RUN groupadd --system --gid 1000 app \
    && useradd --system --uid 1000 --gid app --create-home app
WORKDIR /app
COPY --from=gems /usr/local/bundle /usr/local/bundle
COPY --chown=app:app . .
USER app
EXPOSE 8080
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb", "config.ru"]
