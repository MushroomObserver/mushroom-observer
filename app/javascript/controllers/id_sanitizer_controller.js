import { Controller } from "@hotwired/stimulus"

// Rewrites a form's action, substituting a typed numeric id into the
// URL path just before submit -- for a form whose target (a RESTful
// member route, e.g. /images/:id/reuse) isn't known until the user
// types a value, unlike a per-thumbnail link that already knows its
// id at render time. Rejects anything that isn't a plain positive
// integer; never interpolates the raw typed string anywhere else.
// Usage:
//   <form action="/images/__ID__/reuse?target_type=Observation&target_id=1"
//         data-controller="id-sanitizer"
//         data-id-sanitizer-placeholder-value="__ID__"
//         data-action="submit->id-sanitizer#submit">
//     <input data-id-sanitizer-target="input">
//   </form>
export default class extends Controller {
  static targets = ["input"]
  static values = { placeholder: String }

  submit(event) {
    const id = this.inputTarget.value.trim()
    if (!/^[1-9]\d*$/.test(id)) {
      event.preventDefault()
      return
    }

    this.element.action = this.element.action.replace(
      this.placeholderValue,
      id
    )
  }
}
