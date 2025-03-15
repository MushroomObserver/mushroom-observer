import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["truncated", "full", "showFull", "showTruncated"];

  connect() {
    this.element.dataset.stimulus = "filter-caption-connected";
    // check if length of text of full is greater than link of text of trunc
    // if not, hide the buttons
    this.fullLength = this.fullTarget.lastChild.innerText.length
    this.truncLength = this.truncatedTarget.lastChild.innerText.length
    if (Math.abs(this.fullLength - this.truncLength) <= 9) {
      this.hideButtons()
    }
  }

  showFull() {
    this.truncatedTarget.classList.remove("d-block");
    this.truncatedTarget.classList.add("d-none");
    this.fullTarget.classList.add("d-block");
    this.fullTarget.classList.remove("d-none");
  }

  showTruncated() {
    this.fullTarget.classList.remove("d-block");
    this.fullTarget.classList.add("d-none");
    this.truncatedTarget.classList.add("d-block");
    this.truncatedTarget.classList.remove("d-none");
  }

  hideButtons() {
    this.showFullTarget.classList.add("d-none");
  }
}
