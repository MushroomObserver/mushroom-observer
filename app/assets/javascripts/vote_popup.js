function VotePopupModule(showNamingsLostChangesText) {
  jQuery(document).ready(function () {

    // elements to be bound
    var $save_votes_button = jQuery("[data-role='save_votes']"),
        $close_popup_buttons = jQuery("[data-role='close_popup']"),
        $open_popup_buttons = jQuery("[data-role='open_popup']"),
        $change_vote_selects = $("[data-role='change_vote']"),
        $vote_popups = jQuery("[data-role='popup']"),
        _haveVotesChanged = false,
        _haveVotesBeenSaved = false;

    // bindings
    $save_votes_button.click(function () {
      _haveVotesBeenSaved = true;
    });

    $close_popup_buttons.click(function () {
      jQuery(this).parents(".popup").first().hide();
    });

    $open_popup_buttons.click(function (event) {
      event.preventDefault();
      console.log(event);
      var namingId = jQuery(this).data("id");
      $vote_popups.hide(); //hide any other popups that might be open
      jQuery("#show_votes_" + namingId)
        .center().show();
    });

    $change_vote_selects.change(function (event) {
      var _this = $(this);
      var value = _this.val();
      var naming_id = _this.data("id");
      _haveVotesChanged = true;
      _this.attr("disabled", "disabled");

      // If setting vote to 3.0, go through all the rest and downgrade any
      // old 3.0's to 2.0.  Only one 3.0 vote is allowed.
      if (value == "3.0") {
        $change_vote_selects.each(function () {
          var _this2 = $(this);
          if (_this2.data("id") != naming_id && _this2.val() == "3.0") {
            _this2.val("2.0");
            _this2.attr("disabled", "disabled");
          }
        });
      }

      jQuery.ajax("/ajax/vote/naming/" + naming_id, {
        data: {value: value, authenticity_token: csrf_token()},
        dataType: "text",
        async: true,
        complete: function (request) {
          _haveVotesChanged = false;
          if (request.status == 200) {
            $change_vote_selects.each(function () {
              $(this).data("old_value", $(this).val())
                     .attr("disabled", null);
            });
          } else {
            $change_vote_selects.each(function () {
              $(this).val($(this).data("old_value"))
                     .attr("disabled", null);
            });
            alert(request.responseText);
          }
        }
      });

    }).each(function (event) {
      $(this).data("old_value", $(this).val());
    });

    // Alert the user if they haven't saved data.
    window.onbeforeunload = function () {
      if (_haveVotesChanged && !_haveVotesBeenSaved)
        return showNamingsLostChangesText;
    }

    // Don't need this if AJAX available.
    $save_votes_button.hide();
  });
}
