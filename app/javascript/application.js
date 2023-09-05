// Configure your import map in config/importmap.rb.
// Read more: https://github.com/rails/importmap-rails
// If string literal error, it means the importmap is not functioning

// import "bootstrap"
import "@hotwired/turbo-rails"
import Rails from "@rails/ujs"
// import "@hotwired/stimulus"
// import "@hotwired/stimulus-loading"
Rails.start(); import "controllers"
