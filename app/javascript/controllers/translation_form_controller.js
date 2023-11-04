import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="translate"
export default class extends Controller {
  static targets = ["cancel_button", "reload_button", "locale_select"]

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

  // Observer resets bindings on translation UI whenever form is reloaded
  // Maybe: separate controller
  formObserver() {
    // Options for the observer (which mutations to observe)
    const obsConfig = { childList: true, subtree: true },
      // Callback function to execute when mutations are observed
      obsCallback = (mutationList, observer) => {
        for (const mutation of mutationList) {
          if (mutation.type === "childList") {
            // console.log("A child node has been added or removed.");
            this.translationUIBindings();
          }
        }
      },
      observer = new MutationObserver(obsCallback);

    // Start observing the target node for configured mutations
    observer.observe(this.$translation_ui, obsConfig);
  }

  // These are loaded dynamically so must be rebound via formObserver()
  // these are targets for the ui controller
  translationUIBindings() {
    // stimulus - these are targets
    const $cancel_button = document.getElementById('cancel_button'),
      $reload_button = document.getElementById('reload_button'),
      $form = document.getElementById('translation_form'),
      $textareas = this.$translation_ui.querySelectorAll('textarea'),
      $locale_select = document.getElementById('locale');

    // Attach listeners as delegates since they are injected into the dom.
    // Give the textareas data-actions so we don't have to bind here.
    // Still need them as targets so we can disable on form changed.
    // Maybe even do same for cancel button and reload button, and locale_select
    $textareas.forEach((element) => {
      element.onchange = () => { this.formChanged() };
      element.onkeydown = () => { this.formChanged() };
    });

    // clear the form
    if ($cancel_button) {
      $cancel_button.onclick = () => {
        this.$translation_ui.innerHTML = '';
        this.LOADED = false;
        this.CHANGED = false;
      };
    }

    // change the locale of the reload button and fire it
    if ($locale_select) {
      $locale_select.onchange = (e) => {
        changeReloadLocale(e);
        $reload_button.click();
      };
    }

    // give the reload button the url of the edit action with new locale
    function changeReloadLocale(e) {
      const _href = $reload_button.href,
        _locale_query = "?locale=",
        _path_components = _href.split(_locale_query),
        _path = _path_components[0],
        // _old_locale = _path_components[1],
        _new_locale = e.target.value,
        _new_href = _path + _locale_query + _new_locale;

      $reload_button.setAttribute("href", _new_href);
    }

    // I think this is fired AFTER ujs submits the form. Anyway unpredictable
    // use data-action
    if ($form) {
      $form.onsubmit = (e) => {
        this.CHANGED = false;
        this.disableCommitButtons(true);
      };
    }
  }

  formChanged() {
    // console.log("formChanged")
    this.CHANGED = true;
    this.disableCommitButtons(false);
  }

  disableCommitButtons(disabled) {
    const $save_button = document.getElementById('save_button'),
      $cancel_button = document.getElementById('cancel_button');

    $save_button.disabled = disabled;
    $cancel_button.disabled = !disabled;
  }
}
