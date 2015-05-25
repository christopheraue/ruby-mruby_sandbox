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

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'mruby_sandbox'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install mruby_sandbox

After the gem is installed the sandbox needs to be build for your system:

    $ build_mruby_sandbox

## Usage

```ruby
sandbox = MrubySandbox.new
sandbox.eval("8+45") # => 53
sandbox.eval("system 'rm -rf /'") # => NoMethodError
```

More complex untrusted code following the rules of mruby is possible:

```ruby
sandbox = MrubySandbox.new
sandbox.eval(<<-CODE)
  def meth
    'result'
  end

  class Klass
    def meth
      'klass meth'
    end
  end
CODE

sandbox.eval('meth') # => 'result'
sandbox.eval('Klass.new.meth') # => 'klass meth'
```

There are two methods available to communicate with the outside:

* `#export`: Registers a receiver inside the sandbox to reach from the outside
  ```ruby
  sandbox = MrubySandbox.new
  sandbox.eval(<<-CODE)
    class Calc
      def multiply(a, b)
        a * b
      end
    end
    export(math: Calc)
  CODE

  sandbox.client_for(:math).multiply(5, 9) # => 45
  sandbox.client_for(:math).add(5, 9) # => NoMethodError
  ```

* `#client_for`: Reaches out to a receiver on the outside of the sandbox
  ```ruby
  class Calc < MrubySandbox::Receiver
    def exp(a, b)
      a ** b
    end
  end

  sandbox = MrubySandbox.new
  sandbox.add_receiver(math: Calc)

  sandbox.eval 'client_for(:math).exp(2,8)' # => 256
  sandbox.eval 'client_for(:math).exp' # => ArgumentError
  ```

To create Receivers outside the sandbox let them inherit from `MrubySandbox::Receiver`. This is
basically a `BasicObject` without `#instance_{eval|exec}` so it does not respond to methods
capable of executing potential malicious code. Inside the sandbox, in mruby land, nothing bad should
be possible, if a receiver is an ordinary object. Otherwise we are screwed anyway.