// propose_naming_button
$('#modal_propose_naming').on('show.bs.modal', function (event) {
  event.stopPropagation();
  var button = $(event.relatedTarget) // Button that triggered the modal
  var href = $(button).attr('href') // Extract info from <a> attributes
  var modal = $(this)
  // Reset in case we had other data in there
  // modal.find('.modal-body').empty();

  jQuery.ajax(href, {
    async: true,
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
