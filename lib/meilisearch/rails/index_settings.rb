module MeiliSearch
  module Rails
    class IndexSettings
      DEFAULT_BATCH_SIZE = 1000

      DEFAULT_PRIMARY_KEY = 'id'.freeze

      # Meilisearch settings
      OPTIONS = %i[
        searchableAttributes
        filterableAttributes
        sortableAttributes
        displayedAttributes
        distinctAttribute
        synonyms
        stopWords
        rankingRules
        attributesToHighlight
        attributesToCrop
        cropLength
      ].freeze

      OPTIONS.each do |option|
        define_method option do |value|
          instance_variable_set("@#{option}", value)
        end

        underscored_name = option.to_s.gsub(/(.)([A-Z])/, '\1_\2').downcase
        alias_method underscored_name, option if underscored_name != option
      end

      def initialize(options, &block)
        @options = options
        instance_exec(&block) if block_given?
      end

      def use_serializer(serializer)
        @serializer = serializer
        # instance_variable_set("@serializer", serializer)
      end

      def attribute(*names, &block)
        raise ArgumentError, 'Cannot pass multiple attribute names if block given' if block_given? && (names.length > 1)

        @attributes ||= {}
        names.flatten.each do |name|
          @attributes[name.to_s] = block_given? ? proc { |d| d.instance_eval(&block) } : proc { |d| d.send(name) }
        end
      end
      alias attributes attribute

      def add_attribute(*names, &block)
        raise ArgumentError, 'Cannot pass multiple attribute names if block given' if block_given? && (names.length > 1)

        @additional_attributes ||= {}
        names.each do |name|
          @additional_attributes[name.to_s] = block_given? ? proc { |d| d.instance_eval(&block) } : proc { |d| d.send(name) }
        end
      end
      alias add_attributes add_attribute

      def mongoid?(document)
        defined?(::Mongoid::Document) && document.class.include?(::Mongoid::Document)
      end

      def sequel?(document)
        defined?(::Sequel) && document.class < ::Sequel::Model
      end

      def active_record?(document)
        !mongoid?(document) && !sequel?(document)
      end

      def get_default_attributes(document)
        if mongoid?(document)
          # work-around mongoid 2.4's unscoped method, not accepting a block
          document.attributes
        elsif sequel?(document)
          document.to_hash
        else
          document.class.unscoped do
            document.attributes
          end
        end
      end

      def get_attribute_names(document)
        get_attributes(document).keys
      end

      def attributes_to_hash(attributes, document)
        if attributes
          attributes.to_h { |name, value| [name.to_s, value.call(document)] }
        else
          {}
        end
      end

      def get_attributes(document)
        # If a serializer is set, we ignore attributes
        # everything should be done via the serializer
        if !@serializer.nil?
          attributes = @serializer.new(document).attributes
        elsif @attributes.blank?
          attributes = get_default_attributes(document)
          # no `attribute ...` have been configured, use the default attributes of the model
        elsif active_record?(document)
          # at least 1 `attribute ...` has been configured, therefore use ONLY the one configured
          document.class.unscoped do
            attributes = attributes_to_hash(@attributes, document)
          end
        else
          attributes = attributes_to_hash(@attributes, document)
        end

        attributes.merge!(attributes_to_hash(@additional_attributes, document)) if @additional_attributes

        if @options[:sanitize]
          attributes = sanitize_attributes(attributes)
        end

        attributes = encode_attributes(attributes) if @options[:force_utf8_encoding]

        attributes
      end

      def sanitize_attributes(value)
        case value
        when String
          ActionView::Base.full_sanitizer.sanitize(value)
        when Hash
          value.each { |key, val| value[key] = sanitize_attributes(val) }
        when Array
          value.map { |item| sanitize_attributes(item) }
        else
          value
        end
      end

      def encode_attributes(value)
        case value
        when String
          value.force_encoding('utf-8')
        when Hash
          value.each { |key, val| value[key] = encode_attributes(val) }
        when Array
          value.map { |x| encode_attributes(x) }
        else
          value
        end
      end

      def get_setting(name)
        instance_variable_get("@#{name}")
      end

      def to_settings
        settings = {}
        OPTIONS.each do |k|
          v = get_setting(k)
          settings[k] = v unless v.nil?
        end
        settings
      end

      def add_index(index_uid, options = {}, &block)
        raise ArgumentError, 'No block given' unless block_given?
        if options[:auto_index] || options[:auto_remove]
          raise ArgumentError, 'Options auto_index and auto_remove cannot be set on nested indexes'
        end

        @additional_indexes ||= {}
        options[:index_uid] = index_uid
        @additional_indexes[options] = IndexSettings.new(options, &block)
      end

      def additional_indexes
        @additional_indexes || {}
      end
    end
  end
end
