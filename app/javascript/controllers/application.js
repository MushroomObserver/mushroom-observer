import { Application } from "@hotwired/stimulus"
import { Autocomplete } from "stimulus-autocomplete"

const application = Application.start()

class CustomAutocomplete extends Autocomplete {
  buildURL(query) {
    return `${new URL(this.urlValue, window.location.href).toString()}/${query}`
  }
}

application.register('autocomplete', CustomAutocomplete)
// application.register('autocomplete', Autocomplete)

// Configure Stimulus development experience
application.debug = false
window.Stimulus = application

export { application }
