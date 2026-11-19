# frozen_string_literal: true

module Views::Controllers::GlossaryTerms
  # GlossaryTerm show page: title + edit icons in the header,
  # description + external-search link on the left, thumbnail on
  # the right, then a strip of other-image thumbnails and a footer
  # with the previous-version link, timestamps, and authors/editors.
  class Show < Views::FullPageBase
    prop :glossary_term, ::GlossaryTerm
    prop :other_images, _Array(::Image)
    prop :versions, _Array(::GlossaryTerm::Version)

    def view_template
      render_page_chrome

      render_main_row
      render_other_images
    end

    private

    def render_page_chrome
      add_show_title(@glossary_term)
      add_edit_icons(@glossary_term, current_user)
      add_pager_for(@glossary_term)
      container_class(:wide)
      column_classes(:eight_four)
      content_padding(:panels)
    end

    def render_main_row
      Row do
        div(class: content_for(:left_columns)) { render_left_column }
        div(class: content_for(:right_columns)) { render_right_column }
      end
    end

    def render_left_column
      render_definition_panel
      ContentPadded do
        render_image_action_links
        render_versions_footer
      end
    end

    def render_definition_panel
      Panel(id: "glossary_term_definition") do |panel|
        panel.with_body do
          div(class: "description mb-3") do
            trusted_html(@glossary_term.description.tpl)
          end
          div(id: "external_searches") { render_wikipedia_link }
        end
      end
    end

    def render_wikipedia_link
      text, url = ::Tab::ExternalSearch.new(
        site: :Wikipedia, query: @glossary_term.name
      ).to_a
      Link(type: :get, name: text, target: url)
    end

    def render_right_column
      return unless @glossary_term.thumb_image

      InteractiveImage(
        user: current_user,
        image: @glossary_term.thumb_image,
        size: :medium,
        votes: true,
        id_prefix: "glossary_term_image"
      )
    end

    def render_image_action_links
      div(class: "mb-3") do
        Link(type: :get, name: :show_glossary_term_reuse_image.t,
             target: reuse_images_for_glossary_term_path(@glossary_term.id))
        br
        Link(type: :get, name: :show_glossary_term_remove_image.t,
             target: remove_images_from_glossary_term_path(@glossary_term.id))
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
      Panel do |panel|
        panel.with_thumbnail do
          InteractiveImage(
            user: current_user,
            image: image,
            votes: true,
            id_prefix: "glossary_term_image"
          )
        end
      end
    end

    def render_versions_footer
      div(id: "glossary_term_authors_editors", class: "mt-3") do
        render(::Components::Description::PreviousVersion.new(
                 obj: @glossary_term, versions: @versions.to_a
               ))
        p(class: "Date") { render_timestamps }
        render(::Views::Layouts::AuthorsAndEditors.new(
                 obj: @glossary_term,
                 versions: @versions.to_a,
                 user: current_user
               ))
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
  end
end
