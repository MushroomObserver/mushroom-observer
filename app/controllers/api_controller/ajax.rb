# encoding: utf-8
#
#  = AJAX Stuff
#
#  == Actions
#
#  ajax::         Entry point for AJAX requests.
#
#  == Methods
#
#  ajax_vote::    Change vote on proposed name or image.
#  ajax_export::  Change export status.
#  ajax_geocode:: Look up extents for geographic location by name.
#  ajax_pivotal:: Pivotal requests: look up, vote, or comment on story.
#  ajax_image::   Serve image from web server until transferred to image server.
#
################################################################################

require 'geocoder'

class ApiController
  # Standard entry point for AJAX requests.  AJAX requests are routed here from
  # URLs that look like this:
  #
  #   http://domain.org/ajax/method
  #   http://domain.org/ajax/method/id
  #   http://domain.org/ajax/method/type/id
  #
  # Syntax of successful responses vary depending on the method.
  #
  # Errors are status 500, with the response body being the error message.
  # Semantics of the error possible messages varies depending on the method.
  #
  def ajax
    begin
      send("ajax_#{params[:method]}")
    rescue => e
      msg = e.to_s
      msg += "\n" + e.backtrace.join("\n") if DEVELOPMENT
      render(:text => msg, :layout => false, :status => 500)
    end
  end

  # Process AJAX request for casting votes.
  # type::   Type of object.
  # id::     ID of object.
  # value::  Value of vote.
  #
  # Valid types are:
  # naming:: Vote on a proposed id -- any logged-in user.
  # image::  Vote on an image -- only reviewers.
  #
  # Examples:
  #
  #   /ajax/vote/naming/1234?value=2
  #   /ajax/vote/image/1234?value=4
  #
  def ajax_vote
    type  = params[:type].to_s
    id    = params[:id].to_s
    value = params[:value].to_s

    result = nil
    if user = login_for_ajax
      case type

      when 'naming'
        if (value = Vote.validate_value(val)) and
           (naming = Naming.safe_find(id))
          naming.observation.change_vote(naming, value, user)
          Transaction.put_naming(:id => naming, :_user => user,
                                 :set_vote => value)
          render(:text => result.to_s)
        else
          render(:text => '')
        end

      when 'image'
        if (value == '0' or (value = Image.validate_vote(value))) and
           (image = Image.safe_find(id))
          value = nil if value == '0'
          anon = user.votes_anonymous == :yes
          image.change_vote(user, value, anon)
          Transaction.put_image(:id => image, :_user => user,
                                :set_vote => value, :set_anonymous => anon)
          @image, @user = image, user
          render(:inline => '<%= image_vote_tabs(@image) %>')
        else
          render(:text => '')
        end
      end
    end
  end

  # Process AJAX request for marking things as for export or not.
  # type::   Type of object.
  # id::     ID of object.
  # value::  Value of vote.
  #
  # Valid types are:
  # image::  Vote on an image -- only reviewers.
  #
  # Examples:
  #
  #   /ajax/export/image/1234?value=0  - Not for export
  #   /ajax/export/image/1234?value=1  - For export
  #
  def ajax_export
    type  = params[:type].to_s
    id    = params[:id].to_s
    value = params[:value].to_s

    result = nil
    if user = login_for_ajax
      case type

      when 'image'
        if (value == '0' or value == '1') and
           (image = Image.safe_find(id) and
           user.in_group?('reviewers'))
          image.ok_for_export = (value == '1')
          image.save_without_our_callbacks
          # Should this have a Transation?
          @image, @user = image, user
          render(:inline => '<%= image_exporter(@image.id, @image.ok_for_export) %>')
        else
          render(:text => '')
        end
      end
    end
  end

  # Process AJAX request for geocoding and location name.
  # name::   Name of location
  #
  # Valid types are:
  # name:: Comma separate string in the order indicated by the user's preference (default is Postal)
  #
  # Examples:
  #
  #   /ajax/geocode?name=Falmouth, Massachusetts, USA
  #
  def ajax_geocode
    name  = params[:name].to_s
    if params[:format]
      name = Location.reverse_name(name) if params[:format] == "scientific"
    else
      name = Location.reverse_name(name) if login_for_ajax.location_format == :scientific
    end
    render(:inline => Geocoder.new(name).ajax_response)
  end

  # Process AJAX requests for Pivotal stories.
  # type::   Type of request: 'story', 'vote', 'comment'
  # id::     ID of story.
  # value::  Value of comment or vote (as necessary).
  #
  # Examples:
  #
  #   /ajax/pivotal/story/991235
  #   /ajax/pivotal/vote/991235?value=2
  #   /ajax/pivotal/comment/991235?value=Blah%20blah%20blah...
  #
  def ajax_pivotal
    type  = params[:type].to_s
    id    = params[:id].to_s
    value = params[:value].to_s
    case type
    when 'story'
      @story = Pivotal.get_story(id)
      render(:inline => '<%= pivotal_story(@story) %>')
    when 'vote'
      @user = login_for_ajax
      @story = Pivotal.cast_vote(id, @user, value)
      render(:inline => '<%= pivotal_vote_controls(@story) %>')
    when 'comment'
      user = login_for_ajax
      story = Pivotal.get_story(id)
      @comment = Pivotal.post_comment(id, user, value)
      @num = story.comments.length + 1
      render(:inline => '<%= pivotal_comment(@comment, @num) %>')
    else
      raise("Invalid type \"#{type}\" in Pivotal AJAX controller.")
    end
  end

  # Serve image from web server, bypassing apache and passenger.  (This is only
  # used when an image hasn't been transferred to the image server successfully.)
  def ajax_image
    size = params[:type].to_s
    id   = params[:id].to_s
    file = "#{IMG_DIR}/#{size}/#{id}.jpg"
    if !File.exists?(file)
      if size == 'thumb'
        file = "#{IMG_DIR}/place_holder_thumb.jpg"
      else
        file = "#{IMG_DIR}/place_holder_320.jpg"
      end
    end
    send_file(file, :type => 'image/jpeg', :disposition => 'inline')
  end
end
