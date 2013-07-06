
Parents    = Struct.new(:a, :b)
Operations = Struct.new(:add, :sub, :mul, :div, :mod)

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
  # c.attach_event(:symbol)                                                     this-|
  #                                                                                  |
                                                                                    #|
  #Let people register events on variables in line or using globally defined events  |
  #                                                                                  |
  # a = Reac.new(2)                                                                  |
  # b = Reac.new(3)                                                                  |
  #                                                                                  |
  # c = a + b                                                                        |
  #                                                                                  | 
  # if no proc given , this acts as onchange...should probably remove on change      |
  # c.fire(:event_name).when(Proc.new { |a| a.iseven? })     <- and this are same thing
  # 
  # listen for event...globally defined or otherwise
  # c.on(:event_name).execute(Proc.new { |a| puts 'do something with your updated value' })

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
    @val = val
    @parents = Parents.new(nil, nil)
    @operation = opp
    @onChange = nil
    @children = []
    @is_root_of_update = true
    @is_last_trace = false
    @coerced = false
  end

  def onChange(proc)
    @onChange = proc
  end
 
  def val=(val)
    @val = val
    @children.each_with_index do |child, i| 
      if (@is_root_of_update or @is_last_trace) and @children.last.equal? @children[i]
        then child.update(true) 
        else child.update(false) 
      end
    end
    if @is_root_of_update and @onChange then @onChange.call(@val) end
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
  
  #Internals
  #--------------------------------------------------------------------------
  protected

  def update(last)
    @is_root_of_update = false
    if last then @is_last_trace = true end  
    self.val = @operation.call(@parents.a, @parents.b)
    if last then
      if @onChange then @onChange.call(@val) end
      @is_last_trace = false
      @is_root_of_update = true
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

end

# Testing
# -----------------------------------------------
b = Reac.new(3.0)
c = Reac.new(4.0)

a = 100 - ( (b + c) * b / c ) - 1
a.onChange(Proc.new { || puts('a changed!!!') })

puts(a.val)
b.val = 4.0
puts(a.val)
c.val = 2
puts(a.val)
puts(a < 100)
puts(100 > a)
puts(a < b)
puts(b > a)
