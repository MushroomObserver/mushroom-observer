// Configure your import map in config/importmap.rb.
// Read more: https://github.com/rails/importmap-rails
// If string literal error, it means the importmap is not functioning

// https://stackoverflow.com/questions/72288802/how-can-i-install-jquery-in-rails-7-with-importmap
import "jquery" // this import first, then your other imports that use `$`

import "bootstrap"

import "@hotwired/turbo-rails"
// Must setFormMode("optin") or all forms will need to provide a turbo response.
// https://stackoverflow.com/questions/70921317/how-can-i-disable-hotwire-turbo-the-turbolinks-replacement-for-all-forms-in
// form, or button like delete/patch: set data-turbo="true" to opt in
// link_to with GET: set data-turbo-stream="true" to opt in
Turbo.setFormMode("optin")
// https://stackoverflow.com/questions/77421369/turbo-response-to-render-javascript-alert/77434363#77434363
Turbo.StreamActions.close_modal = function () {
  $("#" + this.templateContent.textContent).modal('hide')
};

import "@rails/request.js"

import "@hotwired/stimulus"
import "@hotwired/stimulus-loading"

import 'exifreader'
import jstz from 'jstz'
try {
  document.cookie = "tz=" + jstz.determine().name() + ";samesite=lax"
}
catch (err) {
  // console.error(err)
}

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
