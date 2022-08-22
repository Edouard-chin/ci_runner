# frozen_string_literal: true

module CIRunner
  module Client
    class Error < StandardError
      attr_reader :error_code

      # @param error_code [String] The HTTP status code.
      # @param error_body [String] The response from the provider.
      # @param provider [String] The name of the CI provider.
      # @param message [String, nil]
      def initialize(error_code, error_body, provider, message = nil)
        @error_code = error_code.to_i

        if message
          super(message)
        else
          super(<<~EOM.rstrip)
            Error while making a request to #{provider}. Code: #{error_code}

            The response was: #{error_body}
          EOM
        end
      end
    end
  end
end
