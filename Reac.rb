
Parents    = Struct.new(:a, :b)

Operations = Struct.new(:add, :sub, :mul, :div, :mod)

Conditional_Event = Struct.new(:condition) do
  
  def initialize(c = nil)
    self.condition = c
  end

  def when(proc)
    self.condition = proc
  end

end

Handler = Struct.new(:callback) do

  def initialize(c = nil)
    self.callback = c
  end

  def execute(proc = nil, &block)
    self.callback = proc || block
  end 

  def exec(data)
    if self.callback
      self.callback.call(data)
    end
  end

end

class Reac 

  #Class Variables
  #--------------------------------------------------------------------------
  Ops = Operations.new(
    Proc.new { |a, b|  Reac.get_value(a) + Reac.get_value(b) },
    Proc.new { |a, b|  Reac.get_value(a) - Reac.get_value(b) },
    Proc.new { |a, b|  Reac.get_value(a) * Reac.get_value(b) },
    Proc.new { |a, b|  Reac.get_value(a) / Reac.get_value(b) },
    Proc.new { |a, b|  Reac.get_value(a) % Reac.get_value(b) }
  )

  global_events = {}
  global_handlers = {}

  ## have a way for people to register how they want their defined type to be evaluated
  # 
  # Reac.register_operation(:symbol, Proc.new { |a , b| 
  #   puts 'your functionality here...'
  # })
  # 
  # a = Reac.new(2)
  # b = Reac.new(3)
  # 
  # c = Reac.symbol(a, b)
  
  # Let people define reusable events that will fire on predfined conditions
  # Reac.fire(:symbol).when(Proc.new { |a| a.iseven? })
  # 
  # c.arm_event(:symbol)                                                     

  # GARBAGE COLLECTION OF INTERMEDIATE NODES!!!
  # possibly check for other == nil in self=(other)...if you can...or expose this as a destroy()
  # API call to clear out all of its references before they change it?...thats super tedious though
  
  #Setup
  #--------------------------------------------------------------------------
  attr_accessor(:val)

  def coerce(other)
    @coerced = true
    return [self, other]
  end

  #API
  #--------------------------------------------------------------------------
  def initialize(val, opp = nil) 
    #wont work...this gets called AFTER the obj has been garbage collected...aka its useless
    ObjectSpace.define_finalizer(self, self.class.method(:finalize)) 
    @val = val
    @parents = Parents.new(nil, nil)
    @operation = opp
    @children = []
    @events = {}
    @single_fire_events = {}
    @handlers = Hash.new {|hash, key| hash[key] = [] }
    @is_root_of_update = true
    @is_last_trace = false
    @coerced = false
  end
 
  def val=(val)
    @val = val
    @children.each_with_index do |child, i| 
      if (@is_root_of_update or @is_last_trace) and @children.last.equal? @children[i]
        then child.update(true) 
        else child.update(false) 
      end
    end
    if @is_root_of_update then emit_events end
  end

  # Mutators---------------------------

  ### Commutative ###
  def +(other)
    if not other.kind_of? Reac 
      then return handle_primitive(self.val + other, Ops.add, other) 
    end
    overload_operator(self.val + other.val, Ops.add, other)
  end

  def *(other)
    if not other.kind_of? Reac 
      then return handle_primitive(self.val * other, Ops.mul, other) 
    end
    overload_operator(self.val * other.val, Ops.mul, other)
  end

  ### Non-Commutative ###
  def -(other)
    if not other.kind_of? Reac 
      if @coerced then return handle_primitive(other - self.val, Ops.sub, other)
      else return handle_primitive(self.val - other, Ops.sub, other) end 
    end
    overload_operator(self.val - other.val, Ops.sub, other)
  end

  def /(other)
    if not other.kind_of? Reac 
      if @coerced then return handle_primitive(other / self.val, Ops.div, other)
      else return handle_primitive(self.val / other, Ops.div, other) end 
    end
    overload_operator(self.val / other.val, Ops.div, other)
  end

  def %(other)
    if not other.kind_of? Reac 
      if @coerced then return handle_primitive(other % self.val, Ops.mod, other)
      else return handle_primitive(self.val % other, Ops.mod, other) end 
    end
    overload_operator(self.val % other.val, Ops.mod, other)
  end

  # Comparison-------------------------
  
  ### Commutative ###
  def ==(other)
    Reac.get_value(self) == Reac.get_value(other)
  end

  def <=>(other)
    Reac.get_value(self) <=> Reac.get_value(other)
  end

  ### Non-Commutative ###
  def <=(other)
    a , b = resolve_coercion(Reac.get_value(self), Reac.get_value(other))
    a <= b
  end

  def >=(other)
    a , b = resolve_coercion(Reac.get_value(self), Reac.get_value(other))
    a >= b
  end

  def <(other)
    a , b = resolve_coercion(Reac.get_value(self), Reac.get_value(other))
    a < b
  end

  def >(other)
    a , b = resolve_coercion(Reac.get_value(self), Reac.get_value(other))
    a > b
  end

  # Event Hook 
  #------------------------------------
  
  def self.fire(symbol)
    _fire(global_events, symbol)
  end

  def self.on(symbol)
    handler = Handler.new()
    global_handlers[symbol].push(handler)
    handler
  end

  def arm_event(symbol)
    @events[symbol] = global_events[symbol]
  end

  def arm_handler(symbol)
    @handlers[symbol] = global_handlers[symbol]
  end

  def fire(symbol)
    _fire(@events, symbol)
  end

  def fire_once(symbol)
    _fire(@single_fire_events, symbol)
  end

  def on(symbol)
    handler = Handler.new()
    @handlers[symbol].push(handler)
    handler
  end
  
  #Internals
  #--------------------------------------------------------------------------
  protected

  def update(last)
    @is_root_of_update = false
    if last then @is_last_trace = true end  
    self.val = @operation.call(@parents.a, @parents.b)
    if last then
      @is_last_trace = false
      @is_root_of_update = true
      emit_events
    end
  end

  def parents
    @parents
  end

  def parents=(other)
    @parents = other
  end

  def children
    @children
  end

  def children=(other)
    @children = other
  end

  #Helpers
  #--------------------------------------------------------------------------
  private 

  def self.finalize
    # Figure out how to kick this off
  end

  def self.get_value(obj)
    if obj.kind_of? Reac then return obj.val end
    obj
  end

  def link(temp, other)
    temp.parents = Parents.new(self, other)
    self.children.push(temp)
    other.children.push(temp)
    return temp
  end

  def link_primitive(temp, prim)
    temp.parents = @coerced ? Parents.new(prim, self) : Parents.new(self, prim)
    self.children.push(temp)
    @coerced = false
    return temp
  end

  def overload_operator(value, operation, other)
    temp = Reac.new(value, operation)
    link(temp, other)
  end

  def handle_primitive(value, operation, prim)
    temp = Reac.new(value, operation)
    link_primitive(temp, prim)
  end

  def resolve_coercion(a, b)
    if not @coerced then return a , b end
    @coerced = false
    return b , a
  end

  def emit_events
    emit_events_from_registry(@events)
    emit_events_from_registry(@single_fire_events)
    @single_fire_events = {}
  end

  def emit_events_from_registry(registry)
    registry.keys.each do |key|
      event = registry[key]
      if event.condition.nil? or event.condition.call(self.val)
        emit(key)
      end
    end
  end

  def emit(name)
    @handlers[name].each do |cb|
      cb.exec(self.val)
    end
  end

  def _fire(container, symbol)
    c_event = Conditional_Event.new()
    container[symbol] = c_event
    c_event
  end

end

# Testing
# -----------------------------------------------

b = Reac.new(3.0)
c = Reac.new(4.0)

a = 100 - ( (b + c) * b / c ) - 1
a.fire(:trial).when(Proc.new { |val| val < 90 })
a.on(:trial).execute do |v|
  p "a shrunk under 90...it is now #{v}!!!"
end
a.on(:trial).execute(Proc.new { p 'Proc version'})

a.fire_once(:single)
a.on(:single).execute do |val|
  p "single got #{val}"
end
a.on(:single).execute lambda { |val| p "lambda got #{val}" }

puts(a.val)
b.val = 4.0
puts(a.val)
c.val = 2
puts(a.val)
puts(a < 100)
puts(100 > a)
puts(a < b)
puts(b > a)
