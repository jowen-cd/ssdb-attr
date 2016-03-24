module SSDB
  module Attr
    extend ActiveSupport::Concern

    SUPPORTED_TYPES = %i(string integer boolean sorted_set)

    included do
      define_model_callbacks :update_ssdb_attrs, only: [:before, :after]
      after_create :init_ssdb_attrs
      after_destroy :clear_ssdb_attrs
    end

    def update_ssdb_attrs(attributes)
      # Determine what attrs are requested to be updated
      attributes = attributes.symbolize_keys
      attr_names = attributes.keys & self.class.ssdb_attr_names

      # Determine dirty fields
      attr_names.each do |name|
        send("#{name}_will_change!") unless attributes[name] == send(name)
      end

      run_callbacks :update_ssdb_attrs do
        SSDBAttr.pool.with do |conn|
          attr_names.each { |name| send("#{name}=", attributes[name]) }
        end
      end

      # Clear dirty fields
      clear_attribute_changes(attr_names)

      true # always return true
    end

    def init_ssdb_attrs
      self.class.ssdb_attrs.each do |attr_name, type|
        SSDBAttr.pool.with { |conn| conn.set(to_ssdb_attr_key(attr_name), self.send(attr_name)) } if type != :sorted_set
      end
    end

    def clear_ssdb_attrs
      SSDBAttr.pool.with do |conn|
        self.class.ssdb_attrs.each do |attr_name, type|
          if type == :sorted_set
            conn.zclear(to_ssdb_attr_key(attr_name))
          else
            conn.del(to_ssdb_attr_key(attr_name))
          end
        end
      end
    end

    def to_ssdb_attr_key(name)
      klass = self.class

      custom_id = klass.instance_variable_get("@ssdb_attr_id")

      if custom_id.present?
        "#{klass.name.tableize}:#{self.send(custom_id)}:#{name}"
      else
        "#{klass.name.tableize}:#{id}:#{name}"
      end
    end

    private
    def touch_db_column(names)
      names == true ? touch : touch(*names)
    end

    module ClassMethods
      def ssdb_attrs
        @ssdb_attrs ||= {}
      end

      def ssdb_attr_names
        @ssdb_attrs.keys
      end

      #
      # Custom SSDB::Attr ID for the current object.
      #
      # @param [Symbol] Attribute / method to get the value acts as the SSDB::Attr ID for the current object.
      #
      # @return [<type>] <description>
      #
      def ssdb_attr_id(sym)
        @ssdb_attr_id = sym
      end

      # ssdb_attr :content,        :string,   default: 0, touch: true
      # ssdb_attr :writer_version, :integer,  default: 0, touch: [:field1, :field2, :field3]
      #
      # [counter description]
      # @param name [type] [description]
      # @param name [type] [description]
      # @param options={} [type] [description]
      # @param block [description]
      #
      # @return [type] [description]
      def ssdb_attr(name, type, options={})
        unless SSDB::Attr::SUPPORTED_TYPES.include?(type.to_sym)
          raise "Type #{type} not supported, only #{SSDB::Attr::SUPPORTED_TYPES.join(",")} are supported now."
        end

        # self.ssdb_attr_names << name
        self.ssdb_attrs[name.to_sym] = type.to_sym

        define_method(name) do
          if type.to_sym == :sorted_set
            # Return SSDB::SortedSet if type is sorted_set
            SSDB::SortedSet.new(to_ssdb_attr_key(name))
          else
            # Return value if type is other type
            value = SSDBAttr.pool.with { |conn| conn.get(to_ssdb_attr_key(name)) }

            if value.nil?
              options[:default]
            else
              case type.to_sym
              when :string
                value.to_s
              when :integer
                value.to_i
              when :boolean
                value == "t" ? true : false
              end
            end
          end
        end

        define_method("#{name}=") do |val|
          raise "Cannot assign value to SortedSet type." if type.to_sym == :sorted_set

          save_val = case type.to_sym
                     when :string, :integer
                       val
                     when :boolean
                       val ? "t" : "f"
                     end

          SSDBAttr.pool.with { |conn| conn.set("#{to_ssdb_attr_key(name)}", save_val) }
          touch_db_column(options[:touch]) if options[:touch].present?
        end

        define_method("#{name}_will_change!") do
          attribute_will_change!(name)
        end

        define_method("#{name}_changed?") do
          attribute_changed?(name)
        end
      end
    end
  end
end
