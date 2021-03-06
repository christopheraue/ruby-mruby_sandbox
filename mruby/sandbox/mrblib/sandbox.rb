class Sandbox < WorldObject::Connection
  self.world_class = 'InsideMrubySandbox'

  # self.logger = Logger.new(STDERR)

  world_public def evaluate(code, file = '', lineno = 0)
    TOPLEVEL_BINDING.__evaluate__(code, nil, file, lineno)
  rescue Exception => e
    # discard calls to main#__evaluate__ and main#eval from backtrace
    e.backtrace.pop 2
    raise e
  end
end

TOPLEVEL_BINDING = self

# We'd like to have errors happening during `eval` reported as happening inside
# `evaluate`.
alias evaluate eval

# This is a tautology but otherwise constants defined during evaluation of
# the given string in Sandbox#evaluate are not defined under the root namespace
# but under Sandbox.
def __evaluate__(*args)
  evaluate *args
end

Sandbox.open(input: STDIN, output: STDOUT).await_close