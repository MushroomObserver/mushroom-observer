# syntax = docker/dockerfile:1

# Multi-stage: `docker build` (or an explicit `--target development`)
# builds the dev/test image from #4511, unchanged in shape -- it relies
# on a bind mount for the app code, not a COPY, so edits don't need a
# rebuild. `docker build --target production` (or Kamal's
# `builder.target: production` in config/deploy.yml) adds
# RAILS_ENV=production, a deployment-mode bundle install excluding
# dev/test gems, and an asset precompile baked into the image.
FROM ruby:3.4.9-bookworm AS base

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
      build-essential \
      default-libmysqlclient-dev \
      imagemagick \
      libmagickcore-dev \
      libmagickwand-dev \
      libjpeg-dev \
      libjpeg-progs \
      libimage-exiftool-perl \
      zbar-tools \
      mariadb-client \
      bsdextrautils \
    && rm -rf /var/lib/apt/lists/*

ENV BUNDLE_PATH=/bundle

RUN mkdir -p /bundle

WORKDIR /app

COPY .ruby-version Gemfile Gemfile.lock ./

COPY script/jpegresize.c ./script/
RUN gcc script/jpegresize.c -ljpeg -lm -O2 -o /usr/local/bin/jpegresize

COPY script/exifautotran /usr/local/bin/exifautotran
RUN chmod 755 /usr/local/bin/exifautotran

EXPOSE 3000

# ---------------------------------------------------------------------
# Development/test image -- #4511's original shape, unchanged.
# ---------------------------------------------------------------------
FROM base AS development

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
      chromium \
    && rm -rf /var/lib/apt/lists/*

RUN bundle install

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["entrypoint.sh"]
CMD ["bin/rails", "server", "-b", "0.0.0.0"]

# ---------------------------------------------------------------------
# Production image.
# ---------------------------------------------------------------------
FROM base AS production

ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_WITHOUT="development:test"

RUN bundle install

# The app code itself -- unlike the development stage, production has
# no bind mount, so the image must be self-contained.
COPY . .

# Unlike Rails' own default production Dockerfile shape, assets are
# NOT precompiled here at build time -- MO's acts_as_versioned models
# (Location, Name, LocationDescription, NameDescription, GlossaryTerm,
# TranslationString) introspect the DB schema at class-load time, and
# precompiling eager-loads every model, so it needs a live, reachable
# database. A build machine has no such thing. Precompiling instead
# happens in docker/entrypoint.production.sh, at container start, once
# the database is confirmed reachable.

COPY docker/entrypoint.production.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENV PORT=3000

ENTRYPOINT ["entrypoint.sh"]
# No -b/-p flags -- config/puma.rb's own bind() call (gated on PORT)
# controls the address; Kamal can override this CMD entirely for the
# Solid Queue role (bin/jobs), sharing this same image.
CMD ["bin/rails", "server"]
