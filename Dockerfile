# Use the Ruby 2.7.1 image from Docker Hub
# as the base image (https://hub.docker.com/_/ruby)
FROM ruby:2.7.1

# Use a directory called /code in which to store
# this application's files. (The directory name
# is arbitrary and could have been anything.)
WORKDIR /code

# Copy all the application's files into the /code
# directory.
COPY . /code

# Install locales and update the locale to en_US.UTF-8
RUN apt-get -y update
RUN apt-get -y upgrade
RUN apt-get install -y locales
RUN update-locale en_US.UTF-8

# Run bundle install to install the Ruby dependencies.
RUN bundle install

# Set "rails server -b 0.0.0.0" as the command to
# run when this container starts.
CMD ["rails", "server", "-b", "0.0.0.0"]