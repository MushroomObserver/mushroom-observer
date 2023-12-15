import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="banner"
export default class extends Controller {
  connect() {
    this.element.dataset.stimulus = "connected";
  }

  setCookie({ params: { time } }) {
    const date = new Date(),
      expiresInDays = 30,
      cookie_name = "hideBanner2=" + time + "; ";

    date.setTime(date.getTime() + (expiresInDays * 24 * 60 * 60 * 1000));
    const expiresText = "expires=" + date.toUTCString() + "; ";

    document.cookie =
      cookie_name + expiresText + "samesite=lax;path=/";
  }
}
