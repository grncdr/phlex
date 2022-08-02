# frozen_string_literal: true

require "digest"

module Phlex
  class Component
    module Overrides
      def initialize(*args, **kwargs, &block)
        @_content = block
        super(*args, **kwargs)
      end

      def template(...)
        if @_rendering
          _template_tag(...)
        else
          @_rendering = true
          super
          @_rendering = false
        end
      end
    end

    include ParentNode, Context

    class << self
      def register_element(*tag_names)
        tag_names.each do |tag_name|
          unless tag_name.is_a? Symbol
            raise ArgumentError, "Custom elements must be provided as Symbols"
          end

          class_eval(<<-RUBY, __FILE__, __LINE__ + 1)
            def #{tag_name}(*args, **kwargs, &)
              _standard_element(*args, _name: "#{tag_name.to_s.gsub('_', '-')}", **kwargs, &)
            end
          RUBY
        end
      end

      def inherited(child)
        child.prepend(Overrides)
        super
      end
    end

    def initialize(**attributes)
      attributes.each { |k, v| instance_variable_set("@#{k}", v) }
    end

    def call(buffer = +"")
      raise "The same component instance shouldn't be rendered twice" if @_rendered
      @_rendered = true

      template(&@_content)
      super
    end
    
    def render_in(_view_context)
      call
    end

    def target
      @_target || self
    end

    def <<(node)
      target.children << node
    end

    def content
      yield(target) if block_given?
    end

    def render_block(new_target, ...)
      old_target = target
      @_target = new_target
      instance_exec(...)
      @_target = old_target
    end
  end
end
