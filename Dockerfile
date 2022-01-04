FROM ruby:2.6.8

ENV LANG C.UTF-8
ENV APP_HOME /numbatApp

RUN apt-get update -qq && apt-get install -y build-essential nodejs npm python locales && npm install --global yarn && update-locale en_US.UTF-8
RUN rm -rf /var/lib/apt/lists/*

RUN mkdir $APP_HOME
WORKDIR $APP_HOME
COPY ./Gemfile $APP_HOME/Gemfile
COPY ./Gemfile.lock $APP_HOME/Gemfile.lock
RUN gem install bundler
RUN bundle install
RUN rails webpacker:install
COPY . $APP_HOME

EXPOSE  3000
