# frozen_string_literal: true
# Copyright (c) 2010-2017 VMware, Inc.  All Rights Reserved.
# SPDX-License-Identifier: MIT

require 'bundler/gem_tasks'
require 'rake/testtask'
require 'yard'
require 'rubocop/rake_task'

Dir.glob(File.join('lib/tasks/**/*.rake')).each { |file| load file }

task(default: :test)

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.test_files = FileList['test/test_*.rb']
  t.verbose = true
  t.warning = true
end

RuboCop::RakeTask.new

YARD::Rake::YardocTask.new

desc 'Update the CONTRIBUTORS.md'
task :update_contributors do
  contributors = `git log --format='%aN <%aE>'`.each_line.map(&:chomp).sort.uniq
  contributors.reject! { |c| c.start_with?('dependabot[bot]') }
  content = contributors.map { |c| "* #{c}" }.join("\n") << "\n"
  File.write(File.expand_path('CONTRIBUTORS.md', __dir__), content)
end
