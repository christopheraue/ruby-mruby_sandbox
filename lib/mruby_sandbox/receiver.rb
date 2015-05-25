class MrubySandbox::Receiver < BasicObject
  # instance_eval imposes a security vulnerability on the ordinary ruby side of the sandbox: All
  # receiver's methods are accessible from the inside. So with instance_eval from the inside the
  # following is possible: `client.instance_eval '::Kernel.system("rm -rf /")'`
  undef_method :instance_eval
  undef_method :instance_exec

  def self.inherited(subclass)
    subclass.send(:define_method, :respond_to?) do |method|
      subclass.instance_methods.include?(method.to_sym)
    end

    subclass.send(:define_method, :class) do
      subclass.to_s
    end
  end
end