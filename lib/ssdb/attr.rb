module SSDB
  module Attr
    extend ActiveSupport::Concern

    included do
      instance_variable_set(:@ssdb_attr_definition, {})

      #before_validation :check_ssdb_json_changes
      after_create :save_ssdb_attrs
      after_update :save_ssdb_attrs
      after_commit :clear_ssdb_attrs, on: :destroy
    end

    module ClassMethods
      SUPPORTED_SSDBATTR_TYPES = %i[string integer json]
      attr_reader :ssdb_attr_definition
      attr_reader :ssdb_attr_id_field
      attr_reader :ssdb_attr_pool_name

      #
      # 设置获取 SSDB Attr Id 的方式
      #
      # @param [String/Symbol] field_name
      #
      # @return [String]
      #
      def ssdb_attr_id(field_name)
        raise if field_name.nil?
        @ssdb_attr_id_field = field_name
      end

      #
      # Specify which SSDB ConnectionPool current class should use, by name specified in `SSDBAttr.setup`
      #
      # @param [String/Symbol] pool_name
      #
      # @return [String/Symbol]
      #
      def ssdb_attr_pool(pool_name)
        @ssdb_attr_pool_name = pool_name
      end

      def ssdb_attr_names
        @ssdb_attr_definition.keys
      end

      #
      # Method to define a SSDB attribute in a Ruby Class
      #
      # @param [String/Symbol] name Attribute name.
      # @param [String/Symbol] type Attribute type, now supports: string/integer
      # @param [options] options Extra options.
      #
      # @return [void]
      #
      def ssdb_attr(name, type, options = {})
        unless SUPPORTED_SSDBATTR_TYPES.include?(type.to_sym)
          raise "Type: #{type} not supported, only supported #{SUPPORTED_SSDBATTR_TYPES} now."
        end

        @ssdb_attr_definition[name.to_s] = type.to_s

        define_method(name) do
          if instance_variable_defined?("@#{name}")
            instance_variable_get("@#{name}")
          else
            ssdb_val = ssdb_attr_pool.with { |conn| conn.get(ssdb_attr_key(name)) }
            cached_ssdb_attr_old_value(name, ssdb_val)
            instance_variable_set("@#{name}", decode_ssdb_attr(ssdb_val || options[:default], type))
          end
        end

        define_method("#{name}=") do |val|
          decode_val = decode_ssdb_attr(val, type)
          send("#{name}_will_change!") unless decode_val == send(name)
          instance_variable_set("@#{name}", decode_val)
        end

        define_method("#{name}_default_value") do
          decode_ssdb_attr(options[:default], type)
        end

        define_method("#{name}_was") { changed_ssdb_attrs[name] }

        define_method("#{name}_change") do
          if __send__("#{name}_changed?")
            [changed_ssdb_attrs[name], __send__(name)]
          end
        end

        define_method("#{name}_changed?") { changed_ssdb_attrs.include?(name) }

        define_method("restore_#{name}!") do
          if __send__("#{name}_changed?")
            __send__("#{name}=", changed_ssdb_attrs[name])
            # 清除 changed_attributes 相关数值
            attributes_changed_by_setter.except!(name)
          end
        end

        # changed_attributes 里会有相关数值
        define_method("#{name}_will_change!") { attribute_will_change!(name) }
      end
    end

    #
    # Overwrite `reload` method in ActiveRecord to reload SSDB attributes as well.
    #
    #
    # @return [void]
    #
    def reload(options = nil)
      super.tap do
        reload_ssdb_attrs
      end
    end

    #
    # Load the values of all specified attrs.
    #
    #
    # @return [void]
    #
    def load_ssdb_attrs(*fields)
      fields = (fields.map(&:to_s) & self.class.ssdb_attr_names)

      values = ssdb_attr_pool.with do |conn|
        conn.mget(fields.map { |name| ssdb_attr_key(name) })
      end

      fields.each_with_index do |attr, index|
        value = decode_ssdb_attr(values[index], self.class.ssdb_attr_definition[attr])
        instance_variable_set("@#{attr}", value)
      end
    end

    #
    # Return the SSDB key for a attribute
    #
    # @param [String] name Attribute name.
    #
    # @return [String]
    #
    def ssdb_attr_key(name)
      "#{self.class.name.tableize}:#{ssdb_attr_id}:#{name}"
    end

    #
    # Cast the value from SSDB to the correct type.
    #
    # @param [Any] val Any value taken from SSDB Server.
    # @param [String/Symbol] type Target value to cast to.
    #
    # @return [Any]
    #
    def decode_ssdb_attr(val, type)
      case type.to_sym
      when :string  then val.to_s
      when :integer then val.to_i
      when :json then
        SSDB::Type::JSON.decode(val)
      else
        raise "decode_ssdb_attr: i don't know this type: #{type}."
      end
    end

    def encode_ssdb_attr(val, type)
      case type.to_sym
      when :string  then val.to_s
      when :integer then val.to_i
      when :json then
        SSDB::Type::JSON.new(val).encode
      else
        raise "encode_ssdb_attr: i don't know this type: #{type}."
      end
    end

    # changes with ssdb_attr changes
    #
    # @return [Hash]
    def changes_with_ssdb
      changes.merge(ssdb_changes)
    end

    private

    def ssdb_attr_old_values
      @ssdb_attr_old_values ||= HashWithIndifferentAccess.new
    end

    #
    # Return the ConnectionPool used by current Class.
    #
    #
    # @return [ConnectionPool]
    #
    def ssdb_attr_pool
      SSDBAttr.pool(self.class.ssdb_attr_pool_name)
    end

    def ssdb_attr_id
      send(self.class.ssdb_attr_id_field || :id)
    end

    #
    # Delete all SSDB Attributes of current object in the server.
    #
    #
    # @return [void]
    #
    def clear_ssdb_attrs
      ssdb_attr_pool.with do |conn|
        self.class.ssdb_attr_names.each { |attr| conn.del(ssdb_attr_key(attr)) }
      end
    end

    #
    # Save changed SSDb Attributes to the server.
    #
    #
    # @return [void]
    #
    def save_ssdb_attrs
      update_params = []
      del_keys = []
      ssdb_changes.each do |attr, values|
        _, val = values
        val = encode_ssdb_attr(val, self.class.ssdb_attr_definition[attr])
        if val.nil?
          del_keys.push "#{ssdb_attr_key(attr)}"
        else
          update_params.push ["#{ssdb_attr_key(attr)}", val]
        end
        cached_ssdb_attr_old_value(attr, val, true)
      end

      ssdb_attr_pool.with do |conn|
        conn.mset(*update_params.flatten) if update_params.length > 0
        conn.del(*del_keys) if del_keys.length > 0
      end 
    end

    def cached_ssdb_attr_old_value(name, value, force = false)
      value = value.duplicable? ? value.dup : value
      if force
        ssdb_attr_old_values[name.to_s] = value
      else
        ssdb_attr_old_values[name.to_s] ||= value
      end
    end

    #
    # Reload attribute values from the server.
    #
    # This method will overwrite current changed but not saved values in the object.
    #
    #
    # @return [void]
    #
    def reload_ssdb_attrs
      load_ssdb_attrs(*self.class.ssdb_attr_names)
    end

    # ssdb_changes (like activerecord changes)
    #
    # @return [Hash]
    def ssdb_changes
      changed_ssdb_attrs.each_with_object({}.with_indifferent_access) do |info, obj|
        attr_name, old_val = info
        obj[attr_name] = [old_val, __send__(attr_name)]
      end
    end

    # changed_ssdb_attr (like activerecord changed_attributes)
    #
    # @return [Hash]
    def changed_ssdb_attrs
      ssdb_attr_old_values.each_with_object({}.with_indifferent_access) do |info, obj|
        attr_name, original_val = info
        type = self.class.ssdb_attr_definition[attr_name]
        old_val = decode_ssdb_attr(original_val, type)
        if old_val != __send__(attr_name)
          obj[attr_name] = old_val
        end
      end
    end
  end
end
