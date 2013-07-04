Parents = Struct.new(:a, :b)
Operations = Struct.new(:add, :sub, :mul, :div, :mod)

Ops = Operations.new(
	Proc.new { |a, b|  a.val + b.val },
	Proc.new { |a, b|  a.val - b.val },
	Proc.new { |a, b|  a.val * b.val },
	Proc.new { |a, b|  a.val / b.val },
	Proc.new { |a, b|  a.val % b.val }
)

class Reac 

	attr_accessor(:val, :parents, :children)

	def initialize(val, opp = nil) 
		@val = val
		@parents = Parents.new(nil, nil)
		@operation = opp
		@onChange = nil
		@children = []
	end

	def update()
		@val = @operation.call(@parents.a, @parents.b)
		puts("got updated to new value #{val}")
	end

	def onChange(proc)
		@onChange = proc
	end

	def val=(val)
		@val = val
		if @onChange
			@onChange.call(@val)
		end
		@children.each do |child| 
			child.update()
		end
	end

	def link(temp, other)
		temp.parents = Parents.new(self, other)
		self.children.push(temp)
		other.children.push(temp)
		return temp
	end

	def +(other)
		temp = Reac.new(self.val + other.val, Ops.add)
		link(temp, other)
	end

	def -(other)
		temp = Reac.new(self.val - other.val, Ops.sub)
		link(temp, other)
	end

	def *(other)
		temp = Reac.new(self.val * other.val, Ops.mul)
		link(temp, other)
	end

	def /(other)
		temp = Reac.new(self.val / other.val, Ops.div)
		link(temp, other)
	end

	def %(other)
		temp = Reac.new(self.val % other.val, Ops.mod)
		link(temp, other)
	end

	# def +=(other) #this should be a hard one
	# 	temp = Reac.new(
	# 		self.val / other.val, 
	# 		Proc.new { |a, b|  a.val / b.val }
	# 	)
	# 	link(temp, other)
	# end
end

# Testing
# -----------------------------------------------
b = Reac.new(3.0)
c = Reac.new(4.0)

a = (b + c) * b #/ c

puts(a.val)
b.val = 4.0
puts(a.val)
