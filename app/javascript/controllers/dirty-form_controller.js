import { Controller } from "@hotwired/stimulus";

// Warns the user before navigating away from a form with unsaved
// changes. Attach with data-controller="dirty-form" on a <form>;
// add data-action="submit->dirty-form#allowSubmit" so the warning
// is suppressed on intentional submission. Issue #4148.
export default class extends Controller {
  connect() {
    this.dirty = false;
    this.snapshot = this.serialize();
    this.boundInputHandler = this.checkDirty.bind(this);
    this.boundBeforeUnload = this.beforeUnload.bind(this);

    this.element.addEventListener("input", this.boundInputHandler);
    this.element.addEventListener("change", this.boundInputHandler);
    window.addEventListener("beforeunload", this.boundBeforeUnload);
  }

  disconnect() {
    this.element.removeEventListener("input", this.boundInputHandler);
    this.element.removeEventListener("change", this.boundInputHandler);
    window.removeEventListener("beforeunload", this.boundBeforeUnload);
  }

  // Wired via data-action submit->dirty-form#allowSubmit so an
  // intentional Save bypasses the warning.
  allowSubmit() {
    this.dirty = false;
  }

  checkDirty() {
    this.dirty = this.serialize() !== this.snapshot;
  }

  beforeUnload(event) {
    if (!this.dirty) return;
    // Setting returnValue is what triggers the native dialog;
    // modern browsers ignore the actual string and use their own.
    event.preventDefault();
    event.returnValue = "";
    return "";
  }

  // Serialize the form's input values into a stable string so we
  // can detect any change. FormData is keyed by input name and
  // preserves order, which is enough for a snapshot.
  serialize() {
    const data = new FormData(this.element);
    const parts = [];
    for (const [key, value] of data.entries()) {
      // Skip File objects (their identity changes on every read).
      if (value instanceof File) continue;
      parts.push(`${key}=${value}`);
    }
    return parts.join("&");
  }
}
