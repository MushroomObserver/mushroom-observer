# Location Change Email
class QueuedEmail::LocationChange < QueuedEmail
  def location
    get_object(:location, ::Location)
  end

  def description
    get_object(:description, ::LocationDescription, :nil_okay)
  end

  def old_location_version
    get_integer(:old_location_version)
  end

  def new_location_version
    get_integer(:new_location_version)
  end

  def old_description_version
    get_integer(:old_description_version)
  end

  def new_description_version
    get_integer(:new_description_version)
  end

  def self.create_email(sender, recipient, location, desc = nil)
    result = create(sender, recipient)
    fail "Missing location or description!" if !location && !desc

    if location
      result.add_integer(:location, location.id)
      result.add_integer(:new_location_version, location.version)
      result.add_integer(:old_location_version, (location.saved_changes? ? location.version - 1 : location.version))
    elsif location = desc.location
      result.add_integer(:location, location.id)
      result.add_integer(:new_location_version, location.version)
      result.add_integer(:old_location_version, location.version)
    end
    if desc
      result.add_integer(:description, desc.id)
      result.add_integer(:new_description_version, desc.version)
      result.add_integer(:old_description_version, (desc.saved_changes? ? desc.version - 1 : desc.version))
    elsif desc = location.description
      result.add_integer(:description, desc.id)
      result.add_integer(:new_description_version, desc.version)
      result.add_integer(:old_description_version, desc.version)
    end
    result.finish
    result
  end

  def deliver_email
    return unless location

    loc_change = ObjectChange.new(location,
                                  old_location_version,
                                  new_location_version)
    desc_change = ObjectChange.new(description,
                                   old_description_version,
                                   new_description_version)
    LocationChangeEmail.build(user, to_user, queued,
                              loc_change, desc_change).deliver_now
  end
end
