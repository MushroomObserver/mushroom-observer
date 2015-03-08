$(window).load(function () {
    var boxes = jQuery('.rss-box-details');

    if (boxes) {
        var dataBootstrapSize = jQuery("[data-bootstrap-size]:visible").data('bootstrap-size');
        if (dataBootstrapSize != "xs") {
            var arrayedObjects = boxes.toArray().map(function (el) {
                return jQuery(el)
            });
            switch (dataBootstrapSize) {
                case "xs":
                    return;
                case "sm":
                    forEveryNth(arrayedObjects, 2);
                    break;
                case "md":
                    forEveryNth(arrayedObjects, 3);
                    break;
                case "lg":
                    forEveryNth(arrayedObjects, 4);
                    break;
            }
        }
    }

    function forEveryNth(array, nth) {
        var splicedAndSorted = array.splice(0, nth)
            .sort(function (a, b) {
                return b.height() - a.height(
                    )
            });

        if (splicedAndSorted.length <= 1)
            return;
        splicedAndSorted.forEach(function (item) {
            item.height(splicedAndSorted[0].height());
        });
        forEveryNth(array, nth);
    }
});