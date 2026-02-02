# frozen_string_literal: true

# Form object for description permissions form.
# Writein fields allow adding individual users to permission groups.
class FormObject::DescriptionPermissions < FormObject::Base
  WRITEIN_COUNT = 6

  # Writein user name fields (autocomplete)
  WRITEIN_COUNT.times do |i|
    attribute :"writein_name_#{i + 1}", :string
    attribute :"writein_reader_#{i + 1}", :boolean, default: false
    attribute :"writein_writer_#{i + 1}", :boolean, default: false
    attribute :"writein_admin_#{i + 1}", :boolean, default: false
  end

  def persisted?
    true # This is an update form
  end

  # Initialize from data hash (for re-rendering form with previous values)
  def load_writein_data(data)
    return unless data

    data.each do |row_num, datum|
      next unless row_num.is_a?(Integer) && row_num.between?(1, WRITEIN_COUNT)

      send(:"writein_name_#{row_num}=", datum[:name])
      send(:"writein_reader_#{row_num}=", datum[:reader])
      send(:"writein_writer_#{row_num}=", datum[:writer])
      send(:"writein_admin_#{row_num}=", datum[:admin])
    end
  end

  # Convert to the hash format the controller expects
  def writein_params
    result = { name: {}, reader: {}, writer: {}, admin: {} }
    WRITEIN_COUNT.times do |i|
      row = i + 1
      result[:name][row] = send(:"writein_name_#{row}") || ""
      result[:reader][row] = send(:"writein_reader_#{row}") ? 1 : 0
      result[:writer][row] = send(:"writein_writer_#{row}") ? 1 : 0
      result[:admin][row] = send(:"writein_admin_#{row}") ? 1 : 0
    end
    result
  end
end
