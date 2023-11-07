import { Controller } from "@hotwired/stimulus"

// TRANSLATION EDIT FORM is this.element
// Connects to data-controller="translate"
export default class extends Controller {
  static targets = [
    "textarea", "saveButton", "cancelButton", "reloadButton", "localeSelect"
  ]

  connect() {
    this.LOCALE = this.element.dataset.locale;
    this.CONFIRM_STRING = this.element.dataset.confirmString;
    this.LOADING_STRING = this.element.dataset.loadingString;
    this.SAVING_STRING = this.element.dataset.savingString;
    this.LOADED = false;
    this.CHANGED = false;

    this.reloadButtonTarget.setAttribute("data-turbo-submits-with",
      this.LOADING_STRING)
    this.saveButtonTarget.setAttribute("data-turbo-submits-with",
      this.SAVING_STRING)
  }

  indexBindings() {
    window.addEventListener("beforeunload", confirmLosingWork)
    window.addEventListener("turbo:before-render", confirmLosingWork)

    function confirmLosingWork() {
      if (this.CHANGED)
        return this.CONFIRM_STRING;
    };
  }

  // clear the form
  clearForm() {
    document.getElementById('translation_ui').innerHTML = '';
    this.LOADED = false;
    this.CHANGED = false;
  }

  // change the locale in the url of the reload button and click it
  changeLocale(event) {
    this.changeReloadLocale(event);
    this.reloadButtonTarget.click();
  }

  // give the reload button the url of the edit action with new locale
  changeReloadLocale(event) {
    const _href = this.reloadButtonTarget.href,
      _locale_query = "?locale=",
      _path_components = _href.split(_locale_query),
      _path = _path_components[0],
      // _old_locale = _path_components[1],
      _new_locale = event.target.value,
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
