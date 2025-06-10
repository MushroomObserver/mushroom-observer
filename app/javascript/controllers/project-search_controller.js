// app/javascript/controllers/project_search_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { names: Array }
  static targets = ["input"]

  connect() {
    this.element.dataset.projectSearch = "connected";
    // console.log("Project search controller connected")
    // console.log("Names data:", this.namesValue)
    // this.setupInputListener()
  }

  // setupInputListener() {
  //   // Find the autocomplete input using querySelector - no target needed
  //   // const input = this.element.querySelector('input[name="name"]') // Concern
  //   // console.log("Input found:", input)
  //   if (this.hasInputTarget) {
  //     this.inputTarget
  //      input.addEventListener('input', this.checkMatch.bind(this))
  //     input.addEventListener('keyup', this.checkMatch.bind(this))
  //     // Check initial state
  //     this.checkMatch({ target: input })
  //   }
  // }

  checkMatch(event) {
    const inputValue = event.target.value.toLowerCase().trim()
    // console.log("Checking match for:", inputValue)
    if (!inputValue) {
      // console.log("checkMatch: Empty input, setting to off")
      this.setStatusLight('off')
      return
    }

    // Check if input matches the start of any name
    const hasMatch = this.namesValue.some(nameObj =>
      nameObj.text_name.toLowerCase().startsWith(inputValue)
    )

    this.setStatusLight(hasMatch ? 'green' : 'red')
  }

  setStatusLight(state) {
    // console.log("Setting status light to:", state)

    // Find status-light controller using Stimulus application
    const statusLightElement = this.element.querySelector('[data-status-light-target="light"]')?.closest('[data-controller*="status-light"]') // Concern

    if (statusLightElement) {
      const statusLightController = this.application.getControllerForElementAndIdentifier(statusLightElement, "status-light")
      if (statusLightController) {
        statusLightController.setState(state)
      }
    } else {
      // console.log("No status light controller found!")
    }
  }
}
