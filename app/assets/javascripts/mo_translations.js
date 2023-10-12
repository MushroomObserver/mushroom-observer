function MOTranslations(localizedText) {
  let LOCALE = localizedText.locale,
    CONFIRM_STRING = localizedText.confirm_string,
    LOADING_STRING = localizedText.loading_string,
    SAVING_STRING = localizedText.saving_string,
    LOADED = false,
    CHANGED = false;
  const $whirly = document.getElementById('whirly'),
    $tag_links = document.querySelectorAll('[data-role="show_tag"]');


  // EVENT LISTENERS (note the delegates!)
  window.onbeforeunload = function () {
    if (CHANGED)
      return CONFIRM_STRING;
  };

  // INDEX OF TRANSLATABLE TAGS
  $tag_links.forEach((element) => {
    element.onclick = function (event) {
      event.preventDefault();
      if (CHANGED)
        confirm
      loadEditForm(LOCALE, this.dataset.tag);
    };
  });

  // TRANSLATION UI - EDIT FORM
  const $translation_ui = document.getElementById('translation_ui'),
    // Options for the observer (which mutations to observe)
    obsConfig = { childList: true, subtree: true },
    // Callback function to execute when mutations are observed
    obsCallback = (mutationList, observer) => {
      for (const mutation of mutationList) {
        if (mutation.type === "childList") {
          // console.log("A child node has been added or removed.");
          translationUIBindings();
        }
      }
    },
    observer = new MutationObserver(obsCallback);

  // Start observing the target node for configured mutations
  observer.observe($translation_ui, obsConfig);

  const translationUIBindings = () => {
    const $cancel_button = document.getElementById('cancel_button'),
      $reload_button = document.getElementById('reload_button'),
      $form = document.getElementById('translation_form'),
      $textareas = $form.querySelectorAll('textarea'),
      $show_versions = $form.querySelectorAll('[data-role="show_old_version"]'),
      $locale = document.getElementById('locale');

    // Attach listeners as delegates since they are injected into the dom.
    $textareas.forEach((element) => {
      element.onchange = () => { formChanged() };
      element.onkeydown = () => { formChanged() };
    });

    $cancel_button.onclick = () => {
      clearForm();
    };

    $reload_button.onclick = (e) => {
      loadEditForm(LOCALE, e.target.dataset.tag);
    };

    $locale.onchange = (e) => {
      loadEditForm(e.target.value, e.target.dataset.tag);
    };

    $show_versions.forEach((element) => {
      element.onclick = function (event) {
        event.preventDefault();
        showOldVersion(this.dataset.id);
      }
    });

    $form.onsubmit = (event) => {
      debugger
      event.preventDefault();
      CHANGED = false;
      show_whirly(SAVING_STRING);
      disableCommitButtons(true);
      submitForm(event.target)
    };
  }

  // FETCH FORM
  function loadEditForm(locale, tag) {
    LOCALE = locale;
    if (!CHANGED || confirm(CONFIRM_STRING)) {
      show_whirly(LOADING_STRING);
      const url = '/translations/' + tag + '/edit' + '?locale=' + locale;
      // debugger;
      fetch(url).then((response) => {
        if (response.ok) {
          if (200 <= response.status && response.status <= 299) {
            response.text().then((html) => {
              // debugger;
              console.log("html: " + html);
              hide_whirly();
              $translation_ui.innerHTML = html;
              CHANGED = false;
              LOADED = true;
            }).catch((error) => {
              console.error("no_content:", error);
            });
          } else {
            hide_whirly();
            alert(response.responseText);
            console.log(`got a ${response.status}`);
          }
        }
      })
    }
  }

  function getCSRFToken() {
    const csrfToken = document.querySelector("[name='csrf-token']")

    if (csrfToken) {
      return csrfToken.content
    } else {
      return null
    }
  }

  // SUBMIT FORM - this is submitting twice
  function submitForm(form) {
    const formData = new FormData(form),
      url = form.action;

    fetch(url, {
      method: 'PATCH',
      headers: {
        'X-CSRF-Token': getCSRFToken(),
        'X-Requested-With': 'XMLHttpRequest',
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      body: JSON.stringify(formData)
      // credentials: 'same-origin'
    }).then((response) => {
      if (response.ok) {
        if (200 <= response.status && response.status <= 299) {
          response.json().then((json) => {
            resultsLoaded(json);
          }).catch((error) => {
            console.error("no_content:", error);
          });
        } else {
          hide_whirly();
          alert(response.responseText);
          console.log(`got a ${response.status}`);
        }
      }
    })
  }

  // RESULTS
  const $results = document.getElementById('translation_results');
  $results.addEventListener('load', resultsLoaded);

  // Helpers and callbacks
  function resultsLoaded(json) {
    // debugger
    // const tag = $results.querySelector("#tag");
    // const str = $results.querySelector("#str");
    if (json.tag != undefined) {
      // Make tag in left column gray because it's now been translated.
      // Want only untranslated tags to be bold black to stand out better.
      const _str_tag = document.getElementById('str_' + json.tag);
      _str_tag.innerHTML = json.str;
      _str_tag.classList.add('translated').add('text-muted');
    } else if (LOADED) {
      CHANGED = true;
      disableCommitButtons(false);
    }
    hide_whirly();
  }

  function clearForm() {
    $translation_ui.innerHTML = '';
    LOADED = false;
    CHANGED = false;
  }

  // AJAX FETCH PREVIOUS VERSIONS
  function showOldVersion(id) {
    show_whirly(LOADING_STRING);
    fetch('/ajax/old_translation/' + id).then((response) => {
      if (response.ok) {
        if (200 <= response.status && response.status <= 299) {
          response.text().then((html) => {
            // console.log("html: " + html);
            hide_whirly();
            alert(html);
          }).catch((error) => {
            console.error("no_content:", error);
          });
        } else {
          hide_whirly();
          alert(response.responseText);
          console.log(`got a ${response.status}`);
        }
      }
    });
  }

  function formChanged() {
    console.log("formChanged")
    CHANGED = true;
    disableCommitButtons(false);
  }

  function disableCommitButtons(disabled) {
    const $save_button = document.getElementById('save_button'),
      $cancel_button = document.getElementById('cancel_button');

    $save_button.disabled = disabled;
    $cancel_button.disabled = !disabled;
  }

  function show_whirly(text) {
    document.getElementById('whirly_text').innerHTML = text;
    // $whirly.center().show();
    show($whirly);
  }

  function hide_whirly() {
    hide($whirly);
  }

  /*********************/
  /*      Helpers      */
  /*********************/

  // notice this is for block-level
  function show(element) {
    if (element !== undefined) {
      element.style.display = 'block';
      element.classList.add('in');
    }
  }

  function hide(element) {
    if (element !== undefined) {
      element.classList.remove('in');
      window.setTimeout(() => { element.style.display = 'none'; }, 600);
    }
  }
}
