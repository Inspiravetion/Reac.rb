
Operations = Struct.new(:add, :sub, :mul, :div, :mod)

Parents = Struct.new(:a, :b) do

  def remove(parent)
    if self.a.equal? parent then self.a = nil end        
    if self.b.equal? parent then self.b = nil end        
  end

end

Conditional_Event = Struct.new(:condition) do
  
  def initialize(c = nil)
    self.condition = c
  end

  def when(proc = nil, &block)
    self.condition = proc || block
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

  include GC 

  #Class Variables
  #--------------------------------------------------------------------------
  Ops = Operations.new(
    Proc.new { |a, b|  Reac.get_value(a) + Reac.get_value(b) },
    Proc.new { |a, b|  Reac.get_value(a) - Reac.get_value(b) },
    Proc.new { |a, b|  Reac.get_value(a) * Reac.get_value(b) },
    Proc.new { |a, b|  Reac.get_value(a) / Reac.get_value(b) },
    Proc.new { |a, b|  Reac.get_value(a) % Reac.get_value(b) }
  )

  Global_Events = {}
  Global_Event_Types = {}

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
    # ObjectSpace.define_finalizer(self, proc {|id| p "#{id} was collected"}) 
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

  def make_collectable
    #sever connection with parents
    same_object = proc { |val| val.equal? self }
    if @parents.a.is_a? Reac 
      then @parents.a.children.delete_if &same_object end
    if @parents.b.is_a? Reac 
      then @parents.b.children.delete_if &same_object end

    # sever connections with children
    @children.each do |child|
      child.parents.remove(self)
    end
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
    if not other.is_a? Reac 
      then return handle_primitive(self.val + other, Ops.add, other) 
    end
    overload_operator(self.val + other.val, Ops.add, other)
  end

  def *(other)
    if not other.is_a? Reac 
      then return handle_primitive(self.val * other, Ops.mul, other) 
    end
    overload_operator(self.val * other.val, Ops.mul, other)
  end

  ### Non-Commutative ###
  def -(other)
    if not other.is_a? Reac 
      if @coerced then return handle_primitive(other - self.val, Ops.sub, other)
      else return handle_primitive(self.val - other, Ops.sub, other) end 
    end
    overload_operator(self.val - other.val, Ops.sub, other)
  end

  def /(other)
    if not other.is_a? Reac 
      if @coerced then return handle_primitive(other / self.val, Ops.div, other)
      else return handle_primitive(self.val / other, Ops.div, other) end 
    end
    overload_operator(self.val / other.val, Ops.div, other)
  end

  def %(other)
    if not other.is_a? Reac 
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
  
  def self.dispose_of(reac_obj)
    reac_obj.make_collectable
    reac_obj = nil
  end
  
  def self.fire(symbol)
    Reac.store_event_in_registry(Global_Events, symbol)
  end

  def self.register_event_type(symbol, proc = nil, &block)
    run_event = Reac.store_event_in_registry(Global_Event_Types, symbol)
    run_event.when proc || block
  end

  def arm_event(symbol)
    @events[symbol] = Global_Event_Types[symbol] 
  end

  def fire(symbol)
    Reac.store_event_in_registry(@events, symbol)
  end

  def fire_once(symbol)
    Reac.store_event_in_registry(@single_fire_events, symbol)
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
    p 'i got collected'
  end

  def self.get_value(obj)
    if obj.is_a? Reac then return obj.val end
    obj
  end

  def self.store_event_in_registry(container, symbol)
    c_event = Conditional_Event.new()
    container[symbol] = c_event
    c_event
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
    if @handlers.keys.empty? then return end 
    emit_events_from_registry(@events)
    emit_events_from_registry(@single_fire_events)
    emit_events_from_registry(Global_Events)
    @single_fire_events = {}
  end

  def emit_events_from_registry(registry)
    registry.keys.each do |key|
      event = registry[key]
      if @handlers[key] and (event.condition.nil? or event.condition.call(self.val))
        emit(key)
      end
    end
  end

  def emit(name)
    @handlers[name].each do |cb|
      cb.exec(self.val)
    end
  end

end

# Testing
# -----------------------------------------------

# setup
b = Reac.new(3.0)
c = Reac.new(4.0)
a = 100 - ( (b + c) * b / c ) - 1

# global event system
Reac.fire(:global)
a.on(:global).execute do |val|
  p "global got #{val}"
end

# reusable event registration system
Reac.register_event_type :reusable do |val|
  val % 2 == 0
end

a.arm_event :reusable #shouldnt fire
a.on(:reusable).execute do |val|
  p "a reusable got #{val}"
end

b.arm_event :reusable
b.on(:reusable).execute do |val|
  p "b reusable got #{val}"
end

# regular event system
a.fire(:trial).when(Proc.new { |val| val < 90 })
a.on(:trial).execute(Proc.new { |val| p "Proc got #{val}"})
a.on(:trial).execute lambda { |val| p "lambda got #{val}" }
a.on(:trial).execute do |v|
  p "block got #{v}"
end

# fire once event system
a.fire_once(:single)
a.on(:single).execute(Proc.new { |val| p "single Proc got #{val}"})
a.on(:single).execute lambda { |val| p "single lambda got #{val}" }
a.on(:single).execute do |val|
  p "single block got #{val}"
end

# change dependent values
b.val = 4.0
c.val = 2

# test comparison operators
puts(a < 100)
puts(100 > a)
puts(a < b)
puts(b > a)

# p a.object_id
# Reac.dispose_of a
# p 'starting garbage collecter'
# GC.start

# p 'file about to end'