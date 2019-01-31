# Name Change Email

class QueuedEmail::NameChange < QueuedEmail
  def name
    get_object(:name, ::Name)
  end

  def description
    get_object(:description, ::NameDescription)
  end

  def old_name_version
    get_integer(:old_name_version)
  end

  def new_name_version
    get_integer(:new_name_version)
  end

  def old_description_version
    get_integer(:old_description_version)
  end

  def new_description_version
    get_integer(:new_description_version)
  end

  def review_status
    get_string(:review_status).to_sym
  end

  def name_change
    ObjectChange.new(name, old_name_version, new_name_version)
  end

  def desc_change
    ObjectChange.new(description, old_description_version, new_description_version)
  end

  def self.create_email(sender, recipient, name, desc,
                        review_status_changed,
                        force_prev = false)
    result = create(sender, recipient)
    raise "Missing name or description!" if !name && !desc

    if name
      result.add_integer(:name, name.id)
      result.add_integer(:new_name_version, name.version)
      old_version = name.version - (name.saved_changes? || force_prev ? 1 : 0)
      result.add_integer(:old_name_version, old_version)
    else
      name = desc.name
      result.add_integer(:name, name.id)
      result.add_integer(:new_name_version, name.version)
      result.add_integer(:old_name_version, name.version)
    end
    if desc
      result.add_integer(:description, desc.id)
      result.add_integer(:new_description_version, desc.version)
      old_version = desc.version - (desc.saved_changes? || force_prev ? 1 : 0)
      result.add_integer(:old_description_version, old_version)
      result.add_string(:review_status, review_status_changed ? desc.review_status : :no_change)
    else
      result.add_integer(:description, 0)
      result.add_integer(:new_description_version, 0)
      result.add_integer(:old_description_version, 0)
      result.add_string(:review_status, :no_change)
    end
    result.finish
    result
  end

  def deliver_email
    # Make sure name wasn't deleted or merged since email was queued.
    NameChangeEmail.build(self).deliver_now if name
  end
end
