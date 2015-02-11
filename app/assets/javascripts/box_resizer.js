jQuery(document).ready(function () {
    var boxes = jQuery('.rss-box-details');
    if (boxes) {

        for (var i = 0; i < boxes.length; i = i + 3) {
            [jQuery(boxes[i]), jQuery(boxes[i + 1]), jQuery(boxes[i + 2])]
                .sort(function (a, b) {
                    return b.height() - a.height()
                })
                .forEach(function (box, i, ary) {
                    box.height(ary[0].height())
                });
        }
    }

    var h = jQuery('body').height();
    jQuery('#navigation').css('min-height', h + 'px');
    jQuery('#right_side').css('min-height', h + 'px');
});