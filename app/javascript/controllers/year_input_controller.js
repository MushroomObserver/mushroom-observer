import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="year-input"
export default class extends Controller {
  connect() {
    this.id = this.element.getAttribute("id");

    if (this.id.indexOf("_1i") > 0) {
      this.turnIntoTextField();
    }
  }

  turnIntoTextField() {
    // copy the attributes
    this.name = this.element.getAttribute("name");
    this.classList = this.element.classList;
    this.style = this.element.getAttribute("style");
    this.value = this.element.value;

    this.new_elem = document.createElement("input");
    this.new_elem.type = "text";
    this.new_elem.classList = classList;
    this.new_elem.style = style;
    this.new_elem.value = value;
    this.new_elem.setAttribute("size", 4);

    if (this.element[0].onchange)
      this.new_elem.onchange = this.element[0].onchange;

    this.element.replaceWith(this.new_elem);
    this.new_elem.setAttribute("id", this.id);
    this.new_elem.setAttribute("name", this.name);

    this.element = this.new_elem;
  }
}
