// Configure your import map in config/importmap.rb.
// Read more: https://github.com/rails/importmap-rails
// If string literal error, it means the importmap is not functioning

// import "jquery3"
import "bootstrap"

import "@hotwired/turbo-rails"
// Turbo.setFormMode("optin"), or all forms will need to provide turbo response!
// https://stackoverflow.com/questions/70921317/how-can-i-disable-hotwire-turbo-the-turbolinks-replacement-for-all-forms-in
// use data-turbo="true" to opt in a form or button like delete/patch
Turbo.setFormMode("optin")

import Rails from "@rails/ujs"
Rails.start();

import "@hotwired/stimulus"
import "@hotwired/stimulus-loading"
import "controllers"
