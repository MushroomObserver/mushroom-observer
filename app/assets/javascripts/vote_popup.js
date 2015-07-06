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
      var _this = $(this); //references the vote being changed
      _haveVotesChanged = true;  //votes have been changed
      getUserAttention();
      // If setting vote to 3.0, go through all the rest and downgrade any
      // old 3.0's to 2.0.  Only one 3.0 vote is allowed.
      if (_this.val() == "3.0") {
        var changedNamingId = _this.data().id;
        $change_vote_selects.each(function () {
          if ($(this).data().id != changedNamingId && $(this).val() == "3.0")
            $(this).val("2.0");
        });
      }
    });

    // Alert the user if they haven't saved data.
    window.onbeforeunload = function () {
      if (_haveVotesChanged && !_haveVotesBeenSaved)
        return showNamingsLostChangesText;
    }

    // Blinks some bold text on the update votes button to alert the user they
    // need to update the votes.
    function getUserAttention(timesFlashed) {
      var _timesToFlash = 3;
      if (timesFlashed == undefined)
        timesFlashed = 0;
      setTimeout(function () {
        if (_timesToFlash > timesFlashed) {
          $save_votes_button.toggleClass("bold");
          getUserAttention(timesFlashed + 1);
        }
      }, 300);
    }
  });
}
