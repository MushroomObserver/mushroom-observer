# frozen_string_literal: true

# "General Description" panel summarizing the name's best description
# in textile-rendered prose. Heading links show / edit description
# when the viewer can edit.
#
# Takes the `Description` record as a prop (eager-loaded via
# `Name.show_includes`) and derives both:
#   - the panel body (`@description.gen_desc.presence ||
#     @description.diag_desc`, same shape as `Name#best_brief_description`)
#   - the show + edit-permission gates on the heading links
#
# Self-gates: emits nothing when there's no description OR neither
# `gen_desc` nor `diag_desc` is populated.
class Views::Controllers::Names::Show::BestDescriptionPanel < Views::Base
  prop :name, ::Name
  prop :description, _Nilable(::Description), default: nil
  prop :user, _Nilable(::User), default: nil

  def view_template
    return if brief_text.blank?

    render(Components::Panel.new(
             panel_id: "name_general_description"
           )) do |panel|
      panel.with_heading { plain(:show_name_general_description.l) }
      panel.with_heading_links { render_heading_links } if @user
      panel.with_body { trusted_html(brief_text.tpl) }
    end
  end

  private

  # Mirrors `Name#best_brief_description` — favor the general
  # description, fall back to the diagnostic.
  def brief_text
    return @brief_text if defined?(@brief_text)

    @brief_text = @description &&
                  (@description.gen_desc.presence ||
                   @description.diag_desc)
  end

  def render_heading_links
    links = [show_link, edit_link].compact
    links.each_with_index do |link, idx|
      render(link)
      plain(" | ") if idx < links.length - 1
    end
  end

  def show_link
    return nil unless @description

    Components::Link.new(
      type: :icon,
      tab: Tab::Name::ShowDescription.new(name: @name)
    )
  end

  def edit_link
    return nil unless @description && permission?(@description)

    Components::Link.new(
      type: :icon,
      tab: Tab::Name::EditDescription.new(name: @name)
    )
  end
end
