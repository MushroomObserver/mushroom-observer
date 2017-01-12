# encoding: utf-8
# see observer_controller.rb
class ObserverController
  def rewrite_url(obj, new_method)
    url = request.fullpath
    if url.match(/\?/)
      base = url.sub(/\?.*/, "")
      args = url.sub(/^[^?]*/, "")
    elsif url.match(/\/\d+$/)
      base = url.sub(/\/\d+$/, "")
      args = url.sub(/.*(\/\d+)$/, "\1")
    else
      base = url
      args = ""
    end
    base.sub!(%r{/\w+/\w+$}, "")
    "#{base}/#{obj}/#{new_method}#{args}"
  end

  # Create redirection methods for all of the actions we've moved out
  # of this controller.  They just rewrite the URL, replacing the
  # controller with the new one (and optionally renaming the action).
  def self.action_has_moved(obj, old_method, new_method = nil)
    new_method = old_method unless new_method
    class_eval(<<-EOS)
      def #{old_method}
        redirect_to rewrite_url("#{obj}", "#{new_method}")
      end
    EOS
  end

  action_has_moved "comment", "add_comment"
  action_has_moved "comment", "destroy_comment"
  action_has_moved "comment", "edit_comment"
  action_has_moved "comment", "list_comments"
  action_has_moved "comment", "show_comment"
  action_has_moved "comment", "show_comments_for_user"

  action_has_moved "image", "add_image"
  action_has_moved "image", "destroy_image"
  action_has_moved "image", "edit_image"
  action_has_moved "image", "license_updater"
  action_has_moved "image", "list_images"
  action_has_moved "image", "next_image"
  action_has_moved "image", "prev_image"
  action_has_moved "image", "remove_images"
  action_has_moved "image", "reuse_image"
  action_has_moved "image", "show_image"

  action_has_moved "name", "approve_name"
  action_has_moved "name", "bulk_name_edit"
  action_has_moved "name", "change_synonyms"
  action_has_moved "name", "deprecate_name"
  action_has_moved "name", "edit_name"
  action_has_moved "name", "map"
  action_has_moved "name", "observation_index"
  action_has_moved "name", "show_name"
  action_has_moved "name", "show_past_name"

  action_has_moved "observer", "show_user_observations", "observations_by_user"

  action_has_moved "species_list", "add_observation_to_species_list"
  action_has_moved "species_list", "create_species_list"
  action_has_moved "species_list", "destroy_species_list"
  action_has_moved "species_list", "edit_species_list"
  action_has_moved "species_list", "list_species_lists"
  action_has_moved "species_list", "manage_species_lists"
  action_has_moved "species_list", "remove_observation_from_species_list"
  action_has_moved "species_list", "show_species_list"
  action_has_moved "species_list", "species_lists_by_title"
  action_has_moved "species_list", "upload_species_list"
end
