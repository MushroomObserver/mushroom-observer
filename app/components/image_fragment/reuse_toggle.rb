# frozen_string_literal: true

# "Show: [My images]" / "[All images]" auto-submitting select for the
# image reuse pages of `Observations::ImagesController#reuse`,
# `Account::Profile::ImagesController#reuse`, and
# `GlossaryTerms::ImagesController#reuse`. Shaped like
# `Header::Sorter` (a flex-bar label + control). Rendered into the
# pagination row's sorter slot (`content_for(:sorter)`) by each of
# those 3 action views, before the `add_pagination` call --
# `add_pagination` renders the pagination nav immediately and reads
# `content_for(:sorter)` at that point, so the select has to be set up
# from the action view itself, not from `ReuseForm` (which renders
# later, nested inside the body).
#
# @example
#   content_for(:sorter) do
#     capture do
#       ImageFragment(type: :reuse_toggle, target: @observation,
#                    all_users: @all_users)
#     end
#   end
class Components::ImageFragment::ReuseToggle < Components::Base
  CONTROLLERS = Components::ImageFragment::ReuseForm::CONTROLLERS

  prop :target, _Union(::Observation, ::User, ::GlossaryTerm)
  prop :all_users, _Boolean, default: false

  def view_template
    # rubocop:disable-next MO/NoHandRolledFormTag
    form(action: toggle_url, method: :get, class: "flex-bar sorter",
         data: { turbo: "false", controller: "autosubmit",
                 autosubmit_delay_value: "0" }) do
      render(Components::Navbar::Text.new(
               class: class_names("mx-0 pr-2",
                                  Components::Column.mobile_hide_classes)
             )) { append_colon(:image_reuse_show_header.l) }
      render_select
    end
  end

  private

  def target_controller
    CONTROLLERS.fetch(@target.class)
  end

  def toggle_url
    url_for(controller: target_controller, action: :reuse, id: @target.id)
  end

  def render_select
    proxy = Components::ApplicationForm::FieldProxy.new(
      nil, "all_users", @all_users ? "1" : "0"
    )
    render(Components::ApplicationForm::SelectField.new(
             proxy, collection: select_options,
                    wrapper_options: { label: false, wrap_class: "mb-0" },
                    data: { action: "change->autosubmit#submit" }
           ))
  end

  def select_options
    [[:image_reuse_just_yours.t, "0"], [:image_reuse_all_users.t, "1"]]
  end
end
