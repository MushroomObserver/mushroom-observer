import { Controller } from "@hotwired/stimulus"

// Controller just removes ANY modal. it's a handler for page elements that
// get updated on successful form submit, so it "cleans up"
export default class extends Controller {
  // static targets = ["form"] // unused rn
  static values = { user: Number }

  connect() {
    // console.log("Hello Modal " + this.element.id);
    this.element.dataset.modal = "connected"
  }

  // Modal form is only removed in the event that the page section updates.
  // That event is broadcast from the section-update controller with a user id.
  // Only remove the modal if the updating user is the same who has modal open.
  // We can't fire based on submit response, because unless something's wrong
  // with the request, turbo-stream will send a 200 OK even if it didn't save.
  remove(event) {
    const initiatingUser = event?.detail?.user
    if (!initiatingUser || initiatingUser !== this.userValue) { return }

    // console.log("Removing modal")
    this.hide()
    this.element.remove()
  }

  // The modal_ajax_progress for voting should only be hidden,
  // since it is printed in the layout and should not be removed from the page.
  // Must be in jQuery for Boostrap 3 and 4
  hide() {
    // console.log("Hiding modal")
    $(this.element).modal('hide')
    this.resetProgress()
  }

  // Reset the text within the progress modal, if it exists.
  resetProgress() {
    document.getElementById('mo_ajax_progress_caption').innerHTML = ""
  }
}
