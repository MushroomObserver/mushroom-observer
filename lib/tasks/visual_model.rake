# frozen_string_literal: true

namespace :visual_model do
  desc "Create a VisualModel from a list of names"
  task(create: :environment) do
    Rails.logger = Logger.new($stdout)
    model_name = ENV.fetch("MODEL_NAME", nil)
    name_list = ENV.fetch("NAME_LIST", nil)
    report_create_usage unless model_name && name_list && File.file?(name_list)
    build_from_file(model_name, name_list)
  end

  desc "Export VisualGroup"
  task(create: :environment) do
    Rails.logger = Logger.new($stdout)
    model_name = ENV.fetch("MODEL_NAME", nil)
    group_names = ENV.fetch("GROUP_NAMES", nil)
    report_export_usage unless model_name
    export_model(model_name, group_names)
  end
end

# visual_model:create support

def report_create_usage
  Rails.logger.error(
    "\nThis task expects the MODEL_NAME and NAME_LIST to be given\n" \
    "through environment variables, and for the value of NAME_LIST\n" \
    "to be an existing file.\n" \
    "\nExample usage:\n" \
    "MODEL_NAME=MyModel NAME_LIST=./name_list rails visual_model:create\n" \
    "\nExample lines from NAME_LIST:\n" \
    "Agaricus campestris\n" \
    "Agaricus bisporus, Agaricus xanthodermus\n" \
    "1234 Agaricus bernardi\n" \
    "-2345 Agaricus abruptibulbus\n"
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

def add_image(model, raw_id, name)
  group = VisualGroup.find_or_create_by(visual_model: model, name: name)
  id = raw_id.abs
  vgi = VisualGroupImage.joins(:visual_group).find_by(
    image_id: id,
    visual_groups: { visual_model_id: model.id }
  )
  if vgi.nil?
    Rails.logger.info { "Adding image #{id} to #{name}" }
    VisualGroupImage.create(visual_group: group,
                            image_id: id,
                            included: raw_id.positive?)
  else
    old_name = vgi.visual_group.name
    Rails.logger.info do
      "Moving image #{id} from #{old_name} to #{name}"
    end
    vgi.visual_group = group
    vgi.included = raw_id.positive?
    vgi.save
  end
end

# visual_model:export support

def report_export_usage
  Rails.logger.error(
    "\nThis task expects the MODEL_NAME to be given through an\n" \
    "environment variable.  GROUP_NAMES can be given to limit the export.\n" \
    "\nExample usage:\n" \
    "MODEL_NAME=MyModel GROUP_NAMES='Microscopy, Text' " \
    "rails visual_model:export"
  )
  exit
end

def export_model(model_name, group_names)
  model = VisualModel.find_by(name: model_name)
  if model
    if group_names.nil?
      export_all_groups(model)
    else
      export_group_names(model, group_names)
    end
  else
    Rails.logger.error("Unable to find the VisualModel #{model_name}")
  end
end

def export_all_groups(model)
  model.visual_groups.each do |group|
    export_group(group)
  end
end

def export_group_names(model, group_names)
  group_names.split(",").each do |name|
    name = name.strip
    next if name == ""

    group = model.visual_groups.where(name: name)
    if group
      export_group(group)
    else
      Rails.logger.error("Unable to find the VisualGroup #{name}")
    end
  end
end
