/**
 * This script simply makes it so that if someone clicks on the span, it
 * checks the checkbox. Makes it easier to check or uncheck the filter
 * checkboxes on rss_logs/_type_filters
 */

$(document).on("ready turbo:load", function () {
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
