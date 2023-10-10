function MOTranslations(localizedText) {
  window.onload = () => {
    let LOCALE = localizedText.locale,
      CONFIRM_STRING = localizedText.confirm_string,
      LOADING_STRING = localizedText.loading_string,
      SAVING_STRING = localizedText.saving_string,
      LOADED = false,
      CHANGED = false;
    const $whirly = document.getElementById('whirly'),
      $save_button = document.getElementById('save_button'),
      $cancel_button = document.getElementById('cancel_button'),
      $form_div = document.getElementById('form_div'),
      $post_form = document.getElementById('post_form'),
      $tag_links = document.querySelectorAll('[data-role="show_tag"]')

    // EVENT LISTENERS (note the delegates!)
    window.onbeforeunload = function () {
      if (CHANGED)
        return CONFIRM_STRING;
    };
    debugger;
    // annoying, cannot attach to window.hidden_frame in FF!
    const $frame = document.getElementById('hidden_frame');
    $frame.addEventListener('load', frame_load);

    $tag_links.forEach((element) => {
      element.onclick = function (event) {
        event.preventDefault();
        if (CHANGED)
          confirm
        show_tag(LOCALE, this.dataset.tag);
      };
    });

    // Override non-javascripty submit target.
    $post_form.setAttribute('action', 'edit_translations_ajax_post');
    $post_form.setAttribute('target', 'hidden_frame');

    // Attach listeners as delegates since they are injected into the dom.
    const $textareas = $post_form.querySelectorAll('textarea');

    $textareas.forEach((element) => {
      element.onchange = () => { form_changed() };
      element.onkeydown = () => { form_changed() };
    });

    $form_div.onload = () => {
      document.getElementById('cancel_button').onclick = () => {
        clear_form();
      };

      document.getElementById('reload_button').onclick = () => {
        show_tag(LOCALE, this.dataset.tag);
      };

      document.getElementById('locale').onchange = () => {
        show_tag(this.value, this.dataset.tag);
      };

      const $show_old_versions =
        $post_form.querySelectorAll('[data-role="show_old_version"]');

      $show_old_versions.forEach((element) => {
        element.onclick = function (event) {
          event.preventDefault();
          show_old_version(this.dataset.id);
        }
      });

      $post_form.submit(function () {
        CHANGED = false;
        show_whirly(SAVING_STRING);
        setDisabledOnButtons(true);
      });
    }

    // Helpers and callbacks
    function frame_load() {
      const tag = $frame.tag;
      const str = $frame.str;
      if (tag != undefined) {
        // Make tag in left column gray because it's now been translated.
        // Want only untranslated tags to be bold black to stand out better.
        const _str_tag = document.getElementById('str_' + tag);
        _str_tag.innerHTML = str;
        _str_tag.classList.add('translated faint');
      } else if (LOADED) {
        CHANGED = true;
        setDisabledOnButtons(false);
      }
      hide_whirly();
    }

    function form_changed() {
      CHANGED = true;
      setDisabledOnButtons(false);
    }

    const csrfToken = document.querySelector("[name='csrf-token']").content;

    function show_tag(locale, tag) {
      LOCALE = locale;
      if (!CHANGED || confirm(CONFIRM_STRING)) {
        show_whirly(LOADING_STRING);
        // jQuery.ajax('/translation/edit_translations_ajax_get', {
        //   data: { locale: locale, tag: tag, authenticity_token: csrf_token() },
        //   dataType: 'text',
        //   async: true,
        //   error: function (response) {
        //     hide_whirly();
        //     alert(response.responseText);
        //   },
        //   success: function (html) {
        //     hide_whirly();
        //     $form_div.html(html);
        //     CHANGED = false;
        //     LOADED = true;
        //   }
        // });
        const url = '/translation/edit_translations_ajax_get'
          + '?locale=' + locale + "&tag=" + tag;
        debugger;
        fetch(url, {
          method: 'GET',
          // headers: {
          //   'X-CSRF-Token': csrfToken,
          //   'X-Requested-With': 'XMLHttpRequest',
          //   'Content-Type': 'text/html',
          //   'Accept': 'text/html'
          // },
          // credentials: 'same-origin'
        }).then((response) => {
          if (response.ok) {
            if (200 <= response.status && response.status <= 299) {
              response.text().then((html) => {
                debugger;
                console.log("html: " + html);
                hide_whirly();
                $form_div.innerHTML = html;
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

    function clear_form() {
      $form_div.innerHTML = '';
      LOADED = false;
      CHANGED = false;
    }

    function show_old_version(id) {
      show_whirly(LOADING_STRING);
      // jQuery.ajax('/ajax/old_translation/' + id, {
      //   data: { authenticity_token: csrf_token() },
      //   dataType: 'text',
      //   async: true,
      //   success: function (text) {
      //     hide_whirly();
      //     alert(text);
      //   }
      // });
      fetch('/ajax/old_translation/' + id, {
        method: 'GET',
        // headers: {
        //   'X-CSRF-Token': csrfToken,
        //   'X-Requested-With': 'XMLHttpRequest',
        //   'Content-Type': 'text/html',
        //   'Accept': 'text/html'
        // },
        // credentials: 'same-origin'
      }).then((response) => {
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

    function setDisabledOnButtons(disabled) {
      $save_button.setAttribute('disabled', disabled);
      $cancel_button.setAttribute('disabled', !disabled);
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

  };
}
