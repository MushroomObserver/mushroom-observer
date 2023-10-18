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
      this.$whirly = document.getElementById('whirly'),
      this.$tag_links = document.querySelectorAll('[data-role="show_tag"]');

    // TRANSLATION UI - EDIT FORM
    this.$translation_ui = document.getElementById('translation_ui');
    // this.$results = document.getElementById('translation_results');

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

    // this.$tag_links.forEach((element) => {
    //   element.onclick = (e) => {
    //     e.preventDefault();
    //     if (this.CHANGED)
    //       confirm
    //     this.loadEditForm(this.LOCALE, e.target.dataset.tag);
    //   };
    // });
  }

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
      $textareas = $form.querySelectorAll('textarea'),
      // $show_versions = $form.querySelectorAll('[data-role="show_versions"]'),
      $locale_select = document.getElementById('locale');

    // Attach listeners as delegates since they are injected into the dom.
    $textareas.forEach((element) => {
      element.onchange = () => { this.formChanged() };
      element.onkeydown = () => { this.formChanged() };
    });

    $cancel_button.onclick = () => {
      this.clearForm();
    };

    // todo: just give the reload button the url of the edit action
    // $reload_button.onclick = (e) => {
    //   this.loadEditForm(this.LOCALE, e.target.dataset.tag);
    // };

    // change the locale of the reload button and fire it
    $locale_select.onchange = (e) => {
      const _href = $reload_button.href,
        _locale_query = "?locale=",
        _path_components = _href.split(_locale_query),
        _path = _path_components[0],
        // _old_locale = _path_components[1],
        _new_locale = e.target.value,
        _new_href = _path + _locale_query + _new_locale;

      $reload_button.setAttribute("href", _new_href);
      $reload_button.click();
    };

    // make this a controller action versions/show
    // $show_versions.forEach((element) => {
    //   element.onclick = (e) => {
    //     e.preventDefault();
    //     this.showOldVersion(e.target.dataset.id);
    //   }
    // });

    // I think this is fired AFTER ujs submits the form. Anyway unpredictable
    $form.onsubmit = (e) => {
      // event.preventDefault();
      // event.stopPropagation();
      this.CHANGED = false;
      this.show_whirly(this.SAVING_STRING);
      this.disableCommitButtons(true);
      // submitForm(event.target)
    };
  }

  // FETCH THE FORM FOR ONE TAG. links are ok. why not use edit actions
  // loadEditForm(locale, tag) {
  //   this.LOCALE = locale;
  //   if (!this.CHANGED || confirm(this.CONFIRM_STRING)) {
  //     this.show_whirly(this.LOADING_STRING);

  //     const url = '/translations/' + tag + '/edit' + '?locale=' + locale;
  //     // debugger;
  //     fetch(url).then((response) => {
  //       if (response.ok) {
  //         if (200 <= response.status && response.status <= 299) {
  //           response.text().then((html) => {
  //             // debugger;
  //             // console.log("html: " + html);
  //             this.hide_whirly();
  //             this.$translation_ui.innerHTML = html;
  //             this.CHANGED = false;
  //             this.LOADED = true;
  //           }).catch((error) => {
  //             console.error("no_content:", error);
  //           });
  //         } else {
  //           this.hide_whirly();
  //           alert(response.responseText);
  //           console.log(`got a ${response.status}`);
  //         }
  //       }
  //     })
  //   }
  // }

  // function getCSRFToken() {
  //   const csrfToken = document.querySelector("[name='csrf-token']")

  //   if (csrfToken) {
  //     return csrfToken.content
  //   } else {
  //     return null
  //   }
  // }

  // SUBMIT FORM - this was submitting twice bc rails ujs, just let rails submit
  // function submitForm(form) {
  //   const url = form.action,
  //     formData = new FormData(form),
  //     plainFormData = Object.fromEntries(formData.entries());

  //   fetch(url, {
  //     method: 'PATCH',
  //     headers: {
  //       'X-CSRF-Token': getCSRFToken(),
  //       // 'X-Requested-With': 'XMLHttpRequest',
  //       'Content-Type': 'application/json',
  //       'Accept': 'application/json'
  //     },
  //     body: JSON.stringify(plainFormData)
  //     // credentials: 'same-origin'
  //   }).then((response) => {
  //     if (response.ok) {
  //       if (200 <= response.status && response.status <= 299) {
  //         response.json().then((json) => {
  //           resultsLoaded(json);
  //         }).catch((error) => {
  //           console.error("no_content:", error);
  //         });
  //       } else {
  //         hide_whirly();
  //         alert(response.responseText);
  //         console.log(`got a ${response.status}`);
  //       }
  //     }
  //   })
  // }

  // RESULTS - update callback. Needs tag and new_str
  // const $results = document.getElementById('translation_results');
  // $results.addEventListener('load', resultsLoaded); // parse resultsLoaded

  // Called by update action onload, with the tag and new_str
  resultsLoaded(tag, new_str, e) {
    console.log("resultsLoaded");
    if (tag != undefined) {
      // Make tag in left column gray because it's now been translated.
      // Want only untranslated tags to be bold black to stand out better.
      const _str_tag = document.getElementById('str_' + tag);
      _str_tag.innerHTML = new_str;
      _str_tag.classList.add('translated').add('text-muted');
    } else if (this.LOADED) {
      this.CHANGED = true;
      this.disableCommitButtons(false);
    }
    this.hide_whirly();
  }

  clearForm() {
    this.$translation_ui.innerHTML = '';
    this.LOADED = false;
    this.CHANGED = false;
  }

  // AJAX FETCH PREVIOUS VERSIONS
  // showOldVersion(id) {
  //   this.show_whirly(this.LOADING_STRING);
  //   fetch('/ajax/old_translation/' + id).then((response) => {
  //     if (response.ok) {
  //       if (200 <= response.status && response.status <= 299) {
  //         response.text().then((html) => {
  //           // console.log("html: " + html);
  //           this.hide_whirly();
  //           alert(html);
  //         }).catch((error) => {
  //           console.error("no_content:", error);
  //         });
  //       } else {
  //         this.hide_whirly();
  //         alert(response.responseText);
  //         console.log(`got a ${response.status}`);
  //       }
  //     }
  //   });
  // }

  formChanged() {
    console.log("formChanged")
    this.CHANGED = true;
    this.disableCommitButtons(false);
  }

  disableCommitButtons(disabled) {
    const $save_button = document.getElementById('save_button'),
      $cancel_button = document.getElementById('cancel_button');

    $save_button.disabled = disabled;
    $cancel_button.disabled = !disabled;
  }

  show_whirly(text) {
    document.getElementById('whirly_text').innerHTML = text;
    // $whirly.center().show();
    this.show(this.$whirly);
  }

  hide_whirly() {
    this.hide(this.$whirly);
  }

  /**********************/
  /*     MO Helpers     */
  /**********************/

  // notice this is for block-level
  show(element) {
    if (element !== undefined) {
      element.style.display = 'block';
      element.classList.add('in');
    }
  }

  hide(element) {
    if (element !== undefined) {
      element.classList.remove('in');
      window.setTimeout(() => { element.style.display = 'none'; }, 600);
    }
  }
}
