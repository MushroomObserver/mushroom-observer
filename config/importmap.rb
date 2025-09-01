# frozen_string_literal: true

# Pin npm packages by running ./bin/importmap package-name
# If string literal error, it means the importmap is not functioning
# check it with bin/importmap json

# jQuery is tricky with importmap: must use cdn.jsdelivr.net, NOT jspm
# (which is for React and similar), or else `$` will not be available globally
pin "jquery", preload: true # @3.7.1

pin "bootstrap", to: "bootstrap.min.js", preload: true
# pin "bootstrap" # @3.4.1

pin "application", preload: true
pin "@rails/request.js", to: "requestjs.js", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin_all_from "app/javascript/controllers", under: "controllers"

pin "exifreader" # @4.16.0
pin "vanilla-lazyload" # @17.8.5
pin "lightgallery" # @2.7.2
pin "lightgallery/plugins/zoom", to: "lightgallery--plugins--zoom.js" # @2.7.2
pin "@googlemaps/js-api-loader", to: "https://ga.jspm.io/npm:@googlemaps/js-api-loader@1.16.2/dist/index.esm.js"
pin "jstz" # @2.1.1

pin_all_from "app/javascript/src", under: "src", to: "src"
pin "jquery-events-to-dom-events" # @1.1.0
pin "geo-coordinates-parser" # @1.6.3
pin "qs-esm" # @7.0.2
