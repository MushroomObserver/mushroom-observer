import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["truncated", "full", "showFull", "showTruncated"];

  connect() {
    this.element.dataset.filterCaption = "connected";
    // check if length of text of full is greater than link of text of trunc
    // if not, hide the buttons
    this.fullLength = this.fullTarget.lastChild.innerText.length
    this.truncLength = this.truncatedTarget.lastChild.innerText.length
    if (Math.abs(this.fullLength - this.truncLength) <= 3) {
      this.hideButtons()
    }
  }

  showFull() {
    $(this.truncatedTarget).collapse('hide');
    $(this.fullTarget).collapse('show');
  }

  showTruncated() {
    $(this.fullTarget).collapse('hide');
    $(this.truncatedTarget).collapse('show');
  }

  hideButtons() {
    this.showFullTarget.classList.add("d-none");
  }
}
