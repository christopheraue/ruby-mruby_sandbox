Object.remove_const :File
Object.remove_const :FileTest

IO.singleton_class.remove_method :_popen
IO.singleton_class.remove_method :popen
IO.singleton_class.remove_method :sysopen
IO.singleton_class.remove_method :read
IO.remove_method :pid

Kernel.remove_method :`
Kernel.remove_method :print
Kernel.remove_method :puts
Kernel.remove_method :printf
Kernel.remove_method :gets
Kernel.remove_method :getc
Kernel.remove_method :open
