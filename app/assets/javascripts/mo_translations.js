// TODO: maybe make this a class, with own functions,
// or give it functions by extending prototype.
// Those functions can be called by edit/update/show versions

class MOTranslations {

  constructor(localizedText = {}) {
    this.LOCALE = localizedText.locale,
      this.CONFIRM_STRING = localizedText.confirm_string,
      this.LOADING_STRING = localizedText.loading_string,
      this.SAVING_STRING = localizedText.saving_string,
      this.LOADED = false,
      this.CHANGED = false,

      // TRANSLATION UI - EDIT FORM
      this.$translation_ui = document.getElementById('translation_ui');

    this.indexBindings();
    this.formObserver();

  }

  // INDEX OF TRANSLATABLE TAGS
  indexBindings() {
    // EVENT LISTENERS (note the delegates!)
    window.onbeforeunload = function () {
      if (this.CHANGED)
        return this.CONFIRM_STRING;
    };
  }

  // reset bindings on the translation UI whenever the form is reloaded
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
  translationUIBindings() {
    const $cancel_button = document.getElementById('cancel_button'),
      $reload_button = document.getElementById('reload_button'),
      $form = document.getElementById('translation_form'),
      $textareas = this.$translation_ui.querySelectorAll('textarea'),
      $locale_select = document.getElementById('locale');

    // Attach listeners as delegates since they are injected into the dom.
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
