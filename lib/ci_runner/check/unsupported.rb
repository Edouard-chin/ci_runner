# frozen_string_literal: true

require_relative "base"

module CIRunner
  module Check
    # Check class used for any CI provider not (yet) supported by CIRunner.
    #
    # When running the `ci_runner` CLI, those will be selectable but CI runner will bail out
    # if they get selected. Not sure if its a good idea :shrug:.
    class Unsupported < Base
      # @return [String]
      def name
        "#{@name} (Unsupported by CI Runner)"
      end

      # @return [String]
      def provider
        ""
      end

      # @raise [Error]
      def download_log
        raise(Error, <<~EOM)
          Aw, snap! This CI is not supported by CI Runner.
          Please open an Issue on GitHub to let me know you are interested:

          {{info:https://github.com/Edouard-chin/ci_runner/issues/new}}
        EOM
      end
    end
  end
end
