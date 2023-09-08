// Configure your import map in config/importmap.rb.
// Read more: https://github.com/rails/importmap-rails
// If string literal error, it means the importmap is not functioning

import "@hotwired/turbo-rails"
import "jquery3"
import "bootstrap"
import Rails from "@rails/ujs"
import "@rails/request.js"
import "@hotwired/stimulus"
import "@hotwired/stimulus-loading"
Rails.start(); import "controllers"
