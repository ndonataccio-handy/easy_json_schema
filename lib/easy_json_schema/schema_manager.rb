require 'json'
require 'json-schema'

module EasyJsonSchema
  class SchemaManager
    def initialize(options = {})
      defaults = {
        data: nil,
        file: nil,
        directory: nil,
        files: [],
        directories: []
      }

      options = defaults.merge(options)

      @schema_titles_to_ids = {}

      unless options[:data].nil?
        initialize_from_data(options[:data])
      end

      unless options[:file].nil?
        initialize_from_file(options[:file])
      end

      options[:files].each do |filename|
        initialize_from_file(filename)
      end

      unless options[:directory].nil?
        initialize_from_directory(options[:directory])
      end

      options[:directories].each do |directory|
        initialize_from_directory(directory)
      end
    end

    def list_schema_titles
      @schema_titles_to_ids.keys
    end

    def validate_data(schema_title, data)
      schema = @schema_titles_to_ids[schema_title]
      if schema.nil?
        raise EasyJsonSchema::UnknownSchemaTitle.new(
          "Unknown schema title: #{schema_title}"
        )
      end

      JSON::Validator.fully_validate(schema, data, errors_as_objects: true)
    end

    private

    def initialize_from_directory(directory)
      schema_files(directory).each do |filename|
        initialize_from_file(filename)
      end
    end

    def initialize_from_file(filename)
      schema_data = load_schema_file(filename)

      initialize_from_data(schema_data)
    end

    def initialize_from_data(schema_data)
      raise_if_missing_title!(schema_data)
      raise_if_missing_id!(schema_data)

      schema_title = schema_data['title']
      schema_id = schema_data['id']

      uri = Addressable::URI.parse(schema_data['id'])

      # If we register the schema, the library can make use of it by
      # referencing it by the id
      schema = JSON::Schema.new(schema_data, uri)
      JSON::Validator.add_schema(schema)

      @schema_titles_to_ids[schema_title] = schema_id
    end

    def load_schema_file(filename)
      File.open(filename, 'r') { |f| JSON.load(f) }
    end

    def schema_files(directory)
      Dir.glob(File.join(directory, '*'))
         .select { |e|
           e.end_with?('.json') && File.file?(e)
         }
    end

    def raise_if_missing_title!(data, filename: nil)
      message = if filename.nil?
                  'Schema is missing title attribute'
                else
                  "Schema from #{filename} is missing title attribute"
                end

      raise EasyJsonSchema::MissingSchemaTitle.new(message) if data['title'].nil?
    end

    def raise_if_missing_id!(data, filename: nil)
      message = if filename.nil?
                  'Schema is missing id attribute'
                else
                  "Schema from '#{filename}' is missing id attribute"
                end

      raise EasyJsonSchema::MisingSchemaId.new(message) if data['id'].nil?
    end
  end

  class SchemaManagerError < StandardError
  end

  class MissingSchemaTitle < SchemaManagerError
  end

  class MissingSchemaId < SchemaManagerError
  end

  class UnknownSchemaTitle < SchemaManagerError
  end
end