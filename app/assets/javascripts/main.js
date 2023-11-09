/**
 * This should be included on every page.
 */

// This observer is a stopgap that handles what Stimulus would handle:
// observes page changes and whether they should fire js.
function moObserveContent() {
  // Select the node that will be observed for mutations
  const contentNode = document.body;

  // Options for the observer (which mutations to observe)
  const config = { attributes: true, childList: true, subtree: true };

  // Callback function to execute when mutations are observed
  const callback = (mutationList, observer) => {
    for (const mutation of mutationList) {
      if (mutation.type === "childList") {
        // console.log("A child node has been added or removed.");
        if (window.lazyLoadInstance != undefined)
          window.lazyLoadInstance.update();
      } else if (mutation.type === "attributes") {
        // console.log(`The ${mutation.attributeName} attribute was modified.`);
      }
    }
  };

  // Create an observer instance linked to the callback function
  const observer = new MutationObserver(callback);

  // Start observing the target node for configured mutations
  observer.observe(contentNode, config);
}

moObserveContent();
