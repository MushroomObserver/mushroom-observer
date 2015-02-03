jQuery(document).ready(function () {
  jQuery('body').on('click', '[data-confirm]', function (event) {
    return confirm($(this).data().confirm);
  })
});
