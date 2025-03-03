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
Turbo.config.forms.mode = "optin"
// https://stackoverflow.com/a/77434363/3357635
// use: <%= turbo_stream.close_modal("modal_#{obs.id}_naming") %>
Turbo.StreamActions.close_modal = function () {
  $("#" + this.templateContent.textContent).modal('hide')
};
// https://stackoverflow.com/a/76744968/3357635
Turbo.StreamActions.update_input = function () {
  this.targetElements.forEach((target) => {
    target.value = this.templateContent.textContent
  });
};
// https://stackoverflow.com/a/77836101/3357635
Turbo.StreamActions.add_class = function () {
  this.targetElements.forEach((target) => {
    target.classList.add(this.templateContent.textContent)
  });
}
Turbo.StreamActions.remove_class = function () {
  this.targetElements.forEach((target) => {
    target.classList.remove(this.templateContent.textContent)
  });
}

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
