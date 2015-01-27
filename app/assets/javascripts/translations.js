function TranslationsModule(localizedText) {
    jQuery(document).ready(function () {
        var LOCALE = localizedText.locale,
            CONFIRM_STRING = localizedText.confirm_string,
            LOADING_STRING = localizedText.loading_string,
            SAVING_STRING = localizedText.saving_string,
            LOADED = false,
            CHANGED = false,
            $whirly = jQuery("#whirly"),
            $save_button = jQuery("#save_button"),
            $cancel_button = jQuery("#cancel_button"),
            $form_div = jQuery("#form_div"),
            $post_form = jQuery("#post_form"),
            $tag_links = jQuery('[data-role="show_tag"]')

        //EVENT LISTENERS (note the delegates!)
        window.onbeforeunload = function () {
            if (CHANGED)
                return CONFIRM_STRING;
        };

        var iframe = document.getElementById('hidden_frame'); //annoying, cannot attach to window.hidden_frame in FF!
        iframe.addEventListener("load", iframe_load);

        $tag_links.click(function (event) {
            event.preventDefault();
            if (CHANGED)
                confirm
            var data = $(this).data();
            show_tag(LOCALE, data.tag);
        });

        //attach listeners as delegates since they are injected into the dom
        $post_form.delegate('textarea', 'change, keypress', function() {
            form_changed();
        });

        $post_form.delegate('#cancel_button', 'click', function () {
            clear_form();
        });

        $post_form.delegate('#reload_button', 'click', function () {
            var data = $(this).data();
            show_tag(LOCALE, data.tag);
        });

        $post_form.delegate('#locale', 'change', function () {
            var data = $(this).data();
            show_tag($(this).val(), data.tag);
        });

        $post_form.delegate('[data-role="show_old_version', 'click', function(event) {
            event.preventDefault()
            var data = $(this).data();
            show_old_version(data.id);
        });


        $post_form.submit(function (){
            CHANGED = false;
            show_whirly(SAVING_STRING);
            setDisabledOnButtons(true);
        });

        //Helpers and callbacks
        function iframe_load() {
            var tag = window.hidden_frame.tag;
            var str = window.hidden_frame.str;
            if (tag != undefined) {  //TODO: Figure out what is going on here
                jQuery("#str_" + tag).html(str).addClass("translated faint");
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

        function show_tag(locale, tag) {
            LOCALE = locale;
            if (!CHANGED || confirm(CONFIRM_STRING)) {
                show_whirly(LOADING_STRING);
                jQuery.ajax("/translation/edit_translations_ajax_get", {
                    data: {locale: locale, tag: tag, authenticity_token: CSRF_TOKEN},
                    dataType: 'text',
                    async: true,
                    error: function (response) {
                        hide_whirly();
                        alert(response.responseText);
                    },
                    success: function (html) {
                        hide_whirly();
                        $form_div.html(html);
                        CHANGED = false;
                        LOADED = true;
                    }
                });
            }
        }

        function clear_form() {
            $form_div.html('');
            LOADED = false;
            CHANGED = false;
        }

        function show_old_version(id) {
            show_whirly(LOADING_STRING);
            jQuery.ajax("/ajax/old_translation/" + id, {
                data: {authenticity_token: CSRF_TOKEN},
                dataType: 'text',
                async: true,
                success: function (text) {
                    hide_whirly();
                    alert(text);
                }
            });
        }

        function setDisabledOnButtons(disabled) {
            $save_button.prop("disabled", disabled);
            $cancel_button.prop("disabled", !disabled);
        }

        function show_whirly(text) {
            jQuery("#whirly_text").html(text);
            $whirly.center().show();
        }

        function hide_whirly() {
            $whirly.hide();
        }
    });
}
