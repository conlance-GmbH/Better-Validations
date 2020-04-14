module BetterValidations::Errors
  extend ActiveSupport::Concern
  included do
    # Returns the same hash as a 'messages' method
    # but if an error is happened with a nested object
    # it will be stored in a nested hash under the key without a dot symbol
    # instead of an array under the key with dot symbol.
    #
    # Example:
    # object.errors.messages == {
    #   field_one: ["can't be blank"],
    #   "nested_object.field_one": ["can't be blank"],
    #   "nested_object.field_two": ["can't be blank"]
    # }
    # object.errors.detailed_messages == {
    #   field_one: ["can't be blank"],
    #   nested_object: {
    #     field_one: ["can't be blank"],
    #     field_two: ["can't be blank"]
    #   }
    # }
    def detailed_messages(wrap_attributes_to: nil)
      return @messages if @messages.blank?

      # Split errors to field errors and nested objects errors.
      # A dot symbol means that the error is happened with a nested object.
      nested_messages, field_messages = split_messages(@messages)

      if wrap_attributes_to.present? && field_messages.present?
        field_messages = { wrap_attributes_to => field_messages }
      end

      detailed_messages = field_messages
      return detailed_messages if nested_messages.blank?

      # Parse nested messages to structure with nested objects and merge.
      detailed_messages.merge(
        parse_nested_messages(nested_messages, wrap_attributes_to)
      )
    end

    def split_messages(messages)
      messages.partition do |field, _|
        base_field_name = field.to_s.split('.').first.to_sym

        if @base.class.respond_to?(:reflect_on_association)
          @base.class.reflect_on_association(base_field_name)
        else
          @base.class._validators[base_field_name]&.any? do |validator|
            validator.is_a? BetterValidations::NestedValidator
          end
        end
      end.map(&:to_h)
    end

    # Converts nested messages to detailed structure with nested objects
    def parse_nested_messages(nested_messages, wrap_attributes_to)
      # Get names of all relations with errors
      relations = nested_messages.keys
                                 .map { |field| field.to_s.split('.').first }
                                 .uniq

      # Collect messages from nested objects
      relations.map do |relation|
        object = @base.relation_for_nested_messages(relation)
        [relation.to_sym, object.detailed_errors_messages(wrap_attributes_to)]
      end.to_h
    end
  end
end
