// Configure your import map in config/importmap.rb.
// Read more: https://github.com/rails/importmap-rails
// If string literal error, it means the importmap is not functioning

import "jquery3"
import "bootstrap"

import "@hotwired/turbo-rails"
// Turbo.setFormMode("optin"), or all forms will need to provide turbo response!
// https://stackoverflow.com/questions/70921317/how-can-i-disable-hotwire-turbo-the-turbolinks-replacement-for-all-forms-in
// form, or button like delete/patch: set data-turbo="true" to opt in
// link_to with GET: set data-turbo-stream="true" to opt in
Turbo.setFormMode("optin")

import "@rails/request.js"

import "@hotwired/stimulus"
import "@hotwired/stimulus-loading"

import 'exifreader'

import LazyLoad from "vanilla-lazyload"
if (!window.lazyLoadInstance) {
  window.lazyLoadInstance = new LazyLoad({
    elements_selector: ".lazy"
    // ... more custom settings?
  });
}

// import Rails from "@rails/ujs"
// Rails.start();
import "controllers"

// Define a variable to check in inlined HTML script
window.importmapScriptsLoaded = true
