# frozen_string_literal: true

# Pin npm packages by running ./bin/importmap

pin "application", preload: true
# pin "bootstrap", to: "bootstrap.min.js", preload: true
pin "@rails/ujs", to: "@rails--ujs.js" # @7.0.7
pin "@rails/request.js", to: "requestjs.js", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin_all_from "app/javascript/controllers", under: "controllers"
