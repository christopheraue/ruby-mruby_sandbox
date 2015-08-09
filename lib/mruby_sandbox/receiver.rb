class MrubySandbox::Receiver < BasicObject
  # instance_eval imposes a security vulnerability on the ordinary ruby side of the sandbox: All
  # receiver's methods are accessible from the inside. So with instance_eval from the inside the
  # following is possible: `client.instance_eval '::Kernel.system("rm -rf /")'`
  undef_method :instance_eval
  undef_method :instance_exec

  def self.inherited(subclass)
    subclass.__send__(:define_method, :respond_to?) do |method|
      subclass.instance_methods.include?(method.to_sym)
    end

    subclass.__send__(:define_method, :class) do
      subclass
    end
  end

  def self.const_missing(name)
    ::Object.const_get(name)
  end

  def inspect
    "#<#{self.class}:#{'%#016x' % __id__}>"
  end
  alias_method :to_s, :inspect
end