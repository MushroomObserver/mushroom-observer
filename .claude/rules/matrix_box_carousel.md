# Matrix-box carousel — salvaged HTML markup

Background: the `nimmo-matrix-box-carousels` branch rewired every matrix box's
thumbnail slot from a single static image to a tiny per-box Bootstrap
carousel. The branch never merged because per-box image lookups blew up the
index page's DB cost and (pre-lazy-load) image fetch cost. That problem can
be solved separately; the rendered HTML markup is what's worth salvaging
from the branch so a future Phlex re-attempt can recreate it without
re-deriving it.

This doc is the rendered-DOM contract — what `carousel_html(object:,
images:, top_img:, thumbnails: false, **image_args)` produced when called
from `app/views/shared/_matrix_box.html.erb`. Reproduce **this** in Phlex
when the matrix-box-carousel work picks back up.

## Call site on the old branch

```erb
<% if presenter.image_data
     images   = presenter.image_data[:images]
     top_img  = presenter.image_data[:thumb_image] || images.first
     image_args = local_assigns.except(:columns, :object, :object_counter,
                                       :object_iteration).
                                merge(presenter.image_data.except(:images) || {})
   end %>
...
<% if presenter.image_data %>
  <%= tag.div(class: "thumbnail-container") do %>
    <%= carousel_html(object: object, images: images, top_img: top_img,
                      thumbnails: false, **image_args) %>
  <% end %>
<% end %>
```

Per box: a `.thumbnail-container` wraps the carousel; the matrix-box's
`.panel.panel-default > .panel-sizing` chrome already owns the outer
shape, so the carousel renders without its own Panel / heading /
indicator strip (`thumbnails: false`).

## Rendered HTML shape (N images, N > 1)

```html
<div class="carousel slide"
     id="observation_{object.id}_carousel"
     data-ride="false"
     data-interval="false">
  <div class="carousel-inner bg-light" role="listbox">

    <!-- one .item per image. exactly one carries .active —
         the slide whose image == top_img -->
    <div class="item active">
      <img src="…" class="carousel-image" loading="lazy" … />
      <!-- emitted only when presenter.image_link is set -->
      <a href="…" class="image-stretched-link" data-method="…"></a>
      <!-- lightbox link from presenter.lightbox_data -->
      <a class="lightbox-link" data-lightbox="…" …></a>
      <div class="carousel-caption">
        <!-- image-vote stars row -->
        <div class="image-vote-section">…</div>
        <!-- info block: hidden on xs, visible from sm up -->
        <div class="image-info d-none d-sm-block">…</div>
      </div>
    </div>

    <div class="item">
      <!-- same shape, no .active -->
    </div>

    <!-- emitted only when images.length > 1 -->
    <a href="#observation_{object.id}_carousel"
       class="left carousel-control"
       role="button"
       data-slide="prev">
      <div class="btn">
        <span class="glyphicon glyphicon-chevron-left" aria-hidden="true"></span>
        <span class="sr-only">Prev</span>
      </div>
    </a>
    <a href="#observation_{object.id}_carousel"
       class="right carousel-control"
       role="button"
       data-slide="next">
      <div class="btn">
        <span class="glyphicon glyphicon-chevron-right" aria-hidden="true"></span>
        <span class="sr-only">Next</span>
      </div>
    </a>
  </div>
  <!-- NO panel-heading (thumbnails: false) -->
  <!-- NO carousel-indicators <ol> (thumbnails: false) -->
</div>
```

Single-image variant: same outer `.carousel.slide` + inner
`.carousel-inner.bg-light`, one `.item.active`, **no** prev/next
controls (gated on `images.length > 1`).

Zero-image variant: the call site already gates on
`presenter.image_data`, so the matrix box never invokes the carousel
with empty `images`. The helper's "no images" message
(`.p-4.w-100.h-100.text-center.h3.text-muted` with
`:show_observation_no_images.l`) is a top-of-page concern, not a
matrix-box concern. Don't carry it into the matrix-box renderer.

## Differences from the top-of-page `Components::Carousel`

