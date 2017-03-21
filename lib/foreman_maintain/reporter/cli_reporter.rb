require 'thread'
require 'highline'

module ForemanMaintain
  class Reporter
    class CLIReporter < Reporter
      DECISION_MAPPER = {
        %w[y yes] => 'add_step',
        %w[n next no] => 'skip_to_next',
        %w[q quit] => 'ask_to_quit'
      }.freeze

      # Simple spinner able to keep updating current line
      class Spinner
        def initialize(reporter, interval = 0.1)
          @reporter = reporter
          @mutex = Mutex.new
          @active = false
          @interval = interval
          @spinner_index = 0
          @spinner_chars = %w[| / - \\]
          @current_line = ''
          @puts_needed = false
          start_spinner
        end

        def update(line)
          @mutex.synchronize do
            @current_line = line
            print_current_line
          end
        end

        def active?
          @mutex.synchronize { @active }
        end

        def activate
          @mutex.synchronize { @active = true }
          spin
        end

        def deactivate
          return unless active?
          @mutex.synchronize do
            @active = false
          end
        end

        private

        def start_spinner
          @thread = Thread.new do
            loop do
              spin
              sleep @interval
            end
          end
        end

        def spin
          @mutex.synchronize do
            return unless @active
            print_current_line
            @spinner_index = (@spinner_index + 1) % @spinner_chars.size
          end
        end

        def print_current_line
          @reporter.clear_line
          line = "#{@spinner_chars[@spinner_index]} #{@current_line}"
          @reporter.print(line)
        end
      end

      def initialize(stdout = STDOUT, stdin = STDIN)
        @stdout = stdout
        @stdin = stdin
        @hl = HighLine.new
        @max_length = 80
        @line_char = '-'
        @cell_char = '|'
        @spinner = Spinner.new(self)
        @last_line = ''
      end

      def before_scenario_starts(scenario)
        puts "Running #{scenario.description || scenario.class}"
        hline
      end

      def before_execution_starts(execution)
        puts(execution_info(execution, ''))
      end

      def print(string)
        new_line_if_needed
        @stdout.print(string)
        @stdout.flush
        record_last_line(string)
      end

      def puts(string)
        # we don't print the new line right away, as we want to be able to put
        # the status label at the end of the last line, if possible.
        # Therefore, we just mark that we need to print the new line next time
        # we are printing something.
        new_line_if_needed
        @stdout.print(string)
        @stdout.flush
        @new_line_next_time = true
        record_last_line(string)
      end

      def ask(message)
        print message
        # the answer is confirmed by ENTER which will emit a new line
        @new_line_next_time = false
        @last_line = ''
        @stdin.gets.chomp.downcase || ''
      end

      def new_line_if_needed
        if @new_line_next_time
          @stdout.print("\n")
          @stdout.flush
          @new_line_next_time = false
        end
      end

      def with_spinner(message)
        new_line_if_needed
        @spinner.activate
        @spinner.update(message)
        yield @spinner
      ensure
        @spinner.deactivate
        @new_line_next_time = true
      end

      def after_execution_finishes(execution)
        puts_status(execution.status)
        puts(execution.output) unless execution.output.empty?
        hline
        new_line_if_needed
      end

      def after_scenario_finishes(_scenario); end

      def on_next_steps(runner, steps)
        if steps.size > 1
          runner.ask_to_quit if multiple_steps_selection(steps) == :quit
        else
          decision = ask_decision("Continue with step [#{steps.first.description}]?")
          runner.send(decision, steps.first)
        end
      end

      def multiple_steps_selection(steps)
        puts 'There are multiple steps to proceed:'
        steps.each_with_index do |step, index|
          puts "#{index + 1}) #{step.description}"
        end
        ask_to_select('Select step to continue', steps, &:description)
      end

      def ask_decision(message)
        answer = ask("#{message}, [y(yes), n(no), q(quit)]")
        filter_decision(answer.downcase.chomp) || ask_decision(message)
      ensure
        clear_line
      end

      def filter_decision(answer)
        decision = nil
        DECISION_MAPPER.each do |options, decision_call|
          decision = decision_call if options.include?(answer)
        end
        decision
      end

      def ask_to_select(message, steps)
        answer = ask("#{message}, [n(next), q(quit)]")
        if %w[n no next].include?(answer)
          return
        elsif answer =~ /^\d+$/
          steps[answer.to_i - 1]
        elsif %w[q quit].include?(answer)
          :quit
        else
          ask_to_select(message, steps)
        end
      ensure
        clear_line
      end

      def clear_line
        print "\r" + ' ' * @max_length + "\r"
      end

      def execution_info(execution, text)
        prefix = "#{execution.name}:"
        "#{prefix} #{text}"
      end

      def puts_status(status)
        label_offset = 10
        padding = @max_length - @last_line.size - label_offset
        if padding < 0
          new_line_if_needed
          padding = @max_length - label_offset
        end
        @stdout.print(' ' * padding + status_label(status))
        @new_line_next_time = true
      end

      def status_label(status)
        mapping = { :success => { :label => '[OK]', :color => :green },
                    :fail => { :label => '[FAIL]', :color => :red },
                    :running => { :label => '[RUNNING]', :color => :blue },
                    :skipped => { :label => '[SKIPPED]', :color => :yellow } }
        properties = mapping[status]
        @hl.color(properties[:label], properties[:color], :bold)
      end

      def hline
        puts @line_char * @max_length
      end

      def record_last_line(string)
        @last_line = string.lines.to_a.last
      end
    end
  end
end
