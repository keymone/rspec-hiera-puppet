require 'puppet'
require 'hiera'
require 'hiera/scope'

class Puppet::Parser::Compiler
  alias_method :compile_unadorned, :compile

  def compile
    spec = Thread.current[:spec]

    if spec
      register_function(spec, :hiera, :priority, :type => :rvalue)
      register_function(spec, :hiera_array, :array, :type => :rvalue)
      register_function(spec, :hiera_hash, :hash, :type => :rvalue)
      register_function(spec, :hiera_include, :array) do |value|
        method = Puppet::Parser::Functions.function(:include)
        send(method, value)
      end
    end

    compile_unadorned
  end

  def register_function(spec, name, resolution, options={})
    Puppet::Parser::Functions.newfunction(name, options) do |*args|
      args = args[0]if args[0].is_a?(Array)

      key, default, override = *args
      hiera = Hiera.new(:config => spec.hiera_config.merge(:logger => 'puppet'))
      hiera_scope = self.respond_to?("[]") ? self : Hiera::Scope.new(self)
      answer = hiera.lookup(key, default, hiera_scope, override, resolution)

      if answer.nil?
        raise(Puppet::ParseError,
          "Could not find data item #{key} in any Hiera data file and no default supplied")
      end

      block_given? ? yield(answer) : answer
    end
  end
end
