import { Controller } from "@hotwired/stimulus"
import lightGallery from 'lightgallery'
import lgZoom from 'lightgallery/plugins/zoom'

// Connects to data-controller="lightgallery", currently "#content"
export default class extends Controller {
  connect() {
    this.element.dataset.lightgallery = "connected";

    this.gallery = lightGallery(this.element, {
      selector: '.theater-btn',
      plugins: [lgZoom],
      licenseKey: '3B4BAB91-98EF-411A-975E-3334D00D1A8C',
      defaultCaptionHeight: 200,
      // The caption is a real, hidden DOM element nested inside each
      // `.theater-btn` (see Components::Image::Base#render_lightbox_caption),
      // not a captured-HTML string -- `data-sub-html` on the theater-btn
      // is the CSS selector ".lightbox-caption" now. `relative: true`
      // scopes lightGallery's lookup to the specific item
      // ($LG(items).eq(index).find(selector)) instead of grabbing the
      // first ".lightbox-caption" anywhere on the page. See #4894.
      subHtmlSelectorRelative: true
    });

    // Turbo Streams update the hidden caption / vote-section DOM
    // directly now (ordinary `update`/`replace` actions), but
    // lightGallery only re-reads a slide's caption on open or slide
    // transition, not via a DOM mutation observer -- so an already-open
    // lightbox needs an explicit refresh to pick up a stream-driven
    // change. Listen generically rather than adding a custom Turbo
    // Stream action per caller.
    this.boundMaybeRefresh = this.maybeRefreshOnStream.bind(this);
    document.addEventListener(
      'turbo:before-stream-render', this.boundMaybeRefresh
    );

    // `.theater-btn` is a <div> now, not an <a> (#4894 -- it nests
    // interactive content an <a> can't legally contain), so it lost
    // native keyboard activation. lightGallery binds its own click
    // listener directly to each `.theater-btn`; translate Enter/Space
    // into a click on it rather than reimplementing gallery-opening
    // logic. Only when `.theater-btn` itself is the event target --
    // not when focus is on a button/link nested inside it (vote,
    // propose-naming), which should keep its own Enter/Space behavior.
    this.boundActivateOnKey = this.activateTheaterBtnOnKey.bind(this);
    this.element.addEventListener('keydown', this.boundActivateOnKey);
  }

  disconnect() {
    if (this.gallery) {
      this.gallery.destroy();
    }
    document.removeEventListener(
      'turbo:before-stream-render', this.boundMaybeRefresh
    );
    this.element.removeEventListener('keydown', this.boundActivateOnKey);
  }

  activateTheaterBtnOnKey(event) {
    if (event.key !== 'Enter' && event.key !== ' ') return;
    if (!event.target.classList.contains('theater-btn')) return;

    event.preventDefault();
    event.target.click();
  }

  // `turbo:before-stream-render` fires BEFORE Turbo actually applies
  // the stream's DOM change (Turbo calls `event.detail.render(...)`,
  // itself async, after dispatching this event) -- calling
  // `refreshCaption` synchronously here would copy the caption's
  // stale, pre-update content. Wrap `render` so the refresh runs
  // after the real DOM mutation completes.
  maybeRefreshOnStream(event) {
    const target = event.target.target;
    if (!target || !/^(lightbox_caption_|lightbox_image_vote_)/.test(target)) {
      return;
    }

    const originalRender = event.detail.render;
    event.detail.render = async (streamElement) => {
      await originalRender(streamElement);
      this.refreshCaption();
    };
  }

  // `gallery.refresh()` does NOT re-copy the caption -- it only
  // rebuilds the item list and re-binds click handlers. lightGallery
  // copies `.lightbox-caption`'s innerHTML into `.lg-sub-html` (a
  // separate DOM subtree, not a live reference) only on initial slide
  // insertion or slide transitions -- `addHtml(index)` is the actual
  // method that does that copy, and it re-resolves the selector fresh
  // from the live DOM every time it's called. Call it directly for
  // the currently-open slide so a Turbo Stream update (e.g. a vote,
  // or the reviewed toggle) shows up without navigating away and back.
  refreshCaption() {
    if (this.gallery && this.gallery.lgOpened) {
      this.gallery.addHtml(this.gallery.index);
    }
  }
}
