# frozen_string_literal: true

module Views::Controllers::GlossaryTerms
  # GlossaryTerm show page: title + edit icons in the header,
  # description + external-search panel on the left, thumbnail on
  # the right, then a strip of other-image thumbnails, the previous-
  # version footer, and an authors/editors panel.
  class Show < Views::FullPageBase
    prop :glossary_term, ::GlossaryTerm
    prop :other_images, _Array(::Image)
    prop :versions, _Array(::GlossaryTerm::Version)

    def view_template
      add_show_title(@glossary_term)
      add_edit_icons(@glossary_term, current_user)
      container_class(:wide)
      column_classes(:eight_four)

      render_main_row
      render_image_action_links
      render_other_images
      render_versions_footer
      render_authors_editors_panel
    end

    private

    def render_main_row
      Row do
        div(class: content_for(:left_columns)) { render_left_column }
        div(class: content_for(:right_columns)) { render_right_column }
      end
    end

    def render_left_column
      ContentPadded do
        div(class: "description") do
          p { trusted_html(@glossary_term.description.tpl) }
        end
        div(id: "external_searches") do
          p { render_wikipedia_link }
        end
      end
    end

    def render_wikipedia_link
      text, url = ::Tab::ExternalSearch.new(
        site: :Wikipedia, query: @glossary_term.name
      ).to_a
      link_to(text, url)
    end

    def render_right_column
      return unless @glossary_term.thumb_image

      Image(
        user: current_user,
        image: @glossary_term.thumb_image,
        size: :medium,
        votes: true,
        id_prefix: "glossary_term_image"
      )
    end

    def render_image_action_links
      ContentPadded(class: "mb-3") do
        link_to(:show_glossary_term_reuse_image.t,
                reuse_images_for_glossary_term_path(@glossary_term.id))
        br
        link_to(:show_glossary_term_remove_image.t,
                remove_images_from_glossary_term_path(@glossary_term.id))
        br
      end
    end

    def render_other_images
      Row do
        @other_images.each do |image|
          Column(sm: 4) { render_other_image_panel(image) }
        end
      end
    end

    def render_other_image_panel(image)
      render(::Components::Panel.new) do |panel|
        panel.with_thumbnail do
          Image(
            user: current_user,
            image: image,
            votes: true,
            id_prefix: "glossary_term_image"
          )
        end
      end
    end

    def render_versions_footer
      ContentPadded(class: "mt-3") do
        render(::Components::Description::PreviousVersion.new(
                 obj: @glossary_term, versions: @versions.to_a
               ))
        p(class: "Date") { render_timestamps }
      end
    end

    def render_timestamps
      trusted_html(
        :footer_created_at.t(date: @glossary_term.created_at.web_time)
      )
      br
      trusted_html(
        :footer_last_updated_at.t(date: @glossary_term.updated_at.web_time)
      )
    end

    def render_authors_editors_panel
      render(::Components::Panel.new(
               panel_id: "glossary_term_authors_editors"
             )) do |panel|
        panel.with_body do
          render(::Views::Layouts::AuthorsAndEditors.new(
                   obj: @glossary_term,
                   versions: @versions.to_a,
                   user: current_user
                 ))
        end
      end
    end
  end
end
