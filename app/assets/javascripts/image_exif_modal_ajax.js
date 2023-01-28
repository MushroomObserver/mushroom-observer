$('#image_exif_modal').on('show.bs.modal', function (event) {
  var button = $(event.relatedTarget) // Button that triggered the modal
  var image_id = $(button).data('image') // Extract info from data-* attributes
  var modal = $(this)
  // Reset in case we had other data in there
  modal.find('.modal-title').text('Exif Data');
  modal.find('.modal-body').html('Loading EXIF header&hellip;');

  jQuery.ajax("/ajax/exif/" + image_id, {
    async: true,
    complete: function (request) {
      if (request.status != 200) {
        modal.find('.modal-body').html(request.responseText);
        alert(request.responseText);
      } else {
        modal.find('.modal-title').text('Exif Data for Image ' + image_id);
        modal.find('.modal-body').html(request.responseText);
      }
    }
  });
})
