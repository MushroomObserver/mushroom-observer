// Patch to make matrix boxes in a row the same height
// TODO: Completely remove this script and layouts/app/media_query_tests partial
// if moving to Bootstrap 4+

$(window).on('load', function () {
  var boxes = jQuery('.matrix-box .panel-sizing');
  var footers = jQuery('.matrix-box .log-footer');

  //if there are matrix boxes
  if (boxes) { arrangeResizing(boxes) }
  if (footers) { arrangeResizing(footers) }

  function arrangeResizing(elems) {
    //get the current bootstrap media query size
    var dataBootstrapSize = jQuery("[data-bootstrap-size]:visible").data('bootstrap-size');
    if (dataBootstrapSize != "xs") {
      //xs size doesn't need anything
      var arrayedObjects = elems.toArray().map(function (el) {
        return jQuery(el);
      });
      switch (dataBootstrapSize) {
        case "xs":
          return; //do nothing;
        case "sm":
          adjustHeightForEveryNth(arrayedObjects, 2);
          break;
        case "md":
          adjustHeightForEveryNth(arrayedObjects, 3);
          break;
        case "lg":
          adjustHeightForEveryNth(arrayedObjects, 4);
          break;
        default:
          //no op
          break;
      }
    }
  }

  function adjustHeightForEveryNth(array, nth) {
    var splicedAndSorted = array.splice(0, nth)//splices changes array in place, returns spliced items
      .sort(function (a, b) {
        return b.height() - a.height(
        )
      });

    if (splicedAndSorted.length <= 1) //we don't have enough boxes to compare...
      return; //...so return
    splicedAndSorted.forEach(function (item) {
      item.height(splicedAndSorted[0].height());
    });
    adjustHeightForEveryNth(array, nth); //recursion through elements, passing back in the modified array
  }
});
