// Configure your import map in config/importmap.rb.
// Read more: https://github.com/rails/importmap-rails
// If string literal error, it means the importmap is not functioning

// import "jquery3"
import "bootstrap"
import "@hotwired/stimulus"
import "@hotwired/stimulus-loading"
// import "@rails/request.js"
import "@hotwired/turbo-rails"
import Rails from "@rails/ujs" // for 7.0.8?
Rails.start();
import "controllers"
