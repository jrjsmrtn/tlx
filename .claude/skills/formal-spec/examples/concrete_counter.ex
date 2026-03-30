# Concrete spec: two sub-counters that refine the abstract counter
#
# The implementation splits the count into two independent sub-counters.
# The refinement mapping proves that a + b behaves like the abstract count.

import Tlx

defspec ConcreteCounter do
  variable :a, 0
  variable :b, 0

  action :inc_a do
    guard(e(a + b < 3))
    next :a, e(a + 1)
  end

  action :inc_b do
    guard(e(a + b < 3))
    next :b, e(b + 1)
  end

  # This spec refines AbstractCounter:
  # the sum of a + b corresponds to the abstract "count"
  refines AbstractCounter do
    mapping :count, e(a + b)
  end
end
