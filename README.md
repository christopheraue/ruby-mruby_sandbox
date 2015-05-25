# A mruby sandbox for ruby

A mruby sandbox whose job is to run untrusted ruby code in a safe environment.
Untrusted code is loaded into an environment having no access to the outside
world by default. Receivers can be registered so methods can be called on the
other side of the sandboxes walls.

The sandbox runs as a subprocess of a managing parent process. To be able to
communicate with its parent the sandbox also loads a restricted IO library
that only allows reading and writing to IO endpoints the parent passed down
to the sandbox. The IO library does not implement any operations creating new
endpoints, accessing files on the system or the like.

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

The inside of the sandbox has two buckets. One for untrusted and one for trusted code.

The untrusted bucket lives in a module shielded of from the critical parts of the sandbox, i.e.
communication with the outside. It can be filled with:

```ruby
sandbox.eval_untrusted('some code')
```

The trusted bucket offers means to communicate with the outside and to access the untrusted code.
It can be filled with:

```ruby
sandbox.eval_trusted('some code')
```

### The bucket for untrusted code

A simple example:

```ruby
sandbox = MrubySandbox.new
sandbox.eval_untrusted("8+45") # => 53
sandbox.eval_untrusted("system 'rm -rf /'") # => NoMethodError
```

More complex untrusted code following the rules of mruby is possible:

```ruby
sandbox = MrubySandbox.new
sandbox.eval_untrusted(<<-CODE)
  def meth
    'result'
  end

  class Klass
    def meth
      'klass meth'
    end
  end
CODE

sandbox.eval_untrusted('meth') # => 'result'
sandbox.eval_untrusted('Klass.new.meth') # => 'klass meth'
```

### The bucket for trusted code

* `#untrusted`: Gives access to the untrusted code. Similar to the example above:
  ```ruby
  sandbox = MrubySandbox.new
  sandbox.eval_untrusted(<<-CODE)
    def meth
      'result'
    end

    class Klass
      def meth
        'klass meth'
      end
    end
  CODE

  sandbox.eval_trusted('untrusted.meth') # => 'result'
  sandbox.eval_trusted('untrusted::Klass.new.meth') # => 'klass meth'
  ```

* `#export`: Registers a receiver inside the sandbox to reach from the outside
  ```ruby
  sandbox = MrubySandbox.new
  sandbox.eval_trusted(<<-CODE)
    class Receiver
      def multiply(a, b)
        a * b
      end
    end
    export(Receiver.new, as: :math)
  CODE

  sandbox.client_for(:math).multiply(5, 9) # => 45
  ```

* `#client_for`: Reaches out to a receiver on the outside of the sandbox
  ```ruby
  class Receiver
    def exp(a, b)
      a ** b
    end
  end

  sandbox = MrubySandbox.new
  sandbox.add_receiver(math: Receiver.new)

  sandbox.eval_trusted('client_for(:math).exp(2,8)') # => 256
  ```