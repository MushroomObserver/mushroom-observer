# frozen_string_literal: true

# Action template for the shared `Images::ReuseController#index` —
# "pick an existing image to attach to this Observation / GlossaryTerm
# / your profile" page. `params[:target_type]`/`params[:target_id]`
# (see config/routes.rb) pick the target; this view dispatches the few
# bits that differ per target (title wording, context-nav tabs),
# renders the id-entry `Form`, and paginates a grid of clickable
# thumbnails (each wrapping `Components::InteractiveImage` in a POST
# link to the RESTful `reuse_image_path` member action, so a click
# attaches that image directly).
module Views::Controllers::Images::Reuse
  class Index < Views::FullPageBase
    prop :target, _Union(::Observation, ::GlossaryTerm, ::User)
    prop :user, _Nilable(::User), default: nil
    prop :objects, _Array(::Image)
    prop :pagination_data, ::PaginationData
    prop :all_users, _Boolean, default: false

    def view_template
      add_page_title(:image_reuse_title.t(name: target_display_name))
      add_target_context_nav
      container_class(:full)
      add_all_users_toggle_to_sorter_slot
      add_pagination(@pagination_data)

      render(Index::Form.new(target: @target))
      render_image_grid
    end

    private

    def target_display_name
      case @target
      when ::Observation then viewer_aware_unique_format_name(@target, @user)
      when ::GlossaryTerm then @target.unique_format_name
      when ::User then @target.legal_name
      end
    end

    def add_target_context_nav
      case @target
      when ::Observation
        add_context_nav(
          ::Tab::Observation::ImagesReuse.new(observation: @target)
        )
      when ::GlossaryTerm
        add_context_nav(::Tab::GlossaryTerm::ImageForm.new(term: @target))
      end
    end

    ############################################################################
    # "Show: [My images]" / "[All images]" auto-submitting select,
    # shaped like `Header::Sorter` (a flex-bar label + control).
    # Rendered into the pagination row's sorter slot before
    # `add_pagination` -- `add_pagination` renders the pagination nav
    # immediately and reads `content_for(:sorter)` at that point, so
    # the select has to be set up here, not from `Form` (which renders
    # later, nested inside the body).

    def add_all_users_toggle_to_sorter_slot
      content_for(:sorter) { capture { render_all_users_toggle } }
    end

    def render_all_users_toggle
      # rubocop:disable-next MO/NoHandRolledFormTag
      form(action: Index::Form.reuse_path_for(@target), method: :get,
           class: "flex-bar sorter",
           data: { turbo: "false", controller: "autosubmit",
                   autosubmit_delay_value: "0" }) do
        render(Components::Navbar::Text.new(
                 class: class_names("mx-0 pr-2",
                                    Components::Column.mobile_hide_classes)
               )) { append_colon(:show.ti) }
        render_all_users_select
      end
    end

    def render_all_users_select
      proxy = Components::ApplicationForm::FieldProxy.new(
        nil, "all_users", @all_users ? "1" : "0"
      )
      render(Components::ApplicationForm::SelectField.new(
               proxy, collection: all_users_select_options,
                      wrapper_options: { label: false, wrap_class: "mb-0" },
                      data: { action: "change->autosubmit#submit" }
             ))
    end

    def all_users_select_options
      [[:image_reuse_just_yours.t, "0"], [:image_reuse_all_users.t, "1"]]
    end

    ############################################################################
    # Image grid

    def render_image_grid
      PaginatedResults do
        Grid() do
          @objects.each { |image| render_image_card(image) }
        end
      end
    end

    def render_image_card(image)
      render(::Components::Grid::Box.new(id: image.id)) do
        Panel(class: "h-100") do |panel|
          panel.with_thumbnail do
            InteractiveImage(
              user: @user,
              image: image,
              votes: false,
              full_width: true,
              show_filename_row: false,
              image_link: Index::Form.attach_path_for(image.id, @target),
              link_method: :post,
              extra_classes: "image-to-reuse"
            )
          end
          panel.with_body { render_image_card_body(image) }
        end
      end
    end

    def render_image_card_body(image)
      div(class: "d-flex flex-column justify-content-between h-100") do
        div(class: "mb-2") do
          render_filename_and_badge_row(image)
          render_image_card_when_who(image)
        end
        render_use_button(image)
      end
    end

    def render_filename_and_badge_row(image)
      div(class: "d-flex justify-content-between align-items-center") do
        render(::Components::Image::OriginalFilenameRow.new(image: image))
        Badge(type: :id, object: image, size: :lg)
      end
    end

    def render_image_card_when_who(image)
      span(class: "nowrap-ellipsis") do
        span { image.when.web_date }
        if @all_users
          plain(": ")
          Link(type: :user, user: image.user)
        end
      end
    end

    def render_use_button(image)
      Button(type: :post, name: :use.ti,
             target: Index::Form.attach_path_for(image.id, @target))
    end
  end
end
