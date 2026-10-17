# Compiles the catalog for one node from a facts fixture, without applying it,
# and prints every resource with its parameters in a stable, diffable form.
#
#   ruby compile_catalog.rb <repo_dir> <facts.yaml> <modulepath> <vardir>
#
# The node name is the fixture's basename; the identity facts Puppet insists on
# (hostname, fqdn, ...) are derived from it so fixtures only hold what differs.
require 'puppet'
require 'yaml'

repo, facts_file, modulepath, vardir = ARGV
node_name = File.basename(facts_file, '.yaml')

Puppet.initialize_settings(['--vardir', vardir, '--confdir', vardir, '--codedir', vardir])
Puppet[:strict] = :error

values = YAML.safe_load_file(facts_file)
values.merge!(
  'hostname' => node_name, 'domain' => 'test', 'fqdn' => node_name, 'clientcert' => node_name,
  'networking' => { 'hostname' => node_name, 'fqdn' => node_name },
)

env = Puppet::Node::Environment.create(:check, ["#{repo}/modules", *modulepath.split(':')], "#{repo}/manifests/hosts.pp")
facts = Puppet::Node::Facts.new(node_name, values)
node = Puppet::Node.new(node_name, facts: facts, environment: env)
node.merge(facts.values)

def show(value)
  case value
  when Puppet::Resource then value.ref
  when Array then "[#{value.map { |v| show(v) }.join(', ')}]"
  when String then value.include?("\n") ? "|\n" + value.lines.map { |l| "      #{l.chomp}" }.join("\n") : value.inspect
  else value.inspect
  end
end

Puppet.override(current_environment: env, loaders: Puppet::Pops::Loaders.new(env)) do
  begin
    catalog = Puppet::Parser::Compiler.compile(node)
  rescue Puppet::Error => e
    warn e.message
    exit 1
  end
  resources = catalog.resources.reject { |r| %w[Class Stage Node].include?(r.type) }
  resources.sort_by(&:ref).each do |r|
    puts r.ref
    r.to_hash.sort.each do |param, value|
      next if param == :name || value.to_s == r.title
      puts "    #{param} => #{show(value)}"
    end
  end
end
