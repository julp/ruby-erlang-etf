module Erlang
  module ETF

    #
    # | 1  | 2   | N    | 4        | N'     |
    # | -- | --- | ---- | -------- | ------ |
    # | 90 | Len | Node | Creation | ID ... |
    #
    # Same as  [`NEW_REFERENCE_EXT`] with `Creation` coded on 4 bytes instead of 1.
    #
    # [`NEWER_REFERENCE_EXT`] was introduced in OTP 19, but only to be decoded and echoed back.
    # Not encoded for local references.
    #
    # [`REFERENCE_EXT`]: http://erlang.org/doc/apps/erts/erl_ext_dist.html#REFERENCE_EXT
    # [`NEW_REFERENCE_EXT`]: http://erlang.org/doc/apps/erts/erl_ext_dist.html#NEW_REFERENCE_EXT
    # [`NEWER_REFERENCE_EXT`]: http://erlang.org/doc/apps/erts/erl_ext_dist.html#NEWER_REFERENCE_EXT
    #
    class NewerReference
      include Erlang::ETF::Term

      UINT8    = Erlang::ETF::Term::UINT8
      UINT16BE = Erlang::ETF::Term::UINT16BE
      UINT32BE = Erlang::ETF::Term::UINT32BE

      class << self
        def [](term, node = nil, creation = nil, ids = nil)
          return new(term, node, creation, ids)
        end

        def erlang_load(buffer)
          length, = buffer.read(2).unpack(UINT16BE)
          node = Erlang::ETF.read_term(buffer)
          creation, *ids = buffer.read(4 + (4 * length)).unpack("#{UINT32BE}#{UINT32BE}#{length}")
          term = Erlang::Reference[Erlang.from(node), Erlang.from(creation), Erlang.from(ids)]
          return new(term, node, creation, ids)
        end
      end

      def initialize(term, node = nil, creation = nil, ids = nil)
        raise ArgumentError, "term must be of type Erlang::Reference" if not term.kind_of?(Erlang::Reference) or not term.newer_reference?
        @term     = term
        @node     = node
        @creation = creation
        @ids      = ids
      end

      def erlang_dump(buffer = ::String.new.force_encoding(BINARY_ENCODING))
        buffer << NEWER_REFERENCE_EXT
        ids = @ids || @term.ids
        length = ids.size
        buffer << [length].pack(UINT16BE)
        Erlang::ETF.write_term(@node || @term.node, buffer)
        buffer << [
          @creation || @term.creation,
          *ids
        ].pack("#{UINT32BE}#{UINT32BE}#{length}")
        return buffer
      end

      def inspect
        if @node.nil? and @creation.nil? and @ids.nil?
          return super
        else
          return "#{self.class}[#{@term.inspect}, #{@node.inspect}, #{@creation.inspect}, #{@ids.inspect}]"
        end
      end

      def pretty_print(pp)
        state = [@term]
        state.push(@node, @creation, @ids) if not @node.nil? or not @creation.nil? or not @ids.nil?
        return pp.group(1, "#{self.class}[", "]") do
          pp.breakable ''
          pp.seplist(state) { |obj| obj.pretty_print(pp) }
        end
      end
    end
  end
end
