import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="translate"
export default class extends Controller {
  static targets = [
    "textarea", "save_button", "cancel_button", "reload_button", "locale_select"
  ]

  connect() {
    // TRANSLATION EDIT FORM. now this.element
    // this.$translation_ui = document.getElementById('translation_ui');
    this.LOCALE = this.element.dataset.locale;
    // this.CONFIRM_STRING = this.element.dataset.confirm_string;
    // this.LOADING_STRING = this.element.dataset.loading_string;
    // this.SAVING_STRING = this.element.dataset.saving_string;
    this.LOADED = false;
    this.CHANGED = false;

    // this.formObserver();
  }

  // these are targets for the ui controller

  // clear the form
  clearForm() {
    document.getElementById('translation_ui').innerHTML = '';
    this.LOADED = false;
    this.CHANGED = false;
  }

  // change the locale of the reload button and fire it
  changeLocale() {
    this.changeReloadLocale(e);
    this.reloadButtonTarget.click();
  }

  // give the reload button the url of the edit action with new locale
  changeReloadLocale(e) {
    const _href = this.reloadButtonTarget.href,
      _locale_query = "?locale=",
      _path_components = _href.split(_locale_query),
      _path = _path_components[0],
      // _old_locale = _path_components[1],
      _new_locale = e.target.value,
      _new_href = _path + _locale_query + _new_locale;

    this.reloadButtonTarget.setAttribute("href", _new_href);
  }

  // I think this is fired AFTER ujs submits the form. Anyway unpredictable
  // fired by the save button
  save() {
    this.CHANGED = false;
    this.disableCommitButtons(true);
  }

  formChanged() {
    // console.log("formChanged")
    this.CHANGED = true;
    this.disableCommitButtons(false); // means "enable"
  }

  disableCommitButtons(disabled) {
    this.saveButtonTarget.disabled = disabled;
    this.cancelButtonTarget.disabled = !disabled;
  }
}
