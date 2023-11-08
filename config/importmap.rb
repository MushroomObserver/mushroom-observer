# Pin npm packages by running ./bin/importmap
# If string literal error, it means the importmap is not functioning
# check it with bin/importmap json

pin "jquery3", to: "jquery.min.js", preload: true
# pin "jquery3", to: "https://ga.jspm.io/npm:jquery@3.7.0/dist/jquery.js",
#                preload: true
# pin "jquery" # @3.7.1
pin "bootstrap", to: "bootstrap.min.js", preload: true
# pin "bootstrap" # @3.4.1
pin "@rails/ujs", to: "@rails--ujs.js" # @7.0.7 ?
pin "application", preload: true
pin "@rails/request.js", to: "requestjs.js", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
# pin "@hotwired/stimulus", to: "https://ga.jspm.io/npm:@hotwired/stimulus@3.2.2/dist/stimulus.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin_all_from "app/javascript/controllers", under: "controllers"
pin "exifreader" # @4.16.0
pin "vanilla-lazyload" # @17.8.5
