# frozen_string_literal: true

class Views::Layouts::Sidebar
  # Renders the language toggle + collapsible language list in the
  # sidebar. An inline accordion (Link::CollapseToggle + Collapsible),
  # not a floating dropdown — a popup menu doesn't behave well at the
  # bottom of a long nav (clipping / off-screen risk), and an inline
  # expand keeps everything in the normal document flow.
  #
  # @example Basic usage
  #   render(Views::Layouts::Sidebar::Languages.new(
  #     browser: browser,
  #     request: request
  #   ))
  class Languages < ::Views::Base
    TOGGLE_ID = "language_dropdown_toggle"
    COLLAPSE_ID = "language_dropdown_collapse"

    # `:browser` and `:request` are both unused inside this view but
    # kept for API symmetry with `Sidebar`, which threads both through
    # uniformly to every sub-view it renders. Duck-typed for the same
    # reason as the parent (tests pass a Struct stub).
    prop :browser, _Interface(:bot?)
    prop :request, _Interface(:url)
    prop :languages, _Array(Language)

    def view_template
      render_toggle
      Collapsible(id: COLLAPSE_ID) do
        @languages.each do |lang|
          next if lang.locale == I18n.locale.to_s

          render_language_row(lang)
        end
      end
    end

    private

    # The current-locale flag + "Languages:" label IS the collapse
    # trigger — no separate toggle affordance. `panel-collapse-trigger`
    # reuses `Panel`'s established chevron-flip CSS (`.active-icon`
    # shown/hidden via the `.collapsed` class) rather than inventing a
    # new one. Standalone `ListGroup::LinkItem` (not the `ListGroup(...)
    # do |list| ... end` builder) since this is the only row rendered
    # by this view outside of any iteration.
    def render_toggle
      render(Components::ListGroup::LinkItem.new(
               class: "pl-3 panel-collapse-trigger"
             )) do |css_class|
        Link(type: :collapse_toggle, target_id: COLLAPSE_ID,
             id: TOGGLE_ID, class: css_class) do
          trusted_html(append_colon(:app_languages.t))
          span(class: "lang-flag-emoji") do
            plain(Components::LanguageSwitchButton.flag_for(I18n.locale))
          end
          whitespace
          Icon(type: :chevron_down, title: :open.ti,
               class: "active-icon")
          Icon(type: :chevron_up, title: :close.ti)
        end
      end
    end

    def render_language_row(lang)
      render(
        Components::ListGroup::LinkItem.new(class: "indent")
      ) do |css_class|
        LanguageSwitchButton(
          language: lang,
          id: "lang_drop_#{lang.locale}_link",
          class: css_class,
          data: { locale: lang.locale }
        )
      end
    end
  end
end
