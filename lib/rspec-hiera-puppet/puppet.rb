require 'puppet'
require 'hiera_puppet'

class Puppet::Parser::Compiler
  alias_method :compile_unadorned, :compile

  def compile
    spec = Thread.current[:spec]

    if spec
      register_function(:hiera, :priority, :type => :rvalue)
      register_function(:hiera_array, :array, :type => :rvalue)
      register_function(:hiera_hash, :hash, :type => :rvalue)
      register_function(:hiera_include, :array) do |value|
        method = Puppet::Parser::Functions.function(:include)
        send(method, value)
      end
    end

    compile_unadorned
  end

  def register_function(name, resolution, options={})
    Puppet::Parser::Functions.newfunction(name, options) do |*args|
      key, default, override = HieraPuppet.parse_args(args)
      answer = HieraPuppet.lookup(key, default, self, override, resolution)
      block_given? ? yield(answer) : answer
    end
  end
end
