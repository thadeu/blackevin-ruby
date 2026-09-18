# frozen_string_literal: true

require 'fileutils'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec)

RuboCop::RakeTask.new(:lint)

task default: %i[spec lint]

namespace :contract do
  desc 'Copy the language-neutral contract from the Blackevin monorepo (BLACKEVIN_SPEC_DIR, default ../blackevin/spec)'
  task :sync do
    source = File.expand_path(ENV.fetch('BLACKEVIN_SPEC_DIR', '../blackevin/spec'), __dir__)
    target = File.expand_path('spec/contract', __dir__)

    abort "no contract at #{source}" unless File.file?(File.join(source, 'openapi.yaml'))

    FileUtils.mkdir_p(File.join(target, 'fixtures'))
    FileUtils.cp(File.join(source, 'openapi.yaml'), target)
    FileUtils.cp(Dir[File.join(source, 'fixtures', '*.json')], File.join(target, 'fixtures'))

    revision = Dir.chdir(source) { `git describe --always --dirty 2>/dev/null`.strip }

    File.write(File.join(target, 'SOURCE'), "blackevin/spec @ #{revision.empty? ? 'unknown' : revision}\n")

    puts "contract synced from #{source} (#{revision})"
  end
end

desc 'Tag the version in lib/blackevin/version.rb and push it, which triggers the release workflow'
task :tag do
  require_relative 'lib/blackevin/version'

  version = Blackevin::VERSION
  tag = "v#{version}"

  abort 'the working tree is not clean; commit first' unless `git status --porcelain`.strip.empty?
  abort "CHANGELOG.md has no entry for #{version}" unless File.read('CHANGELOG.md').include?("## #{version}")
  abort "#{tag} already exists" unless `git tag --list #{tag}`.strip.empty?

  sh "git tag #{tag}"
  sh "git push origin HEAD #{tag}"

  puts "#{tag} pushed. Follow it with: gh run watch"
end
