/**
 * This should be included on every page.
 */

jQuery(document).ready(function () {

  // This works better than straight autofocus attribute in firefox.
  // Normal autofocus causes it to scroll window hiding title etc.
  jQuery('[data-autofocus=true]').first().focus();

  jQuery('[data-role=link]').on('click', function () {
    window.location = jQuery(this).attr('data-url');
  });

  jQuery('[data-toggle="tooltip"]').tooltip({ container: 'body' });

  // HAMBURGER HELPER
  jQuery('[data-toggle="offcanvas"]').on('click', function () {
    jQuery(document).scrollTop(0);
    jQuery('.row-offcanvas').toggleClass('active');
    jQuery('#main_container').toggleClass('overflow-x-hidden');
  });

  // SEARCH BAR FINDER
  jQuery('[data-toggle="search"]').on('click', function () {
    jQuery(document).scrollTop(0);
    var target = jQuery(this).data().target;
    // jQuery(target).css('margin-top', '32px');
    jQuery(target).toggleClass('d-none d-md-block');
  });

  jQuery('[data-dismiss="alert"]').on('click', function () {
    setCookie('hideBanner2', BANNER_TIME, 30);
  });

  function setCookie(cname, cvalue, exdays) {
    var d = new Date();
    d.setTime(d.getTime() + (exdays * 24 * 60 * 60 * 1000));
    var expires = "expires=" + d.toUTCString();
    document.cookie = cname + "=" + cvalue + "; " + expires
      + ";samesite=lax;path=/";
  }

  jQuery('.file-field :file').on('change', function () {
    var val = $(this).val().replace(/.*[\/\\]/, ''),
      next = $(this).parent().next();
    // If file field immediately followed by span, show selection there.
    if (next.is('span')) next.html(val);
  });

  // Not a great solution, but ok for now.
  jQuery('form :input').on('change', function () {
    var disabled_buttons = $('[data-disable-with]');
    $(disabled_buttons).each(function () {
      $.rails.enableElement(this);
    })
  });

  // very precise binding for dynamically generated lightbox links
  // they are not there on page load, only when lightbox activated
  jQuery('body').on('click', '#lightbox .lb-dataContainer button.lightbox_link', function (e) {
    e.stopPropagation();
    var button = jQuery(e.target),
      modal_target_id = button.data("target");
    // must pass the button itself as second param
    jQuery(modal_target_id).modal("toggle", button);
  });

  // Initialize Verlok LazyLoad
  var lazyLoadInstance = new LazyLoad({
    elements_selector: ".lazy"
    // ... more custom settings?
  });

  // Update lazy loads
  lazyLoadInstance.update();
});

// window.onload = (event) => {
//   const autocompleters = document.querySelectorAll('[data-autocompleter]');
//   // console.log(autocompleters);
//   autocompleters.forEach(element => {
//     // element will have "data-ajax-url" if initialized
//     if (!element.hasAttribute("data-ajax-url") && element.hasAttribute("id")) {
//       const input_id = element.getAttribute("id");
//       const type = element.dataset.autocompleter;

//       // Only initialize the `year` sub-field in Rails date_selects (1i, 2i, 3i)
//       if (type != "year" || type == "year" && input_id.indexOf("_1i") > 0) {
//         new MOAutocompleter({
//           input_id: input_id,
//           token: element.dataset.autocomplete_separator
//         });
//       }
//     }
//   });
// }

const moObserveContent = function () {
  // Select the node that will be observed for mutations
  const contentNode = document.body;

  // Options for the observer (which mutations to observe)
  const config = { attributes: true, childList: true, subtree: true };

  // Callback function to execute when mutations are observed
  const callback = (mutationList, observer) => {
    for (const mutation of mutationList) {
      if (mutation.type === "childList") {
        // console.log("A child node has been added or removed.");
        initializeAutocompleters();
      } else if (mutation.type === "attributes") {
        // console.log(`The ${mutation.attributeName} attribute was modified.`);
      }
    }
  };

  // Create an observer instance linked to the callback function
  const observer = new MutationObserver(callback);

  // Start observing the target node for configured mutations
  observer.observe(contentNode, config);

  // Initialize autocompleters that are not already initialized
  const initializeAutocompleters = function () {
    const autocompleters = document.querySelectorAll(
      '[data-autocompleter]:not([data-ajax-url])'
    );
    // console.log(autocompleters);
    autocompleters.forEach(element => {
      // element will have "data-ajax-url" if initialized
      if (element.hasAttribute("id")) {
        const input_id = element.getAttribute("id");
        const type = element.dataset.autocompleter;
        // console.log("Adding autocompleter for " + type)
        // Only initialize the `year` sub-field in Rails date_selects (1i, 2i, 3i)
        if (type != "year" || type == "year" && input_id.indexOf("_1i") > 0) {
          new MOAutocompleter({
            input_id: input_id,
            token: element.dataset.autocomplete_separator
          });
        }
      }
    });
  }

  window.onload = (event) => {
    initializeAutocompleters();
  }
}

moObserveContent();
