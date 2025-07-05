import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["banner", "container", "dismissButton", "showButton"];

  connect() {
    this.element.dataset.banner = "connected";
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
    this.bannerTarget.classList.remove('d-block');
    this.bannerTarget.classList.add('d-none');
  }

  showBanner() {
    this.bannerTarget.classList.remove('d-none');
    this.bannerTarget.classList.add('d-block');
  }

  hideShowButton() {
    this.containerTarget.classList.remove('d-block');
    this.containerTarget.classList.add('d-none');
  }

  showShowButton() {
    this.containerTarget.classList.remove('d-none');
    this.containerTarget.classList.add('d-block');
  }
}
