// propose_naming_button - change the link to the naming form to a modal button
$(document).ready(function () {
  var atag = document.getElementById("propose_naming_button");
  var btn = $("<button>")
    .html($(atag).html())
    .addClass($(atag).attr("class"))
    .attr("id", $(atag).attr("id"));
  $.each($(atag).data(), function (name, value) {
    btn.attr('data-' + name, value);
  });
  $(atag).parent().prepend(btn);
  $(atag).remove();
})

$('#modal_propose_naming').on('show.bs.modal', function (event) {
  var button = $(event.relatedTarget) // Button that triggered the modal
  var obs_id = button.data("obs");
  var modal = $(this);
  var url = '/observations/' + obs_id + '/namings/new';
  // Reset in case we had other data in there
  modal.find('.modal-body').empty();

  jQuery.ajax(url, {
    type: 'GET',
    contentType: "text/javascript",
    complete: function (request) {
      if (request.status != 200) {
        modal.find('.modal-body').html(request.responseText);
        alert(request.responseText);
      } else {
        modal.find('.modal-body').html(request.responseText);
      }
    }
  });
})

