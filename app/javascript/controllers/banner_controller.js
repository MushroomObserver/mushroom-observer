import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["banner", "dismissButton"]

  connect() {
    this.dismissButtonTarget.addEventListener('click', this.dismiss.bind(this));
  }

  dismiss() {
    const version = this.dismissButtonTarget.dataset.version;
    document.cookie = `dismissed_banner_version=${version}; path=/; max-age=31536000`; // 1 year
    this.bannerTarget.style.display = 'none';
  }
}
