# frozen_string_literal: true

# Configuration only. SimpleCov.start is called by spec/spec_helper.rb, and by
# the Rails subprocesses the Railtie specs spawn. Active under COVERAGE=1.
SimpleCov.configure do
  command_name ENV.fetch('SIMPLECOV_COMMAND', 'rspec')

  enable_coverage :branch
  primary_coverage :line

  # SimpleCov 1.x needs Ruby 3.3; on the older Rubies this gem still supports,
  # Bundler resolves the 0.22 line, which spells the same two settings differently.
  #
  # version.rb is left out because Bundler loads it while reading the gemspec,
  # before coverage can start.
  if respond_to?(:cover)
    cover 'lib/**/*.rb'
    skip 'lib/blackevin/version.rb'
  else
    track_files 'lib/**/*.rb'
    add_filter ['/spec/', 'lib/blackevin/version.rb']
  end

  # A subprocess measures one file. It stores its result for the merge and says
  # nothing: its stdout is what the spec reads, and a floor checked against one
  # file would fail it.
  if ENV['SIMPLECOV_COMMAND']
    formatter SimpleCov::Formatter::SimpleFormatter
    print_error_status false
  else
    minimum_coverage line: 100, branch: 95
  end
end
