function APIKeyModule() {
  jQuery(document).ready(function () {

    // bindings
    jQuery('[data-role="edit_api_key"]').on('click', function (event) {
      var keyId = $(this).data().id;
      event.preventDefault();
      shouldShowEditFields(keyId, true);
    });

    jQuery('[data-role="activate_api_key"]').on('click', function (event) {
      var keyId = $(this).data().id;
      event.preventDefault();
      activateKey(keyId);
    });

    jQuery('[data-role="key_notes_input"]').keypress(function (e) {
      var keyId = $(this).data().id;
      if (e.keyCode == 27) { // escape key
        shouldShowEditFields(keyId, false);
      }
      if (e.keyCode == 13) {
        allowFormSubmit(false);
        saveKey(keyId);
      }
    });

    jQuery('[data-role="key_notes_save"]').on('click', function () {
      var keyId = $(this).data().id;
      saveKey(keyId);
    });

    jQuery('[data-role="key_notes_cancel"]').on('click', function () {
      var keyId = $(this).data().id;
      shouldShowEditFields(keyId, false);
    });

    // functions
    function shouldShowEditFields(keyId, showEdit, newNoteText) {
      var $editFormContainer = jQuery('.edit_key_notes_container[data-target-key=' + keyId + ']'),
        $currentNotesContainer = jQuery('.view_key_notes_container[data-target-key=' + keyId + ']');

      if (showEdit) {
        jQuery("#remove_button, #create_button").attr('disabled', true);
        allowFormSubmit(false);
        $currentNotesContainer.hide();
        $editFormContainer.show();
        $editFormContainer.children('input').first().focus();
      }

      else {
        allowFormSubmit(true);
        jQuery("#remove_button, #create_button").attr('disabled', false);
        $editFormContainer.hide();
        $currentNotesContainer.show();
        if (newNoteText)
          $currentNotesContainer.children('.current_notes').first().text(newNoteText);
      }
    }

    // This is an ugly hack because pressing the enter button while editing a key notes
    // causes the entire form to submit in firefox instead of just changing the note via ajax.
    function allowFormSubmit(shouldSubmit) {
      if (!shouldSubmit) {
        $('form').bind('submit.disable', function (event) {
          event.preventDefault();
          return false;
        });
      } else {
        $('form').unbind('submit.disable');
      }
    }

    function saveKey(id) {
      var notes = jQuery('[data-role="key_notes_input"][data-id=' + id + ']').val();
      jQuery.ajax("/ajax/api_key/edit/" + id, {
        data: { value: notes, authenticity_token: csrf_token() },
        dataType: "text",
        async: true,
        error: function (response) {
          shouldShowEditFields(id, false);
          alert(response.responseText);
        },
        success: function (data) {
          shouldShowEditFields(id, false, data)
        }
      })
    }

    function activateKey(id) {
      jQuery.ajax("/ajax/api_key/activate/" + id, {
        data: { authenticity_token: csrf_token() },
        dataType: "text",
        async: true,
        error: function (response) {
          alert(response.responseText);
        },
        success: function () {
          jQuery("#key_time_" + id).html("--");
        }
      })
    }
  })
}
