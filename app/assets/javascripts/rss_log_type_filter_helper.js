/**
 * This script simply makes it so that if someone clicks on the span that it
 * checks the checkbox. Makes it easier to check / uncheck the filter
 * checkboxes on _rss_log_type_filters
 */

jQuery(document).ready(function () {
  jQuery("[data-toggle='checkbox']").on('click', function () {
    var $checkbox = $(this).find('input[type="checkbox"]');
    $checkbox.prop('checked', !$checkbox.prop('checked'));
  });

  jQuery("[data-toggle='checkbox'] input").on('click', function (e) {
    e.stopPropagation();
  });

  jQuery("[data-toggle='checkbox'] a").on('click', function (e) {
    e.stopPropagation();
  });
});
