FROM ruby:3.4.9-bookworm

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
      build-essential \
      default-libmysqlclient-dev \
      imagemagick \
      libmagickcore-dev \
      libmagickwand-dev \
      libjpeg-dev \
      libjpeg-progs \
      libimage-exiftool-perl \
      chromium \
      mariadb-client \
      bsdextrautils \
    && rm -rf /var/lib/apt/lists/*

ENV BUNDLE_PATH=/bundle

RUN mkdir -p /bundle

WORKDIR /app

COPY .ruby-version Gemfile Gemfile.lock ./
RUN bundle install

COPY script/jpegresize.c ./script/
RUN gcc script/jpegresize.c -ljpeg -lm -O2 -o /usr/local/bin/jpegresize

COPY script/exifautotran /usr/local/bin/exifautotran
RUN chmod 755 /usr/local/bin/exifautotran

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 3000
ENTRYPOINT ["entrypoint.sh"]
CMD ["bin/rails", "server", "-b", "0.0.0.0"]
