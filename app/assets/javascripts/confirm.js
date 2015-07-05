jQuery(document).ready(function () {
  jQuery('body').on('click', '[data-confirm]', function (event) {
    var msg = $(this).attr('data-confirm');
    return confirm(msg);
  })
});