| Concern | Top-of-page | Matrix-box |
|---|---|---|
| Outer wrapper | `Components::Panel` + heading + heading-links | `<div class="thumbnail-container">` (caller-owned) |
| Indicator strip | `<ol class="carousel-indicators panel-footer …">` | none |
| Active slide | first image | `top_img` (defaults to `images.first`, may be `presenter.image_data[:thumb_image]`) |
| Per-slide content | `Components::Carousel::Item` (heavy: copyright, lightbox, fit-contain, full-size) | same `.item` skeleton; image-info block has `d-none d-sm-block` so it disappears in the tightest grid breakpoint |
| Controls | inside `.carousel-inner` | inside `.carousel-inner` (same) |
| Carousel id | `"{type}_{id}_carousel"` | `"{type}_{id}_carousel"` (same — that's why ids stay unique across N boxes on one page) |

The matrix-box variant is **the Panel-less carousel** — exactly the
case `Components::Carousel::Shell` would exist to serve if and when
the Shell extraction discussed in the carousel-refactor assessment
happens.

## Active-slide selection — `top_img`

`top_img` is computed at the call site as
`presenter.image_data[:thumb_image] || images.first`. The helper
walks the image list and tags exactly one `.item` with `.active`
based on `image == top_img` (identity comparison on the Image model).
Same gate is reused inside `carousel_thumbnails` on the top-of-page
caller (irrelevant here since `thumbnails: false`).

When re-implementing in Phlex:
- accept `active_image:` (or `active_index:`) on whatever primitive
  renders the slides; default to `0` / `images.first`;
- the matrix-box caller passes the presenter-computed `top_img`
  through.

## Image presenter / `<img>` attributes

The helper feeds `ImagePresenter.new(image, fit: :contain, original: true,
extra_classes: "carousel-image")` and emits the image tag with
`presenter.options_lazy`. The relevant Image presenter contract for the
matrix-box case:

- `loading="lazy"` (this is what was missing on the old branch and is
  the centre of the perf concern — re-attempt must keep this);
- `class="carousel-image"` on the `<img>`;
- `src` is the full-size original (the helper passed `original: true`),
  which is the **other** half of the perf concern. A matrix-box of 50
  observations × 5 images each = 250 full-size image requests on one
  index page. The re-attempt almost certainly wants a smaller `:size`
  (e.g. `:medium` or `:large` — match what the static-thumbnail mode
  currently uses) and only swap to `:huge` / `:full_size` if the
  lightbox is opened.

## Performance constraints to budget for on the re-attempt

The two reasons the branch didn't ship; capture them up front when
designing the Phlex version:

1. **DB cost**: `presenter.image_data[:images]` was an extra query per
   matrix-box presenter — N+1 across an index of M observations. The
   index controller's eager-loading needs to include
   `Observation.includes(:images, :thumb_image)` (or equivalent) so
   one query serves the whole page.
2. **Image fetch cost**: even with lazy-load wired (which it now is on
   master via `loading="lazy"` and the matrix-box JS observer), the
   *first* slide of every box is in the initial viewport, so M
   observations = M concurrent image requests on page load. Use the
   smallest size that looks acceptable in a matrix tile; the original
   branch used `:large`/original which is way too big.

## Class / id checklist (for parity tests)

When the Phlex rewrite arrives, the parity test against the old ERB
markup (per `.claude/rules/phlex_reference.md`) should pin these:

- `div.carousel.slide[id="{type}_{id}_carousel"][data-ride="false"][data-interval="false"]`
- `div.carousel-inner.bg-light[role="listbox"]`
- per slide: `div.item` (one of them `.item.active`)
- per slide image: `img.carousel-image[loading="lazy"]`
- per slide: `div.carousel-caption > div.image-vote-section`
- per slide: `div.carousel-caption > div.image-info.d-none.d-sm-block`
  (only if `image_info` returns content)
- controls: `a.left.carousel-control[data-slide="prev"]` +
  `a.right.carousel-control[data-slide="next"]`, each containing
  `.glyphicon.glyphicon-chevron-{left,right}[aria-hidden="true"]`
  and `.sr-only`. Only present when `images.length > 1`.

## Reference: full helper source from `nimmo-matrix-box-carousels`

For convenience — the `CarouselHelper` module on the abandoned branch.
Don't port this code; it's the wrong abstraction for the Phlex era.
But the markup it generates is what the rules above describe, so
having the source here means a future re-attempt can sanity-check
against the original without checking out the branch.

```ruby
# app/helpers/carousel_helper.rb on nimmo-matrix-box-carousels
module CarouselHelper
  def carousel_html(**args)
    args[:images] ||= nil
    args[:object] ||= nil
    args[:size] ||= :large
    args[:top_img] ||= args[:images].first
    args[:title] ||= :IMAGES.t
    args[:links] ||= ""
    args[:thumbnails] = true if args[:thumbnails].nil?
    type = args[:object]&.type_tag || "image"
    args[:html_id] ||= "#{type}_#{args[:object].id}_carousel"

    capture do
      if !args[:images].nil? && args[:images].any?
        concat(carousel_basic_html(**args))
      else
        if args[:thumbnails]
          concat(carousel_heading(args[:title], args[:links]))
        end
        concat(carousel_no_images_message)
      end
    end
  end

  def carousel_basic_html(**args)
    tag.div(class: "carousel slide", id: args[:html_id],
            data: { ride: "false", interval: "false" }) do
      concat(tag.div(class: "carousel-inner bg-light", role: "listbox") do
        args[:images].each do |image|
          concat(carousel_item(image, **args))
        end
        concat(carousel_controls(args[:html_id])) if args[:images].length > 1
      end)
      concat(carousel_heading(args[:title], args[:links])) if args[:thumbnails]
      concat(carousel_thumbnails(**args)) if args[:thumbnails]
    end
  end

  def carousel_item(image, **args)
    img_args = args.except(:images, :object, :top_img, :title, :links,
                           :thumbnails, :html_id)
    presenter_args = img_args.merge({ fit: :contain, original: true,
                                      extra_classes: "carousel-image" })
    presenter = ImagePresenter.new(image, presenter_args)
    active = image == args[:top_img] ? "active" : ""

    tag.div(class: class_names("item", active)) do
      concat(image_tag(presenter.img_src, presenter.options_lazy))
      if presenter.image_link
        concat(image_stretched_link(presenter.image_link,
                                    presenter.image_link_method))
      end
      concat(lightbox_link(presenter.lightbox_data))
      concat(carousel_caption(image, args[:object], presenter))
    end
  end

  def carousel_caption(image, object, presenter)
    classes = "carousel-caption"
    caption = if (info = image_info(image, object,
                                    original: presenter.original)).present?
                tag.div(info, class: "image-info d-none d-sm-block")
              else
                ""
              end

    tag.div(class: classes) do
      [
        image_vote_section_html(presenter.image, presenter.votes),
        caption
      ].safe_join
    end
  end

  def carousel_controls(html_id)
    [
      link_to("##{html_id}", class: "left carousel-control",
                             role: "button", data: { slide: "prev" }) do
        tag.div(class: "btn") do
          concat(tag.span(class: "glyphicon glyphicon-chevron-left",
                          aria: { hidden: "true" }))
          concat(tag.span(:PREV.l, class: "sr-only"))
        end
      end,
      link_to("##{html_id}", class: "right carousel-control",
                             role: "button", data: { slide: "next" }) do
        tag.div(class: "btn") do
          concat(tag.span(class: "glyphicon glyphicon-chevron-right",
                          aria: { hidden: "true" }))
          concat(tag.span(:NEXT.l, class: "sr-only"))
        end
      end
    ].safe_join
  end

  def carousel_heading(title, links = "")
    tag.div(class: "panel-heading carousel-heading") do
      tag.h4(class: "panel-title") do
        concat(title)
        concat(tag.span(links, class: "float-right"))
      end
    end
  end

  def carousel_thumbnails(**args)
    tag.ol(class: "carousel-indicators bg-light mt-2 mb-0") do
      args[:images].each_with_index do |image, index|
        active = image == args[:top_img] ? "active" : ""

        concat(tag.li(class: class_names("carousel-indicator mx-1", active),
                      data: { target: "##{args[:html_id]}",
                              slide_to: index.to_s }) do
                 carousel_thumbnail(image)
               end)
      end
    end
  end

  def carousel_thumbnail(image)
    presenter_args = { fit: :contain, extra_classes: "carousel-thumbnail" }
    presenter = ImagePresenter.new(image, presenter_args)

    image_tag(presenter.img_src, presenter.options_lazy)
  end

  def carousel_no_images_message
    tag.div(:show_observation_no_images.l,
            class: "p-4 w-100 h-100 text-center h3 text-muted")
  end
end
```
