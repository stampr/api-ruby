module Stampr
  # Mailing configuration to be used with Batches.
  #
  # TODO: Allow attributes to be set.
  class Config
    DEFAULT_SIZE = :standard
    DEFAULT_TURNAROUND = :threeday
    DEFAULT_STYLE = :color
    DEFAULT_OUTPUT = :single
    DEFAULT_RETURN_ENVELOPE = false

    attr_reader :size, :turnaround, :style, :output, :return_envelope

    class << self
      # Get the config
      # @return [Stampr::Config]
      def [](id)
        raise TypeError, "Expecting positive Integer" unless id.is_a?(Integer) && id > 0

        configs = Stampr.client.get ["configs", id]
        config = configs.first
        self.new symbolize(config)       
      end

      def symbolize(hash)
        Hash[hash.map {|k, v| [k.to_sym, v.is_a?(String) ? v.to_sym : v]}]
      end

      def each
        return enum_for(:each) unless block_given?

        i = 0

        loop do
          configs = Stampr.client.get ["configs", "all", i]

          break if configs.empty?

          configs.each do |config|
            yield self.new(symbolize(config))
          end   

          i += 1
        end 
      end
    end

    # @option :size [:standard]
    # @option :turnaround [:threeday]
    # @option :style [:color]
    # @option :output [:single]
    # @option :return_envelope [false]
    def initialize(options = {})
      @size = options[:size] || DEFAULT_SIZE
      @turnaround = options[:turnaround] || DEFAULT_TURNAROUND
      @style = options[:style] || DEFAULT_STYLE
      @output = options[:output] || DEFAULT_OUTPUT
      # :returnenvelope is from json, return_envelope is more ruby-friendly for end-users.
      @return_envelope = options[:returnenvelope] || options[:return_envelope] || DEFAULT_RETURN_ENVELOPE
      @id = options[:config_id] || nil
    end


    def id
      create unless @id
      @id
    end


    # Create the config on the server.
    #
    # @return [Stampr::Config]
    def create
      return if @id # Don't re-create if it already exists.

      result = Stampr.client.post "configs",
                                  size: size,
                                  turnaround: turnaround, 
                                  style: style,
                                  output: output,
                                  returnenvelope: return_envelope

      @id = result["config_id"]

      self
    end
  end
end