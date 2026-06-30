# frozen_string_literal: true

# One observation row on the species_list show page. The row is a
# `list-group-item` with two columns when there's a thumb image
# (image + details), or a single full-width column otherwise. Permission-
# gated "Remove" button sits in the top-right.
module Views::Controllers::SpeciesLists
  class Observation < Views::Base
    def initialize(observation:, user:, species_list:,
                   image: false, remove: false)
      super()
      @observation = observation
      @user = user
      @species_list = species_list
      @image = image
      @remove = remove
    end

    def view_template
      render(Components::ListGroup::Item.new) do
        div(class: "row") do
          render_image_column if @image
          div(class: details_column_classes) { render_details_row }
        end
      end
    end

    private

    def details_column_classes
      @image ? "col-sm-8 col-md-9" : "col-xs-12"
    end

    def render_image_column
      div(class: "col-sm-4 col-md-3") do
        render(Components::Image::Interactive.new(
                 user: @user,
                 image: @observation.thumb_image,
                 image_link: observation_path(id: @observation.id),
                 votes: true
               ))
      end
    end

    def render_details_row
      div(class: "d-flex justify-content-between align-items-start") do
        render_observation_details
        render_manage_observation if @remove
      end
    end

    def render_observation_details
      div(class: "observation_details") do
        render_observation_name_link
        render_observation_location_link
        render_observation_who_and_when
      end
    end

    def render_observation_name_link
      div(class: "font-weight-bold") do
        link_to(@observation.unique_format_name.t,
                observation_path(id: @observation.id))
      end
    end

    def render_observation_location_link
      div(class: "font-weight-bold") do
        render(Components::Link::Location.new(
                 where: @observation.where, location: @observation.location
               ))
      end
    end

    def render_observation_who_and_when
      div do
        render(Components::Link::User.new(user: @observation.user))
        plain(": ")
        plain(@observation.when.web_date)
      end
    end

    def render_manage_observation
      div(class: "manage_observation") { render_remove_obs_button }
    end

    # `confirm:` is the Turbo-confirm kwarg; `data: { confirm: … }` is
    # a no-op under Turbo (rails-ujs is not wired).
    def render_remove_obs_button
      render(Components::Button.new(
               type: :put,
               variant: :strip,
               name: :REMOVE.t,
               target: observation_species_list_path(
                 id: @observation.id,
                 species_list_id: @species_list.id,
                 commit: "remove"
               ),
               confirm: :are_you_sure.l
             ))
    end
  end
end
