# A mruby sandbox for ruby

A mruby sandbox whose job is to run untrusted ruby code in a safe environment.
Untrusted code is loaded into an environment having no access to the outside
world by default. Receivers can be registered so methods can be called on the
outside of the sandbox.

The sandbox runs as a subprocess of a managing parent process. To be able to
communicate with its parent the sandbox also loads a restricted IO library
that only allows reading and writing through STDIN and STDOUT. Besides STDERR
no further IO Endpoints are passed down by the parent. The IO library does not
implement any operations accessing files on the system or the like.

**A gem has not been published, yet.**

## Usage

The string given to `MrubySandbox#evaluate` is parsed and evaluated in the
sandbox by mruby:

```ruby
sandbox = MrubySandbox.new
sandbox.evaluate "8+45" # => 53
sandbox.evaluate "system 'rm -rf /'" # => NoMethodError
```

The environment built by previous evaluations is accessible by following
evaluations:

```ruby
sandbox = MrubySandbox.new
sandbox.evaluate <<-CODE
  def meth
    'result'
  end

  class Klass
    def meth
      'klass meth'
    end
  end
CODE

sandbox.evaluate 'meth' # => 'result'
sandbox.evaluate 'Klass.new.meth' # => 'klass meth'
```