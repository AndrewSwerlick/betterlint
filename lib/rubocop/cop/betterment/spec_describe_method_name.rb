# frozen_string_literal: true

module RuboCop
  module Cop
    module Betterment
      class SpecDescribeMethodName < Base
        MSG_CLASS_LABEL = 'Label the outer `describe` with the class constant, not a string.'
        MSG_METHOD_LABEL = 'Put examples inside a `describe` labeled with a method name, such as `"#instance_method"` or `".class_method"`.'
        MSG_DIRECTLY_INSIDE = 'Put the method `describe` directly inside the class `describe`, and share setup with `let` or `before`.'

        METHOD_LABEL = /\A(?:#|\.|::)\S/

        # @!method example_group_send?(node)
        def_node_matcher :example_group_send?, <<~PATTERN
          (send {nil? (const {nil? cbase} :RSpec)} {:describe :context :fdescribe :fcontext :xdescribe :xcontext} ...)
        PATTERN

        # @!method describe_send?(node)
        def_node_matcher :describe_send?, <<~PATTERN
          (send {nil? (const {nil? cbase} :RSpec)} {:describe :fdescribe :xdescribe} ...)
        PATTERN

        # @!method shared_group_send?(node)
        def_node_matcher :shared_group_send?, <<~PATTERN
          (send {nil? (const {nil? cbase} :RSpec)} {:shared_examples :shared_examples_for :shared_context} ...)
        PATTERN

        # @!method example_send?(node)
        def_node_matcher :example_send?, <<~PATTERN
          (send nil? {
            :it :its :specify :example :scenario
            :fit :fspecify :fexample :fscenario
            :xit :xspecify :xexample :xscenario
          } ...)
        PATTERN

        def on_block(node)
          return unless example_group_send?(node.send_node)
          return if inside_shared_group?(node)

          check_class_label(node)
          check_method_describe_placement(node)
        end
        alias on_numblock on_block

        def on_send(node)
          return unless example_send?(node)
          return if inside_shared_group?(node)

          check_example_placement(node)
        end
        alias on_csend on_send

        private

        def check_class_label(node)
          return unless describe_send?(node.send_node) && enclosing_group(node).nil?

          label = node.send_node.first_argument
          return if label.nil? || label.const_type?

          add_offense(label, message: MSG_CLASS_LABEL)
        end

        def check_method_describe_placement(node)
          return unless method_describe?(node)

          parent = enclosing_group(node)
          return if parent.nil? || class_describe?(parent)
          return unless inside_class_describe?(node)

          add_offense(node.send_node, message: MSG_DIRECTLY_INSIDE)
        end

        def check_example_placement(node)
          return unless inside_class_describe?(node)
          return if node.each_ancestor(:block, :numblock).any? { |ancestor| method_describe?(ancestor) }

          add_offense(node, message: MSG_METHOD_LABEL)
        end

        def enclosing_group(node)
          node.each_ancestor(:block, :numblock).find { |ancestor| example_group_send?(ancestor.send_node) }
        end

        def inside_class_describe?(node)
          node.each_ancestor(:block, :numblock).any? { |ancestor| class_describe?(ancestor) }
        end

        def inside_shared_group?(node)
          node.each_ancestor(:block, :numblock).any? { |ancestor| shared_group_send?(ancestor.send_node) }
        end

        def class_describe?(node)
          return false unless describe_send?(node.send_node)

          node.send_node.first_argument&.const_type? || false
        end

        def method_describe?(node)
          return false unless describe_send?(node.send_node)

          label = node.send_node.first_argument
          return false unless label&.str_type?

          METHOD_LABEL.match?(label.value)
        end
      end
    end
  end
end
