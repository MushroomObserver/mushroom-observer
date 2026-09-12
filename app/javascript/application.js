// Configure your import map in config/importmap.rb.
// Read more: https://github.com/rails/importmap-rails
// If string literal error, it means the importmap is not functioning

// https://stackoverflow.com/questions/72288802/how-can-i-install-jquery-in-rails-7-with-importmap
import "jquery" // this import first, then your other imports that use `$`

import "bootstrap"

import "@hotwired/turbo-rails"
// Rails 8 default: every form submits via Turbo unless it (or an
// ancestor) carries data-turbo="false". Components::ApplicationForm's
// `turbo:` prop always emits an explicit data-turbo attribute per
// form, so this global mode only matters for the handful of raw
// <form> tags outside that framework -- each of those already sets
// data-turbo="false" explicitly where needed.
Turbo.config.forms.mode = "on"
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
// Guards against duplicate inserts when both a controller's
// synchronous turbo_stream response and a model's async broadcast
// try to prepend the same new record (see CommentsController#create).
// Whichever arrives first wins; the second becomes a no-op instead of
// inserting a second copy.
Turbo.StreamActions.prepend_once = function () {
  const newElement = this.templateContent.firstElementChild
  if (newElement && newElement.id && document.getElementById(newElement.id)) {
    return
  }
  this.targetElements.forEach((target) => {
    target.prepend(this.templateContent.cloneNode(true))
  });
}

import "@rails/request.js"

import "@hotwired/stimulus"
import "@hotwired/stimulus-loading"

import "exifreader"
import jstz from "jstz"
try {
  document.cookie = "tz=" + jstz.determine().name() + ";samesite=lax"
}
catch (err) {
  // console.error(err)
}
// Allows js to parse Rails-formatted nested params under `q` as query strings
// (they are different from other formats). This is the dependency-free version.
import "qs-esm"

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
