import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["banner", "dismissButton", "showButton"];

  connect() {
    this.element.dataset.banner = "connected";
    this.dismissButtonTarget.addEventListener("click", this.dismiss.bind(this));
    this.showButtonTarget.addEventListener("click", this.show.bind(this));

    if (this.isBannerDismissed()) {
      this.hideBanner();
      this.showShowButton();
    } else {
      this.showBanner();
      this.hideShowButton();
    }
  }

  dismiss() {
    const version = this.dismissButtonTarget.dataset.version;
    document.cookie = `dismissed_banner_version=${version}; path=/; max-age=31536000`; // 1 year
    this.hideBanner();
    this.showShowButton();
  }

  show() {
    document.cookie = `dismissed_banner_version=; path=/; max-age=0`; // Clear the cookie
    this.showBanner();
    this.hideShowButton();
  }

  isBannerDismissed() {
    const version = this.dismissButtonTarget.dataset.version;
    return document.cookie
      .split("; ")
      .some((cookie) => cookie === `dismissed_banner_version=${version}`);
  }

  hideBanner() {
    this.bannerTarget.classList.remove('d-block');
    this.bannerTarget.classList.add('d-none');
  }

  showBanner() {
    this.bannerTarget.classList.remove('d-none');
    this.bannerTarget.classList.add('d-block');
  }

  // No `d-block` add/remove here (unlike hideBanner/showBanner) --
  // this button is a `.btn:has(.mo-icon)`, and _icons.scss already
  // gives it `display: inline-flex` for icon centering. Adding
  // Bootstrap's `.d-block` (`display: block !important`) would
  // override that via !important, un-centering the icon and making
  // the button taller than its search/qrcode siblings.
  hideShowButton() {
    this.showButtonTarget.classList.add('d-none');
  }

  showShowButton() {
    this.showButtonTarget.classList.remove('d-none');
  }
}
