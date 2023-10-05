require "logger"

module Danger
  class SwiftFormat
  
    def initialize(path = nil)
      @path = path || "swiftformat"
      @lintError = "Source input did not pass lint check."
    end

    def installed?
      Cmd.run([@path, "--version"])
    end

    def check_format(files, additional_args = "", swiftversion = "")
      cmd = [@path] + files
      cmd << additional_args.split unless additional_args.nil? || additional_args.empty?

      unless swiftversion.nil? || swiftversion.empty?
        cmd << "--swiftversion"
        cmd << swiftversion
      end

      cmd << %w(--lint --quiet)
      stdout, stderr, status = Cmd.run(cmd.flatten)

      if stderr.strip.eql? @lintError 
        output = @lintError 
      else
        output = stdout.empty? ? stderr : stdout
        if status && !status.success?
          raise "Error running SwiftFormat:\nError: #{output}"
        else
          raise "Error running SwiftFormat: Empty output." if output.empty?
        end
          output = output.strip.no_color
      end
      raise "Error running SwiftFormat: Empty output." unless output
  
      process(output)
    end

    private

    def process(output)
      {
          errors: errors(output),
          stats: {
              run_time: run_time(output)
          }
      }
    end

    ERRORS_REGEX = /(.*:\d+:\d+): ((warning|error):.*)$/.freeze

    def errors(output)
      errors = []
      if output.eql? @lintError 
        errors << {
            file: "Unknown",
            rules: ["lint"]
        }
      else
        output.scan(ERRORS_REGEX) do |match|
          next if match.count < 2

          errors << {
              file: match[0].sub("#{Dir.pwd}/", ""),
              rules: match[1].split(",").map(&:strip)
          }
        end
      end
      errors
    end

    RUNTIME_REGEX = /.*SwiftFormat completed.*(.+\..+)s/.freeze

    def run_time(output)
      if RUNTIME_REGEX.match(output)
        RUNTIME_REGEX.match(output)[1]
      elsif output.eql? @lintError 
        @lintError
      else
        logger = Logger.new($stderr)
        logger.error("Invalid run_time output: #{output}")
        "-1"
      end
    end
  end
end
