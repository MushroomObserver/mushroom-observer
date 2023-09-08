import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal"]

  // this should remove modal. it's a handler for page elements that
  // get updated on successful form submit, so it "cleans up"
  initialize() {
    console.log("Hello Modal");
  }

}
