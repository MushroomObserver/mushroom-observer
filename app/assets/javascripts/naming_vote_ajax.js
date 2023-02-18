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
        $('#mo_ajax_progress_caption').empty().append(
          $("<span>").text(translations.show_namings_saving + "... "),
          $("<span class='spinner-right mx-2'></span>")
        );
        $("#mo_ajax_progress").modal({ backdrop: 'static', keyboard: false });
      });
    };

    attach_bindings();
  });
}
