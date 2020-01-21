# frozen_string_literal: true

require 'parslet'

module Scim
  module Kit
    module V2
      # Parses SCIM filter queries
      class Filter < Parslet::Parser
        root :filter

        # FILTER = attrExp / logExp / valuePath / assignVariable / *1"not" "(" FILTER ")"
        rule(:filter) do
          logical_expression | filter_atom
        end

        rule(:filter_atom) do
          (not_op? >> lparen >> filter >> rparen) | attribute_expression | value_path
        end

        # valuePath = attrPath "[" valFilter "]" ; FILTER uses sub-attributes of a parent attrPath
        rule(:value_path) do
          attribute_path >> lbracket >> value_filter >> rbracket
        end

        # valFilter = attrExp / logExp / *1"not" "(" valFilter ")"
        rule(:value_filter) do
          attribute_expression | logical_expression | not_op? >> lparen >> value_filter >> rparen
        end

        # attrExp = (attrPath SP "pr") / (attrPath SP compareOp SP compValue)
        rule(:attribute_expression) do
          (attribute_path >> space >> presence.as(:operator)) | (attribute_path >> space >> comparison_operator.as(:operator) >> space >> comparison_value.as(:value))
        end

        # logExp = FILTER SP ("and" / "or") SP FILTER
        rule(:logical_expression) do
          filter_atom.as(:left) >> space >> (and_op | or_op).as(:operator) >> space >> filter.as(:right)
        end

        # compValue = false / null / true / number / string ; rules from JSON (RFC 7159)
        rule(:comparison_value) do
          falsey | null | truthy | number | string
        end

        # compareOp = "eq" / "ne" / "co" / "sw" / "ew" / "gt" / "lt" / "ge" / "le"
        rule(:comparison_operator) do
          equal | not_equal | contains | starts_with | ends_with |
            greater_than | less_than | less_than_equals | greater_than_equals
        end

        # attrPath = [URI ":"] ATTRNAME *1subAttr ; SCIM attribute name ; URI is SCIM "schema" URI
        rule(:attribute_path) do
          ((uri >> colon).repeat(0, 1) >> attribute_name >> sub_attribute.repeat(0, 1)).as(:attribute)
        end

        # ATTRNAME  = ALPHA *(nameChar)
        rule(:attribute_name) do
          alpha >> name_character.repeat(0, nil)
        end

        # nameChar = "-" / "_" / DIGIT / ALPHA
        rule(:name_character) { hyphen | underscore | digit | alpha }

        # subAttr = "." ATTRNAME ; a sub-attribute of a complex attribute
        rule(:sub_attribute) { dot >> attribute_name }

        # uri = 1*ALPHA 1*(":" 1*ALPHA)
        rule(:uri) do
          # alpha.repeat(1, nil) >> (colon >> (alpha.repeat(1, nil) | version)).repeat(1, nil)
          str('urn:ietf:params:scim:schemas:') >> (
            str('core:2.0:User') |
            str('core:2.0:Group') | (
              str('extension') >>
            colon >>
            alpha.repeat(1) >>
            colon >>
            version >>
            colon >>
            alpha.repeat(1)
            )
          )
        end

        rule(:presence) { str('pr') }
        rule(:and_op) { str('and') }
        rule(:or_op) { str('or') }
        rule(:not_op?) { (str('not') >> space).repeat(0, 1).as(:not) }
        rule(:falsey) { str('false') }
        rule(:truthy) { str('true') }
        rule(:null) { str('null') }
        rule(:number) do
          str('-').maybe >> (
            str('0') | (match('[1-9]') >> digit.repeat)
          ) >> (
            str('.') >> digit.repeat(1)
          ).maybe >> (
            match('[eE]') >> (str('+') | str('-')).maybe >> digit.repeat(1)
          ).maybe
        end
        rule(:equal) { str('eq') }
        rule(:not_equal) { str('ne') }
        rule(:contains) { str('co') }
        rule(:starts_with) { str('sw') }
        rule(:ends_with) { str('ew') }
        rule(:greater_than) { str('gt') }
        rule(:less_than) { str('lt') }
        rule(:greater_than_equals) { str('ge') }
        rule(:less_than_equals) { str('le') }
        rule(:string) do
          quote >> (str('\\') >> any | str('"').absent? >> any).repeat >> quote
        end
        rule(:lparen) { str('(') }
        rule(:rparen) { str(')') }
        rule(:lbracket) { str('[') }
        rule(:rbracket) { str(']') }
        rule(:digit) { match('\d') }
        rule(:quote) { str('"') }
        rule(:single_quote) { str("'") }
        rule(:space) { match('\s') }
        rule(:alpha) { match['a-zA-Z'] }
        rule(:dot) { str('.') }
        rule(:colon) { str(':') }
        rule(:hyphen) { str('-') }
        rule(:underscore) { str('_') }
        rule(:version) { digit >> dot >> digit }
        rule(:assign) { str('=') }

        class << self
          def parse(filter)
            Node.new(new.parse(filter))
          end
        end
      end
    end
  end
end
