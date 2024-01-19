import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="matrix-table"
export default class extends Controller {
  connect() {
    this.element.dataset.stimulus = "connected";

    this.matrixBoxes = document.querySelectorAll('.matrix-box')
    this.boxes = document.querySelectorAll('.matrix-box .panel-sizing')
    this.footers = document.querySelectorAll('.matrix-box .log-footer')

    this.add_spacers()
    this.rearrange()
  }

  add_spacers() {
    this.matrixBoxes.forEach((element, i) => {
      if (i % 2 == 0) {
        element.insertAdjacentElement('beforebegin', this.smSpacer())
      }
      if (i % 3 == 0) {
        element.insertAdjacentElement('beforebegin', this.mdSpacer())
      }
      if (i % 4 == 0) {
        element.insertAdjacentElement('beforebegin', this.lgSpacer())
      }
    })
  }

  smSpacer() {
    const spacer = document.createElement('div')
    spacer.classList.add('hidden', 'visible-sm-block')
    spacer.style.clear = "left"
    return spacer
  }

  mdSpacer() {
    const spacer = document.createElement('div')
    spacer.classList.add('hidden', 'visible-md-block')
    spacer.style.clear = "left"
    return spacer
  }

  lgSpacer() {
    const spacer = document.createElement('div')
    spacer.classList.add('hidden', 'visible-lg-block')
    spacer.style.clear = "left"
    return spacer
  }

  rearrange() {
    this.breakpoint =
      Array.from(document.querySelectorAll('[data-breakpoint]')).filter(s =>
        window.getComputedStyle(s).getPropertyValue('display') != 'none'
      )[0].dataset.breakpoint

    if (this.breakpoint != "xs") {
      if (this.boxes.length) { this.arrangeResizing(this.boxes) }
      if (this.footers.length) { this.arrangeResizing(this.footers) }
    }
  }

  arrangeResizing(elements) {
    // get the current bootstrap media query size
    // xs size doesn't need anything
    const arrayedObjects = Array.from(elements)

    switch (this.breakpoint) {
      case "xs":
        return // do nothing;
      case "sm":
        this.adjustHeightForEveryNth(arrayedObjects, 2)
        break
      case "md":
        this.adjustHeightForEveryNth(arrayedObjects, 3)
        break
      case "lg":
        this.adjustHeightForEveryNth(arrayedObjects, 4)
        break
      default:
        //no op
        break
    }
  }

  adjustHeightForEveryNth(array, nth) {
    // splices changes array in place, returns spliced items
    const splicedAndSorted = array.splice(0, nth).sort((a, b) => {
      return b.clientHeight - a.clientHeight
    });

    // we don't have enough boxes to compare...
    if (splicedAndSorted.length <= 1)
      return; // ...so return

    splicedAndSorted.forEach((item) => {
      item.style.height = splicedAndSorted[0].clientHeight + "px"
    });

    // recursion through elements, passing back in the modified array
    this.adjustHeightForEveryNth(array, nth);
  }
}
