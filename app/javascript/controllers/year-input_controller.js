import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="year-input"
export default class extends Controller {
  connect() {
    this.id = this.element.getAttribute("id");
    // console.log(this.id)

    if (this.id && this.id.indexOf("_1i") > 0) {
      this.element.setAttribute("data-stimulus", "connected")
      // copy the attributes
      this.name = this.element.getAttribute("name");
      this.classList = this.element.classList || "";
      this.style = this.element.getAttribute("style") || "";
      this.value = this.element.value;

      this.turnIntoTextField();
    }
  }

  disconnect() {
    this.element.setAttribute("data-stimulus", "disconnected")
  }

  turnIntoTextField() {
    this.new_elem = document.createElement("input");
    this.new_elem.type = "text";
    this.new_elem.setAttribute("class", this.classList.value);
    this.new_elem.style = this.style;
    this.new_elem.value = this.value;
    this.new_elem.setAttribute("size", 4);
    // dataset must be set one at the time
    if (this.element.dataset != undefined) {
      for (const prop in this.element.dataset) {
        if (!["controller", "stimulus"].includes(prop))
          this.new_elem.setAttribute('data-' + prop,
            this.element.dataset[prop]);
      }
    }

    this.new_elem.setAttribute("name", this.name);
    this.new_elem.setAttribute("id", this.id);
    this.element.replaceWith(this.new_elem);
    this.element.remove();
  }
}
