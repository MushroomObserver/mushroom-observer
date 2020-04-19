/**
 * This script simply makes it so that if someone clicks on the span that it checks the checkbox
 * Makes it easier to check and uncheck the filter checkboxes on _rss_log_tabset
 */

jQuery(document).ready(function() {
    jQuery("[data-toggle='checkbox']").click(function() {
        var $checkbox = $(this).find('input[type="checkbox"]');
            $checkbox.prop('checked', !$checkbox.prop('checked'));
    });

    jQuery("[data-toggle='checkbox'] input").click(function(e) {
        e.stopPropagation();
    });

    jQuery("[data-toggle='checkbox'] a").click(function(e) {
        e.stopPropagation();
    });
});
