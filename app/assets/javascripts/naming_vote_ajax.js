function VoteByAjaxModule(translations) {
  $(document).ready(function () {

    var _haveVotesChanged = false;
    var _haveVotesBeenSaved = false;

    var save_vote_buttons = function () {
      return $("[data-role='save_vote']");
    };

    var change_vote_selects = function () {
      return $("[data-role='change_vote']");
    };

    var attach_bindings = function () {
      change_vote_selects().on("change", function (event) {
        var _this = $(this);
        var value = _this.val();
        var naming_id = _this.data("id");
        _haveVotesChanged = true;

        // If setting vote to 3.0, go through all the rest and downgrade any
        // old 3.0's to 2.0.  Only one 3.0 vote is allowed. Also disable all
        // the menus while the AJAX request is pending.
        if (value == "3.0") {
          change_vote_selects().each(function () {
            var _this2 = $(this);
            if (_this2.data("id") != naming_id && _this2.val() == "3.0") {
              _this2.val("2.0");
            }
            _this2.attr("disabled", "disabled");
          });
        }

        // progress modal printed in layout already, just activate it
        $('#naming_ajax_progress_caption').empty().append(
          $("<span>").text(translations.show_namings_saving + "... "),
          $("<span class='spinner-right mx-2'></span>")
        );
        $("#naming_ajax_progress").modal('show');

        $.ajax("/votes/" + naming_id, {
          type: 'PATCH',
          data: { vote: { value: value }, authenticity_token: csrf_token() },
          dataType: "script",
          async: true,
          complete: function (request) {
            _haveVotesChanged = false;
            $('#naming_ajax_progress_caption').empty();
            $('#naming_ajax_progress').modal('hide');
            if (request.status == 200) {
              attach_bindings();
              if (typeof SuggestionModule !== "undefined")
                attach_suggestion_bindings();
              save_vote_buttons().hide();
            } else {
              change_vote_selects().each(function () {
                _this.val(_this.data("old_value"))
                  .attr("disabled", null);
              });
              alert(request.responseText);
            }
          }
        });
      });

      // Save initial value in case of error, when we'll need to revert.
      change_vote_selects().each(function (event) {
        var _this = $(this);
        _this.data("old_value", _this.val());
        _this.attr("disabled", null);
      });
    };

    // Alert the user if they haven't saved data.
    window.onbeforeunload = function () {
      if (_haveVotesChanged && !_haveVotesBeenSaved)
        return translations.show_namings_lose_changes;
    }

    attach_bindings();

    // Don't need this if AJAX available.
    save_vote_buttons().hide();
  });
}
