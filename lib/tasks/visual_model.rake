# frozen_string_literal: true

namespace :visual_model do
  desc "Create a VisualModel from a list of names"
  task(create: :environment) do
    Rails.logger = Logger.new($stdout)
    model_name = ENV.fetch("MODEL_NAME", nil)
    name_list = ENV.fetch("NAME_LIST", nil)
    report_usage unless model_name && name_list && File.file?(name_list)
    build_from_file(model_name, name_list)
  end
end

def report_usage
  Rails.logger.error(
    "\nThis task expects the MODEL_NAME and NAME_LIST to provided\n" \
    "through environment variables, and for the value of NAME_LIST\n" \
    "to be an existing file.\n\n" \
    "Example usage:\n" \
    "MODEL_NAME=MyModel NAME_LIST=./name_list rails visual_model:create"
  )
  exit
end

def build_from_file(model_name, name_list)
  model = VisualModel.find_or_create_by(name: model_name)
  if model.save
    File.open(name_list) do |file|
      file.readlines.each do |line|
        process_line(model, line)
      end
    end
  end
  return unless model.errors.count.positive?

  Rails.logger.error("VisualModel errors:")
  Rails.logger.error(model.errors.full_messages)
end

def process_line(model, line)
  line.split(",").each do |raw_cmd|
    cmd = raw_cmd.strip
    next if cmd == ""

    id, label = parse_cmd(cmd)
    if id.nil?
      add_visual_group(model, label)
    else
      add_image(model, id, label)
    end
  end
end

def parse_cmd(cmd)
  first_space = cmd.index(" ")
  return [nil, cmd] if first_space.nil?

  id = begin
         Integer(cmd[..first_space - 1])
       rescue StandardError
         nil
       end
  return [nil, cmd] if id.nil?

  [id, cmd[first_space + 1..]]
end

def add_visual_group(model, name)
  Rails.logger.info { "Adding VisualGroup for '#{name}'" }
  errors = create_visual_group(model, name)
  Rails.logger.error(errors.full_messages) if errors
end

def create_visual_group(model, name)
  group = VisualGroup.new(visual_model: model, name: name)
  if group.save
    group.add_initial_images
    nil
  else
    group.errors
  end
end

def add_image(model, id, name)
  group = VisualGroup.find_or_create_by(visual_model: model, name: name)
  vgi = VisualGroupImage.joins(:visual_group).find_by(
    image_id: id,
    visual_groups: { visual_model_id: model.id }
  )
  if vgi.nil?
    VisualGroupImage.create(visual_group: group,
                            image_id: id,
                            included: true)
  else
    vgi.visual_group = group
    vgi.included = true
    vgi.save
  end
end
