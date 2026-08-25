# frozen_string_literal: true

module RuboCop
  module Cop
    module Betterment
      class SpecDescribeMethodName < Base
        MSG_CLASS_LABEL = 'Label the outer `describe` with the class constant, not a string.'
        MSG_METHOD_LABEL = 'Put examples inside a `describe` labeled with a method name, such as `"#instance_method"` or `".class_method"`.'
        MSG_DIRECTLY_INSIDE = 'Put the method `describe` directly inside the class `describe`, and share setup with `let` or `before`.'

        METHOD_LABEL = /\A(?:#|\.|::)\S/

        DESCRIBE_METHODS = %i(describe fdescribe xdescribe).freeze
        EXAMPLE_GROUP_METHODS = %i(describe fdescribe xdescribe context fcontext xcontext).freeze
        SHARED_GROUP_METHODS = %i(shared_examples shared_examples_for shared_context).freeze
        EXAMPLE_METHODS = %i(
          it its specify example scenario
          fit fspecify fexample fscenario
          xit xspecify xexample xscenario
        ).freeze

        RESTRICT_ON_SEND = EXAMPLE_METHODS

        def on_block(node)
          send_node = node.send_node
          return unless example_group?(send_node)

          groups = enclosing_groups(node)
          return if groups.any? { |group| shared_group?(group) }

          check_class_label(send_node) if groups.empty?
          check_method_describe_placement(send_node, groups)
        end
        alias on_numblock on_block

        def on_send(node)
          return unless node.receiver.nil?

          groups = enclosing_groups(node)
          return if groups.any? { |group| shared_group?(group) || method_describe?(group) }
          return unless groups.any? { |group| class_describe?(group) }

          add_offense(node, message: MSG_METHOD_LABEL)
        end
        alias on_csend on_send

        private

        def check_class_label(send_node)
          return unless describe?(send_node)

          label = send_node.first_argument
          return if label.nil? || label.const_type?

          add_offense(label, message: MSG_CLASS_LABEL)
        end

        def check_method_describe_placement(send_node, groups)
          return unless method_describe?(send_node)

          parent = groups.first
          return if parent.nil? || class_describe?(parent)
          return unless groups.any? { |group| class_describe?(group) }

          add_offense(send_node, message: MSG_DIRECTLY_INSIDE)
        end

        def enclosing_groups(node)
          node.each_ancestor(:block, :numblock).filter_map do |ancestor|
            send_node = ancestor.send_node
            send_node if example_group?(send_node) || shared_group?(send_node)
          end
        end

        def example_group?(send_node)
          EXAMPLE_GROUP_METHODS.include?(send_node.method_name) && rspec_receiver?(send_node)
        end

        def shared_group?(send_node)
          SHARED_GROUP_METHODS.include?(send_node.method_name) && rspec_receiver?(send_node)
        end

        def describe?(send_node)
          DESCRIBE_METHODS.include?(send_node.method_name) && rspec_receiver?(send_node)
        end

        def class_describe?(send_node)
          return false unless describe?(send_node)

          send_node.first_argument&.const_type? || false
        end

        def method_describe?(send_node)
          return false unless describe?(send_node)

          label = send_node.first_argument
          return false unless label&.str_type?

          METHOD_LABEL.match?(label.value)
        end

        def rspec_receiver?(send_node)
          receiver = send_node.receiver
          return true if receiver.nil?

          receiver.const_type? && receiver.short_name == :RSpec && (receiver.namespace.nil? || receiver.namespace.cbase_type?)
        end
      end
    end
  end
end
