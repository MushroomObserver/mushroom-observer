#
#  = Application Helpers
#
#  These methods are available to all templates in the application:
#
#  ==== Localization
#  rank_as_string::         Translate :Genus into "Genus" (localized).
#  rank_as_lower_string::   Translate :Genus into "genus" (localized).
#  rank_as_plural_string::  Translate :Genus into "Genera" (localized).
#  image_vote_as_long_string::  Translate image vote into (long) localized String.
#  image_vote_as_short_string:: Translate image vote into (short) localized String.
#  review_as_string::       Translate review status into localized String.
#
#  ==== Other Stuff
#  show_object_footer::     Show the created/modified/view dates and RSS log.
#
################################################################################

module ApplicationHelper
  require_dependency 'auto_complete_helper'
  require_dependency 'description_helper'
  require_dependency 'html_helper'
  require_dependency 'javascript_helper'
  require_dependency 'map_helper'
  require_dependency 'object_link_helper'
  require_dependency 'paginator_helper'
  require_dependency 'tab_helper'
  require_dependency 'textile_helper'

  include AutoComplete
  include Description
  include HTML
  include Javascript
  include Map
  include ObjectLink
  include Paginator
  include Tabs
  include Textile

  ##############################################################################
  #
  #  :section: Localization
  #
  ##############################################################################

  # Translate Name rank (singular).
  #
  #   rank_as_string(:genus)  -->  "Genus"
  #
  def rank_as_string(rank)
    :"RANK_#{rank.to_s.upcase}".l
  end

  # Translate Name rank (singular).
  #
  #   rank_as_lower_string(:genus)  -->  "genus"
  #
  def rank_as_lower_string(rank)
    :"rank_#{rank.to_s.downcase}".l
  end

  # Translate Name rank (plural).
  #
  #   rank_as_plural_string(:genus)  -->  "Genera"
  #
  def rank_as_plural_string(rank)
    :"RANK_PLURAL_#{rank.to_s.upcase}".l
  end

  # Translate Name rank (plural).
  #
  #   rank_as_plural_string(:genus)  -->  "genera"
  #
  def rank_as_lower_plural_string(rank)
    :"rank_plural_#{rank.to_s.downcase}".l
  end

  # Translate image quality.
  #
  #   image_vote_as_long_string(3)  -->  "Good enough for a field guide."
  #
  def image_vote_as_long_string(val)
    :"image_vote_long_#{val || 0}".l
  end

  # Translate image quality.
  #
  #   image_vote_as_short_string(3)  -->  "Good"
  #
  def image_vote_as_short_string(val)
    :"image_vote_short_#{val || 0}".l
  end

  # Translate review status.
  #
  #   review_as_string(:unvetted)  -->  "Reviewed"
  #
  def review_as_string(val)
    :"review_#{val}".l
  end

  ##############################################################################
  #
  #  :section: Other Stuff
  #
  ##############################################################################

  # Renders the little footer at the bottom of show_object pages.
  #
  #   <%= show_object_footer(@name) %>
  #
  #   # Non-versioned object:
  #   <p>
  #     <span class="Date">
  #       Created: <date><br/>
  #       Last Modified: <date><br/>
  #       Viewed: <num> times, last viewed: <date><br/>
  #       Show Log<br/>
  #     </span>
  #   </p>
  #
  #   # Latest version of versioned object:
  #   <p>
  #     <span class="Date">
  #       Created: <date> by <user><br/>
  #       Last Modified: <date> by <user><br/>
  #       Viewed: <num> times, last viewed: <date><br/>
  #       Show Log<br/>
  #     </span>
  #   </p>
  #
  #   # Old version of versioned object:
  #   <p>
  #     <span class="Date">
  #       Version: <num> of <total>
  #       Modified: <date> by <user><br/>
  #       Show Log<br/>
  #     </span>
  #   </p>
  #
  def show_object_footer(obj)
    html = []
    type = obj.class.name.underscore
    num_versions = obj.respond_to?(:version) ? obj.versions.length : 0

    # Old version of versioned object.
    if num_versions > 0 && obj.version < num_versions
      html << :footer_version_out_of.t(:num => obj.version,
                                    :total => num_versions)
      html << :footer_modified_by.t(:user => user_link(obj.user),
                                 :date => obj.modified.web_time) if obj.modified

    # Latest version or non-versioned object.
    else
      if num_versions > 0
        latest_user = User.find(obj.versions.latest.user_id)
        html << :footer_created_by.t(:user => user_link(obj.user),
                                  :date => obj.created.web_time) if obj.created
        html << :footer_last_modified_by.t(:user => user_link(latest_user),
                                        :date => obj.modified.web_time) if obj.modified
      else
        html << :footer_created_at.t(:date => obj.created.web_time) if obj.created
        html << :footer_last_modified_at.t(:date => obj.modified.web_time) if obj.modified
      end
      if obj.respond_to?(:num_views)
        html << :footer_viewed.t(:date => obj.last_view.web_time,
                                :times => obj.num_views == 1 ? :one_time.l :
                                :many_times.l(:num => obj.num_views)) if obj.last_view
      end
    end

    # Show RSS log for all of the above.
    if obj.respond_to?(:rss_log_id) and obj.rss_log_id
      html << link_to(:show_object.t(:type => :log),
                      :controller => 'observer', :action => 'show_rss_log',
                      :id => obj.rss_log_id)
    end

    html = html.join("<br/>\n")
    html = '<span class="Date">' + html + '</span>'
    html = '<p>' + html + '</p>'
  end
end
