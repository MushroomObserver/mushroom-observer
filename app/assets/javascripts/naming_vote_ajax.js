// Voting can be slow, so this script disables other form elements
// while waiting for an AJAX response.

function VoteByAjaxModule(translations) {
  $(document).ready(function () {

    var save_vote_buttons = function () {
      return $("[data-role='save_vote']");
    };

    // Don't need these if AJAX available.
    save_vote_buttons().hide();

    var change_vote_selects = function () {
      return $("[data-role='change_vote']");
    };

    var attach_bindings = function () {
      change_vote_selects().on("change", function (event) {
        // bootstrap modal printed in layout already, just activate it
        $('#naming_ajax_progress_caption').empty().append(
          $("<span>").text(translations.show_namings_saving + "... "),
          $("<span class='spinner-right mx-2'></span>")
        );
        $("#naming_ajax_progress").modal({ backdrop: 'static', keyboard: false });

        // fire the special rails-ujs submit event for remote submit
        // requires a native js (not jQuery) element, form is parent of select
        var nativeFormEl = $(this).parent()[0];
        Rails.fire(nativeFormEl, 'submit');
      });
    };

    attach_bindings();
  });
}
