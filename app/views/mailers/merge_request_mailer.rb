# frozen_string_literal: true

# Merge-request email body. Always plain text (see
# MergeRequestMailer#build's `content_style: "plain"`).
#
# `old_obj`/`new_obj`'s summary lines (was Location/Herbarium/
# Name::Format#merge_info, moved here per #4901) are resolved per
# type -- each model's merge summary needs different data (obs count,
# curator/record counts, naming/interest counts), so the dispatch has
# to live somewhere that knows about all three, same shape as
# Components::ImageFragment's DISPATCH.
class Views::Mailers::MergeRequestMailer < Views::Mailers::Base
  prop :old_obj, _Union(::Location, ::Herbarium, ::Name)
  prop :new_obj, _Union(::Location, ::Herbarium, ::Name)
  prop :user, ::User
  prop :notes, ::String, default: ""

  def view_template
    trusted_text(ApplicationMailer.prepend_user(@user, message_body))
  end

  private

  def message_body
    :email_merge_objects.l(
      user: @user.login,
      type: @old_obj.type_tag,
      this: merge_summary(@old_obj),
      that: merge_summary(@new_obj),
      show_this_url: @old_obj.show_url,
      edit_this_url: @old_obj.edit_url,
      show_that_url: @new_obj.show_url,
      edit_that_url: @new_obj.edit_url,
      notes: @notes
    )
  end

  def merge_summary(obj)
    case obj
    when ::Location then location_merge_summary(obj)
    when ::Herbarium then herbarium_merge_summary(obj)
    when ::Name then name_merge_summary(obj)
    end
  end

  def location_merge_summary(loc)
    "#{:location.ti} ##{loc.id}: #{loc.name} [o=#{loc.observations.count}]"
  end

  def herbarium_merge_summary(herb)
    "#{:herbarium.ti} ##{herb.id}: #{herb.name} " \
      "[#{herb.curators.count} curators, " \
      "#{herb.herbarium_records.count} records]"
  end

  def name_merge_summary(name)
    "#{:name.ti} ##{name.id}: #{name.real_search_name} " \
      "[#obs: #{name.observations.count}, " \
      "#namings: #{name.namings.count}, " \
      "#users_with_interest: #{name.interests.count}]"
  end
end
