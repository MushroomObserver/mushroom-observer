import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["banner", "dismissButton", "showButton"];

  connect() {
    this.dismissButtonTarget.addEventListener("click", this.dismiss.bind(this));
    this.showButtonTarget.addEventListener("click", this.show.bind(this));

    if (this.isBannerDismissed()) {
      this.hideBanner();
      this.showShowButton(true); // Show the chevron
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
    this.bannerTarget.style.display = "none";
  }

  showBanner() {
    this.bannerTarget.style.display = "block";
  }

  hideShowButton() {
    document.getElementById("show-banner-container").style.display = "none";
  }

  showShowButton() {
    document.getElementById("show-banner-container").style.display = "block";
  }
}
