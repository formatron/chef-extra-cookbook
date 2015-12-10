#!/usr/bin/env ruby

require 'chef/cookbook/metadata'

fail 'Must specify category' if ARGV.empty?

category = ARGV.shift

metadata = Chef::Cookbook::Metadata.new
metadata.from_file './metadata.rb'

def run(cmd, fail_message)
  system cmd
  fail fail_message unless $? == 0
end

run 'git diff --exit-code > /dev/null', 'Failed: there are local unstaged changes'
run 'git diff --cached --exit-code > /dev/null', 'Failed: there are local staged but uncommitted changes'
run 'git push', 'Failed: could not push local commits'
run "git tag v#{metadata.version}", "Failed: could not create tag v#{metadata.version}"
run 'git push --tags', "Failed: could not push tag v#{metadata.version}"
run "chef exec knife cookbook site share '#{metadata.name}' \"#{category}\"", "Failed: could not share cookbook #{metadata.name} with version #{metadata.version} under category #{category}"
