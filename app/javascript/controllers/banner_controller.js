import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="banner"
export default class extends Controller {
  connect() {
    this.element.dataset.stimulus = "connected";
  }

  setCookie() {
    const date = new Date(),
      expiresInDays = 30,
      bannerTime = BANNER_TIME,
      cookie_name = "hideBanner"

    date.setTime(date.getTime() + (expiresInDays * 24 * 60 * 60 * 1000));
    const expiresText = "expires=" + d.toUTCString();
    document.cookie = cookie_name + "=" + bannerTime + "; " + expiresText
      + ";samesite=lax;path=/";
  }
}
