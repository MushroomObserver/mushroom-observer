# frozen_string_literal: true

module LogoEntryHelper
  def build_image(param_image, user, date, copyright_holder, license)
    image = Image.new(image: param_image,
                      user: user,
                      when: date,
                      copyright_holder: copyright_holder,
                      license: license)
    if !image.save
      flash_object_errors(image)
    elsif !image.process_image
      logger.error("Unable to upload image")
      name = image.original_name
      name = "???" if name.empty?
      flash_error(:runtime_profile_invalid_image.t(name: name))
      flash_object_errors(image)
    else
      name = image.original_name
      name = "##{image.id}" if name.empty?
      flash_notice(:runtime_profile_uploaded_image.t(name: name))
    end
  end
end
